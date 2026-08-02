-- Recipe cover images (AI-generated food photos) + optional grocery aisle metadata.

alter table public.recipes
  add column if not exists image_url text;

comment on column public.recipes.image_url is
  'Public URL of AI-generated dish cover photo; null falls back to emoji gradient.';

-- Public bucket for recipe covers (written by edge functions with user JWT).
insert into storage.buckets (id, name, public)
values ('recipe-covers', 'recipe-covers', true)
on conflict (id) do nothing;

-- Allow public read of recipe covers.
drop policy if exists "Public read recipe covers" on storage.objects;
create policy "Public read recipe covers"
  on storage.objects for select
  using (bucket_id = 'recipe-covers');

-- Authenticated users (and edge calls as the user) may upload into their folder.
drop policy if exists "Users upload recipe covers" on storage.objects;
create policy "Users upload recipe covers"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'recipe-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users update recipe covers" on storage.objects;
create policy "Users update recipe covers"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'recipe-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Featured/editor picks for empty social feed states.
alter table public.recipes
  add column if not exists featured boolean not null default false;

create index if not exists recipes_featured_idx
  on public.recipes (featured, net_upvotes desc)
  where featured = true;

-- Seed a few existing high-engagement recipes as featured (safe if ids missing).
update public.recipes
set featured = true
where id in (
  'b0000000-0000-4000-8000-000000000024',
  'b0000000-0000-4000-8000-000000000022',
  'b0000000-0000-4000-8000-000000000001',
  'b0000000-0000-4000-8000-000000000010',
  'b0000000-0000-4000-8000-000000000015'
);
