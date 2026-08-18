-- ============================================================
-- Meal-prep bundle metadata on recipes.
-- Lets us score ingredient overlap and method compatibility
-- without scanning free-text jsonb on every request.
-- ============================================================

alter table public.recipes
  add column if not exists ingredient_keys text[] not null default '{}',
  add column if not exists primary_method text
    check (primary_method is null or primary_method in (
      'oven', 'stovetop', 'sheet_pan', 'air_fryer', 'slow_cooker',
      'grill', 'no_cook', 'instant_pot', 'mixed'
    )),
  add column if not exists base_protein text
    check (base_protein is null or base_protein in (
      'chicken', 'beef', 'pork', 'turkey', 'fish', 'shrimp',
      'tofu', 'beans', 'eggs', 'lamb', 'none'
    )),
  add column if not exists meal_slot text
    check (meal_slot is null or meal_slot in (
      'breakfast', 'lunch', 'dinner', 'snack', 'dessert', 'any'
    )),
  add column if not exists active_prep_minutes integer
    check (active_prep_minutes is null or active_prep_minutes >= 0),
  add column if not exists equipment text[] not null default '{}';

comment on column public.recipes.ingredient_keys is
  'Canonical, staple-stripped ingredient tokens for overlap queries.';
comment on column public.recipes.primary_method is
  'Dominant cooking method used for concurrent-cook compatibility.';
comment on column public.recipes.base_protein is
  'Primary protein / protein analogue for batch-cook grouping.';
comment on column public.recipes.meal_slot is
  'breakfast | lunch | dinner | snack | dessert | any';
comment on column public.recipes.active_prep_minutes is
  'Hands-on minutes (prep plus active cook; excludes unattended roast).';
comment on column public.recipes.equipment is
  'Exclusive or shared appliances this recipe needs.';

create index if not exists recipes_ingredient_keys_gin
  on public.recipes using gin (ingredient_keys);

create index if not exists recipes_method_protein_idx
  on public.recipes (primary_method, base_protein);

-- Cheap tag-based backfill. Full ingredient_keys are written on
-- generate/import/complete-bundle; the iOS client also infers at read time.
update public.recipes
set primary_method = case
  when exists (select 1 from unnest(tags) t where lower(t) in ('sheet-pan', 'sheet pan')) then 'sheet_pan'
  when exists (select 1 from unnest(tags) t where lower(t) in ('air-fryer', 'air fryer')) then 'air_fryer'
  when exists (select 1 from unnest(tags) t where lower(t) in ('no-cook', 'no cook', 'overnight')) then 'no_cook'
  when exists (select 1 from unnest(tags) t where lower(t) in ('slow-cooker', 'crockpot')) then 'slow_cooker'
  when exists (select 1 from unnest(tags) t where lower(t) like '%instant%pot%') then 'instant_pot'
  when exists (select 1 from unnest(tags) t where lower(t) in ('one-pan', 'one-pot', 'stir-fry')) then 'stovetop'
  when exists (select 1 from unnest(tags) t where lower(t) = 'grill') then 'grill'
  else primary_method
end
where primary_method is null;

update public.recipes
set meal_slot = case
  when exists (select 1 from unnest(tags) t where lower(t) in ('breakfast', 'brunch')) then 'breakfast'
  when exists (select 1 from unnest(tags) t where lower(t) in ('dessert', 'baking')) then 'dessert'
  when exists (select 1 from unnest(tags) t where lower(t) in ('snack', 'appetizer')) then 'snack'
  when exists (select 1 from unnest(tags) t where lower(t) = 'lunch') then 'lunch'
  else meal_slot
end
where meal_slot is null;
