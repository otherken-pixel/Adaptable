-- ============================================================
-- Adaptable — shopping list
-- Personal, owner-only grocery items, optionally linked to the
-- recipe they came from (title denormalized so groups survive
-- recipe deletion).
-- ============================================================

create table public.shopping_items (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles (id) on delete cascade,
  recipe_id    uuid references public.recipes (id) on delete set null,
  recipe_title text not null default '',
  item         text not null check (char_length(item) between 1 and 200),
  quantity     text not null default '',
  checked      boolean not null default false,
  created_at   timestamptz not null default now()
);

create index shopping_items_user_idx
  on public.shopping_items (user_id, created_at desc);

alter table public.shopping_items enable row level security;

create policy "Users can view their own shopping items"
  on public.shopping_items for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can add their own shopping items"
  on public.shopping_items for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their own shopping items"
  on public.shopping_items for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their own shopping items"
  on public.shopping_items for delete
  to authenticated
  using (auth.uid() = user_id);
