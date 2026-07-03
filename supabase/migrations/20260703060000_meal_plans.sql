-- ============================================================
-- Adaptable — meal planner
-- One row per planned meal; the client scales grocery quantities
-- by servings / recipes.servings when pushing a plan to the list.
-- ============================================================

create table public.meal_plans (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  recipe_id  uuid not null references public.recipes (id) on delete cascade,
  plan_date  date not null,
  servings   integer not null default 2 check (servings between 1 and 24),
  created_at timestamptz not null default now()
);

create index meal_plans_user_date_idx
  on public.meal_plans (user_id, plan_date);

alter table public.meal_plans enable row level security;

create policy "Users can view their own meal plans"
  on public.meal_plans for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can add to their own meal plans"
  on public.meal_plans for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their own meal plans"
  on public.meal_plans for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can remove their own meal plans"
  on public.meal_plans for delete
  to authenticated
  using (auth.uid() = user_id);
