-- ============================================================
-- Adaptable — community layer
-- Comments, "Cooked it" tracking (feeds the Trending sort),
-- and device tokens for push notifications.
-- ============================================================

-- Denormalized counters on recipes, maintained by triggers below.
alter table public.recipes
  add column cook_count    integer not null default 0,
  add column comment_count integer not null default 0;

-- ------------------------------------------------------------
-- COMMENTS — public community discussion on a recipe
-- ------------------------------------------------------------
create table public.comments (
  id         uuid primary key default gen_random_uuid(),
  recipe_id  uuid not null references public.recipes (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

create index comments_recipe_idx on public.comments (recipe_id, created_at desc);

alter table public.comments enable row level security;

create policy "Comments are viewable by everyone"
  on public.comments for select
  using (true);

create policy "Authenticated users can comment as themselves"
  on public.comments for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can edit their own comments"
  on public.comments for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their own comments"
  on public.comments for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.sync_comment_count()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  target uuid;
begin
  target := coalesce(new.recipe_id, old.recipe_id);
  update public.recipes r
     set comment_count = (
       select count(*) from public.comments c where c.recipe_id = target)
   where r.id = target;
  return coalesce(new, old);
end;
$$;

create trigger on_comment_changed
  after insert or delete on public.comments
  for each row execute function public.sync_comment_count();

-- ------------------------------------------------------------
-- COOKS — one row per completed Cook Mode session
-- ------------------------------------------------------------
create table public.cooks (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  recipe_id  uuid not null references public.recipes (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index cooks_recipe_idx on public.cooks (recipe_id);
create index cooks_user_idx   on public.cooks (user_id, created_at desc);

alter table public.cooks enable row level security;

create policy "Users can view their own cooks"
  on public.cooks for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can record their own cooks"
  on public.cooks for insert
  to authenticated
  with check (auth.uid() = user_id);

create or replace function public.sync_cook_count()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  target uuid;
begin
  target := coalesce(new.recipe_id, old.recipe_id);
  update public.recipes r
     set cook_count = (
       select count(*) from public.cooks c where c.recipe_id = target)
   where r.id = target;
  return coalesce(new, old);
end;
$$;

create trigger on_cook_changed
  after insert or delete on public.cooks
  for each row execute function public.sync_cook_count();

-- ------------------------------------------------------------
-- DEVICE_TOKENS — push notification targets (APNs / FCM)
-- Sending happens server-side (edge function + FCM); clients
-- may only manage their own tokens.
-- ------------------------------------------------------------
create table public.device_tokens (
  token      text primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  platform   text not null default 'unknown'
             check (platform in ('ios', 'android', 'web', 'unknown')),
  created_at timestamptz not null default now()
);

create index device_tokens_user_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

create policy "Users can view their own device tokens"
  on public.device_tokens for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can register their own device tokens"
  on public.device_tokens for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their own device tokens"
  on public.device_tokens for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can remove their own device tokens"
  on public.device_tokens for delete
  to authenticated
  using (auth.uid() = user_id);
