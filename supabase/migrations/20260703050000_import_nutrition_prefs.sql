-- ============================================================
-- Adaptable — recipe import attribution, macro nutrition,
-- and per-user taste preferences.
-- ============================================================

alter table public.recipes
  add column source_url text,
  add column protein_g  integer check (protein_g is null or protein_g >= 0),
  add column carbs_g    integer check (carbs_g   is null or carbs_g   >= 0),
  add column fat_g      integer check (fat_g     is null or fat_g     >= 0);

-- Taste profile: diets, allergies, dislikes, household_size, spice, skill.
-- Injected into every Gemini prompt by the edge functions.
alter table public.profiles
  add column preferences jsonb not null default '{}'::jsonb;
