-- Server-side Adaptable Plus entitlement. Clients cannot grant Plus.
-- generate-recipe reads this table; only service_role / report-plus-entitlement
-- (Apple-verified) or a dashboard/SQL grant can write it.

create table if not exists public.plus_entitlements (
  user_id                  uuid primary key references public.profiles (id) on delete cascade,
  is_plus                  boolean not null default false,
  product_id               text,
  original_transaction_id  text,
  expires_at               timestamptz,
  environment              text,
  updated_at               timestamptz not null default now()
);

create index if not exists plus_entitlements_active_idx
  on public.plus_entitlements (is_plus, expires_at);

alter table public.plus_entitlements enable row level security;

-- Owner can see their own row (paywall / debugging). No client writes.
drop policy if exists "Users can view their own plus entitlement" on public.plus_entitlements;
create policy "Users can view their own plus entitlement"
  on public.plus_entitlements for select
  to authenticated
  using ((select auth.uid()) = user_id);

revoke insert, update, delete on public.plus_entitlements from anon, authenticated, public;
grant select on public.plus_entitlements to authenticated;
grant all on public.plus_entitlements to service_role;

comment on table public.plus_entitlements is
  'StoreKit-verified (or ops-granted) Plus status. Clients cannot upsert this row.';
