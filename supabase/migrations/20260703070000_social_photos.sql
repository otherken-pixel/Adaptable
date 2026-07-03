-- ============================================================
-- Adaptable — follows, cooked-it photos, and storage buckets
-- ============================================================

-- ------------------------------------------------------------
-- FOLLOWS — follow a chef; powers the "Following" feed filter
-- ------------------------------------------------------------
create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  followee_id uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

create index follows_followee_idx on public.follows (followee_id);

alter table public.follows enable row level security;

create policy "Users can view their own follows"
  on public.follows for select
  to authenticated
  using (auth.uid() = follower_id);

create policy "Users can follow chefs"
  on public.follows for insert
  to authenticated
  with check (auth.uid() = follower_id);

create policy "Users can unfollow chefs"
  on public.follows for delete
  to authenticated
  using (auth.uid() = follower_id);

-- ------------------------------------------------------------
-- RECIPE_PHOTOS — "I cooked it" photos shown on the recipe
-- ------------------------------------------------------------
create table public.recipe_photos (
  id         uuid primary key default gen_random_uuid(),
  recipe_id  uuid not null references public.recipes (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  path       text not null,
  created_at timestamptz not null default now()
);

create index recipe_photos_recipe_idx
  on public.recipe_photos (recipe_id, created_at desc);

alter table public.recipe_photos enable row level security;

create policy "Recipe photos are viewable by everyone"
  on public.recipe_photos for select
  using (true);

create policy "Users can add their own recipe photos"
  on public.recipe_photos for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can delete their own recipe photos"
  on public.recipe_photos for delete
  to authenticated
  using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- STORAGE — public buckets for cooked-it photos and avatars.
-- Uploads are namespaced per user: <user_id>/<filename>
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('cook-photos', 'cook-photos', true), ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "Public read app images"
  on storage.objects for select
  using (bucket_id in ('cook-photos', 'avatars'));

create policy "Users upload to their own folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id in ('cook-photos', 'avatars')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users update their own objects"
  on storage.objects for update
  to authenticated
  using (
    bucket_id in ('cook-photos', 'avatars')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users delete their own objects"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id in ('cook-photos', 'avatars')
    and (storage.foldername(name))[1] = auth.uid()::text
  );
