-- ============================================================
-- Adaptable MVP — initial schema
-- Tables: profiles, recipes, user_votes, saves
-- All tables have Row Level Security enabled.
-- ============================================================

-- ------------------------------------------------------------
-- PROFILES — one row per auth user, created automatically
-- ------------------------------------------------------------
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  username   text unique not null
             check (char_length(username) between 3 and 24),
  avatar_url text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Profiles are viewable by everyone"
  on public.profiles for select
  using (true);

create policy "Users can insert their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Auto-create a profile when a user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'username',
      'chef_' || substr(replace(new.id::text, '-', ''), 1, 8)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ------------------------------------------------------------
-- RECIPES — structured Gemini output
-- ------------------------------------------------------------
create table public.recipes (
  id                uuid primary key default gen_random_uuid(),
  author_id         uuid not null references public.profiles (id) on delete cascade,
  title             text not null check (char_length(title) between 1 and 140),
  description       text not null default '',
  emoji             text not null default '🍽️',
  cuisine           text not null default 'Fusion',
  difficulty        text not null default 'Easy'
                    check (difficulty in ('Easy', 'Medium', 'Hard')),
  prep_time_minutes integer not null default 0 check (prep_time_minutes >= 0),
  cook_time_minutes integer not null default 0 check (cook_time_minutes >= 0),
  servings          integer not null default 2 check (servings > 0),
  calories          integer check (calories is null or calories > 0),
  tags              text[] not null default '{}',
  -- [{ "item": "chickpeas", "quantity": "1 can (400g)", "note": "drained" }]
  ingredients       jsonb not null,
  -- [{ "step": 1, "instruction": "…", "tip": "…" }]
  steps             jsonb not null,
  source_prompt     text not null default '',
  net_upvotes       integer not null default 0,
  created_at        timestamptz not null default now()
);

create index recipes_net_upvotes_idx on public.recipes (net_upvotes desc, created_at desc);
create index recipes_created_at_idx  on public.recipes (created_at desc);
create index recipes_author_idx      on public.recipes (author_id);

alter table public.recipes enable row level security;

create policy "Recipes are viewable by everyone"
  on public.recipes for select
  using (true);

create policy "Authenticated users can create their own recipes"
  on public.recipes for insert
  to authenticated
  with check (auth.uid() = author_id);

create policy "Authors can update their own recipes"
  on public.recipes for update
  to authenticated
  using (auth.uid() = author_id)
  with check (auth.uid() = author_id);

create policy "Authors can delete their own recipes"
  on public.recipes for delete
  to authenticated
  using (auth.uid() = author_id);

-- ------------------------------------------------------------
-- USER_VOTES — one vote per user per recipe (up = 1, down = -1)
-- ------------------------------------------------------------
create table public.user_votes (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  recipe_id  uuid not null references public.recipes (id) on delete cascade,
  value      smallint not null check (value in (-1, 1)),
  created_at timestamptz not null default now(),
  primary key (user_id, recipe_id)
);

create index user_votes_recipe_idx on public.user_votes (recipe_id);

alter table public.user_votes enable row level security;

create policy "Users can view their own votes"
  on public.user_votes for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can cast their own votes"
  on public.user_votes for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can change their own votes"
  on public.user_votes for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can remove their own votes"
  on public.user_votes for delete
  to authenticated
  using (auth.uid() = user_id);

-- Keep recipes.net_upvotes in sync. SECURITY DEFINER so the counter
-- updates even though voters cannot update other people's recipes.
create or replace function public.sync_net_upvotes()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  target uuid;
begin
  target := coalesce(new.recipe_id, old.recipe_id);
  update public.recipes r
     set net_upvotes = coalesce(
       (select sum(v.value) from public.user_votes v where v.recipe_id = target), 0)
   where r.id = target;
  return coalesce(new, old);
end;
$$;

create trigger on_vote_changed
  after insert or update or delete on public.user_votes
  for each row execute function public.sync_net_upvotes();

-- ------------------------------------------------------------
-- SAVES — personal cookbook
-- ------------------------------------------------------------
create table public.saves (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  recipe_id  uuid not null references public.recipes (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, recipe_id)
);

create index saves_user_idx on public.saves (user_id, created_at desc);

alter table public.saves enable row level security;

create policy "Users can view their own saves"
  on public.saves for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can save recipes"
  on public.saves for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can unsave recipes"
  on public.saves for delete
  to authenticated
  using (auth.uid() = user_id);
