-- Household RPC grants + unauthenticated guard on my_household_user_ids.
-- Also: durable daily counter for fridge-scan Gemini usage.

create table if not exists public.ai_usage_events (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  action     text not null,
  created_at timestamptz not null default now()
);

create index if not exists ai_usage_events_user_action_idx
  on public.ai_usage_events (user_id, action, created_at desc);

alter table public.ai_usage_events enable row level security;

drop policy if exists "Users can insert their own ai usage" on public.ai_usage_events;
create policy "Users can insert their own ai usage"
  on public.ai_usage_events for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can view their own ai usage" on public.ai_usage_events;
create policy "Users can view their own ai usage"
  on public.ai_usage_events for select
  to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.my_household_user_ids()
returns uuid[]
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  return coalesce(
    (
      select array_agg(distinct m.user_id)
      from public.household_members me
      join public.household_members m on m.household_id = me.household_id
      where me.user_id = auth.uid()
    ),
    array[auth.uid()]
  );
end;
$$;

revoke all on function public.create_household(text) from public, anon;
revoke all on function public.join_household(text) from public, anon;
revoke all on function public.leave_household() from public, anon;
revoke all on function public.my_household_user_ids() from public, anon;

grant execute on function public.create_household(text) to authenticated;
grant execute on function public.join_household(text) to authenticated;
grant execute on function public.leave_household() to authenticated;
grant execute on function public.my_household_user_ids() to authenticated;
