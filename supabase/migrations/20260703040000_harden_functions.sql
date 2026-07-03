-- ============================================================
-- Adaptable — hardening (from Supabase security advisors)
-- Trigger functions should not be callable through the PostgREST
-- RPC surface. Triggers still fire fine: execution permission is
-- checked against the table owner, which retains EXECUTE.
-- ============================================================

revoke execute on function public.handle_new_user() from anon, authenticated, public;
revoke execute on function public.sync_net_upvotes() from anon, authenticated, public;
revoke execute on function public.sync_comment_count() from anon, authenticated, public;
revoke execute on function public.sync_cook_count() from anon, authenticated, public;
revoke execute on function public.notify_recipe_author() from anon, authenticated, public;
