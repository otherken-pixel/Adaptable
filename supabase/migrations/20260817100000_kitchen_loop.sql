-- Leftover lineage, household sharing for plans + groceries.

create table if not exists public.recipe_lineage (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.profiles (id) on delete cascade,
  parent_recipe_id  uuid not null references public.recipes (id) on delete cascade,
  child_recipe_id   uuid not null references public.recipes (id) on delete cascade,
  leftover_focus    text[] not null default '{}',
  created_at        timestamptz not null default now()
);

create index if not exists recipe_lineage_user_idx
  on public.recipe_lineage (user_id, created_at desc);
create index if not exists recipe_lineage_parent_idx
  on public.recipe_lineage (parent_recipe_id);
create index if not exists recipe_lineage_child_idx
  on public.recipe_lineage (child_recipe_id);

alter table public.recipe_lineage enable row level security;

drop policy if exists "Users can view their own lineage" on public.recipe_lineage;
create policy "Users can view their own lineage"
  on public.recipe_lineage for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own lineage" on public.recipe_lineage;
create policy "Users can insert their own lineage"
  on public.recipe_lineage for insert to authenticated
  with check (auth.uid() = user_id);

alter table public.meal_plans
  add column if not exists leftover_of uuid references public.recipes (id) on delete set null,
  add column if not exists leftover_focus text;

-- Households ------------------------------------------------

create table if not exists public.households (
  id          uuid primary key default gen_random_uuid(),
  name        text not null default 'Kitchen',
  invite_code text unique not null,
  created_at  timestamptz not null default now()
);

create table if not exists public.household_members (
  household_id uuid not null references public.households (id) on delete cascade,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  role         text not null default 'member'
               check (role in ('owner', 'member')),
  created_at   timestamptz not null default now(),
  primary key (household_id, user_id)
);

create unique index if not exists household_members_one_kitchen
  on public.household_members (user_id);

alter table public.profiles
  add column if not exists household_id uuid references public.households (id) on delete set null;

alter table public.households enable row level security;
alter table public.household_members enable row level security;

create or replace function public.my_household_user_ids()
returns uuid[]
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select array_agg(distinct m.user_id)
      from public.household_members me
      join public.household_members m on m.household_id = me.household_id
      where me.user_id = auth.uid()
    ),
    array[auth.uid()]
  );
$$;

grant execute on function public.my_household_user_ids() to authenticated;

create or replace function public.join_household(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  hid uuid;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  select id into hid
    from public.households
   where invite_code = upper(trim(p_code));
  if hid is null then
    raise exception 'NOT_FOUND';
  end if;
  delete from public.household_members where user_id = auth.uid();
  insert into public.household_members (household_id, user_id, role)
  values (hid, auth.uid(), 'member');
  update public.profiles set household_id = hid where id = auth.uid();
  return hid;
end;
$$;

grant execute on function public.join_household(text) to authenticated;

drop policy if exists "Members can view their household" on public.households;
create policy "Members can view their household"
  on public.households for select to authenticated
  using (
    exists (
      select 1 from public.household_members m
      where m.household_id = id and m.user_id = auth.uid()
    )
  );

drop policy if exists "Authenticated can create a household" on public.households;
create policy "Authenticated can create a household"
  on public.households for insert to authenticated
  with check (true);

drop policy if exists "Owners can update household" on public.households;
create policy "Owners can update household"
  on public.households for update to authenticated
  using (
    exists (
      select 1 from public.household_members m
      where m.household_id = id and m.user_id = auth.uid() and m.role = 'owner'
    )
  );

drop policy if exists "Members can view household roster" on public.household_members;
create policy "Members can view household roster"
  on public.household_members for select to authenticated
  using (user_id = any (public.my_household_user_ids()) or user_id = auth.uid());

drop policy if exists "Users can join a household" on public.household_members;
create policy "Users can join a household"
  on public.household_members for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Users can leave a household" on public.household_members;
create policy "Users can leave a household"
  on public.household_members for delete to authenticated
  using (user_id = auth.uid());

-- Household can see / tick each other's plans and groceries.
drop policy if exists "Users can view their own meal plans" on public.meal_plans;
create policy "Household can view meal plans"
  on public.meal_plans for select to authenticated
  using (user_id = any (public.my_household_user_ids()));

drop policy if exists "Users can add to their own meal plans" on public.meal_plans;
create policy "Users can add to their own meal plans"
  on public.meal_plans for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own meal plans" on public.meal_plans;
create policy "Household can update meal plans"
  on public.meal_plans for update to authenticated
  using (user_id = any (public.my_household_user_ids()))
  with check (user_id = any (public.my_household_user_ids()));

drop policy if exists "Users can remove their own meal plans" on public.meal_plans;
create policy "Household can remove meal plans"
  on public.meal_plans for delete to authenticated
  using (user_id = any (public.my_household_user_ids()));

drop policy if exists "Users can view their own shopping items" on public.shopping_items;
create policy "Household can view shopping items"
  on public.shopping_items for select to authenticated
  using (user_id = any (public.my_household_user_ids()));

drop policy if exists "Users can add their own shopping items" on public.shopping_items;
create policy "Users can add their own shopping items"
  on public.shopping_items for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own shopping items" on public.shopping_items;
create policy "Household can update shopping items"
  on public.shopping_items for update to authenticated
  using (user_id = any (public.my_household_user_ids()))
  with check (user_id = any (public.my_household_user_ids()));

drop policy if exists "Users can delete their own shopping items" on public.shopping_items;
create policy "Household can delete shopping items"
  on public.shopping_items for delete to authenticated
  using (user_id = any (public.my_household_user_ids()));
