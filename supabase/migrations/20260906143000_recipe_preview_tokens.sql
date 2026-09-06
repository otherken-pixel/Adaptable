-- One-time tokens so keep cannot publish a crafted recipe without a
-- prior generate/surprise. Rows are written and consumed by generate-recipe
-- under the caller's JWT (RLS). Expired leftovers are harmless.

create table if not exists public.recipe_preview_tokens (
  token_hash text primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists recipe_preview_tokens_user_idx
  on public.recipe_preview_tokens (user_id, created_at desc);

alter table public.recipe_preview_tokens enable row level security;

drop policy if exists "Users can insert their own preview tokens" on public.recipe_preview_tokens;
create policy "Users can insert their own preview tokens"
  on public.recipe_preview_tokens for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can view their own preview tokens" on public.recipe_preview_tokens;
create policy "Users can view their own preview tokens"
  on public.recipe_preview_tokens for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own preview tokens" on public.recipe_preview_tokens;
create policy "Users can delete their own preview tokens"
  on public.recipe_preview_tokens for delete
  to authenticated
  using ((select auth.uid()) = user_id);
