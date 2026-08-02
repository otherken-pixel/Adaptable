-- ============================================================
-- Adaptable — AI hero images for recipes
-- ============================================================
--
-- Recipes have always shown a single emoji on a gradient. This adds an
-- optional AI-generated "dish photo" so the recipe hero — and, more
-- importantly, the link preview when a recipe is shared — can show the
-- real dish instead of the emoji. The emoji stays as the fallback while
-- an image is being generated (or if generation fails), so nothing here
-- is required and older rows keep working untouched.

-- ------------------------------------------------------------
-- COLUMNS — public URL + storage path of the generated hero image
-- ------------------------------------------------------------
alter table public.recipes
  add column if not exists image_url  text,
  add column if not exists image_path text;

-- ------------------------------------------------------------
-- STORAGE — public bucket for generated hero images.
-- Uploads are namespaced per author: <author_id>/<recipe_id>.png,
-- mirroring the cook-photos / avatars convention.
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('recipe-images', 'recipe-images', true)
on conflict (id) do nothing;

create policy "Public read recipe images"
  on storage.objects for select
  using (bucket_id = 'recipe-images');

create policy "Authors upload their own recipe images"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'recipe-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Authors update their own recipe images"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'recipe-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Authors delete their own recipe images"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'recipe-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
