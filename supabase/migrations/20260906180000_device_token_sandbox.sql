-- Per-token APNs environment. Xcode/debug tokens are sandbox;
-- TestFlight and App Store tokens are production. Default false so
-- existing rows stay on production (the live webhook path).

alter table public.device_tokens
  add column if not exists is_sandbox boolean not null default false;

comment on column public.device_tokens.is_sandbox is
  'True when the token was issued by APNs sandbox (Xcode / development).';
