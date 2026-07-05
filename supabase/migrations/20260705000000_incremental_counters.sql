-- ============================================================
-- Adaptable — switch denormalized counters to incremental updates
--
-- The original triggers recomputed net_upvotes/cook_count/comment_count
-- from scratch on every change (`select count(*) ... where recipe_id = x`).
-- That works, but it means a recipe's displayed counters can never exceed
-- the number of distinct rows actually present — e.g. net_upvotes is
-- capped at the number of distinct users who voted (one row per
-- (user_id, recipe_id) by primary key), which makes it impossible to
-- seed realistic "highly reviewed" social-proof numbers without creating
-- hundreds of fake user accounts.
--
-- These counters are pure denormalized display counts — nothing in the
-- product enumerates "here are the N voters" — so there's no correctness
-- reason they must equal a live recount. Switching to incremental
-- (+1 / -1 / delta) updates:
--   1. Lets a seed step set an initial baseline via a plain UPDATE, which
--      then increments correctly as real engagement happens.
--   2. Is cheaper per write (no full aggregate scan per vote/comment/cook).
-- ============================================================

create or replace function public.sync_net_upvotes()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.recipes set net_upvotes = net_upvotes + new.value where id = new.recipe_id;
    return new;
  elsif tg_op = 'UPDATE' then
    if new.recipe_id <> old.recipe_id then
      update public.recipes set net_upvotes = net_upvotes - old.value where id = old.recipe_id;
      update public.recipes set net_upvotes = net_upvotes + new.value where id = new.recipe_id;
    else
      update public.recipes set net_upvotes = net_upvotes + (new.value - old.value) where id = new.recipe_id;
    end if;
    return new;
  elsif tg_op = 'DELETE' then
    update public.recipes set net_upvotes = net_upvotes - old.value where id = old.recipe_id;
    return old;
  end if;
  return null;
end;
$$;

create or replace function public.sync_comment_count()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.recipes set comment_count = comment_count + 1 where id = new.recipe_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.recipes set comment_count = greatest(0, comment_count - 1) where id = old.recipe_id;
    return old;
  end if;
  return null;
end;
$$;

create or replace function public.sync_cook_count()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.recipes set cook_count = cook_count + 1 where id = new.recipe_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.recipes set cook_count = greatest(0, cook_count - 1) where id = old.recipe_id;
    return old;
  end if;
  return null;
end;
$$;

-- Re-assert the hardening from 20260703040000: CREATE OR REPLACE keeps the
-- function's oid (and thus prior grants/revokes) when the signature is
-- unchanged, but we restate this explicitly so it's never accidentally
-- callable through the PostgREST RPC surface.
revoke execute on function public.sync_net_upvotes() from anon, authenticated, public;
revoke execute on function public.sync_comment_count() from anon, authenticated, public;
revoke execute on function public.sync_cook_count() from anon, authenticated, public;
