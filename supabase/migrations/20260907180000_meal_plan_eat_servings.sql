-- Per-eater plates on a planned meal. Independent of cook/grocery yield.
-- Planner nutrition always uses eat_servings × recipe per-serving macros.

alter table public.meal_plans
  add column if not exists eat_servings integer not null default 1
    check (eat_servings between 1 and 8);

comment on column public.meal_plans.eat_servings is
  'Plates the eater counts toward daily calorie/macro totals. Cook servings stay on servings.';
