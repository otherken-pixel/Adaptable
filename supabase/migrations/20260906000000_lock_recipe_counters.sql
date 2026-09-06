-- Lock denormalized recipe counters + featured so authors cannot forge
-- popularity (or self-feature) via a client UPDATE. Counter triggers
-- (sync_net_upvotes / sync_cook_count / sync_comment_count) stay
-- SECURITY DEFINER and continue to maintain the columns.

revoke update (net_upvotes, cook_count, comment_count, featured)
  on public.recipes
  from anon, authenticated, public;

-- service_role (edge admin) may still set featured / seed counters.
grant update (net_upvotes, cook_count, comment_count, featured)
  on public.recipes
  to service_role;

create or replace function public.guard_recipe_locked_columns()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- Client JWT roles cannot change these columns. Table-owner / security
  -- definer counter triggers run as postgres and are allowed through.
  if current_user in ('authenticated', 'anon') then
    new.net_upvotes := old.net_upvotes;
    new.cook_count := old.cook_count;
    new.comment_count := old.comment_count;
    new.featured := old.featured;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_recipe_locked_columns on public.recipes;
create trigger guard_recipe_locked_columns
  before update on public.recipes
  for each row
  execute function public.guard_recipe_locked_columns();

revoke execute on function public.guard_recipe_locked_columns() from anon, authenticated, public;

comment on function public.guard_recipe_locked_columns() is
  'Reverts client updates to net_upvotes, cook_count, comment_count, featured.';
