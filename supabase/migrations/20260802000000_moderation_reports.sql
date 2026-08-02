-- Content moderation: users can flag comments (and later recipes).
-- Rows are only readable by the reporter; inserts as self. Ops review via service role / dashboard.

create table if not exists public.content_reports (
  id           uuid primary key default gen_random_uuid(),
  reporter_id  uuid not null references public.profiles (id) on delete cascade,
  target_type  text not null check (target_type in ('comment', 'recipe')),
  target_id    uuid not null,
  reason       text not null check (char_length(reason) between 3 and 500),
  created_at   timestamptz not null default now(),
  unique (reporter_id, target_type, target_id)
);

create index if not exists content_reports_created_idx
  on public.content_reports (created_at desc);

alter table public.content_reports enable row level security;

create policy "Users can file reports as themselves"
  on public.content_reports for insert
  to authenticated
  with check (auth.uid() = reporter_id);

create policy "Users can view their own reports"
  on public.content_reports for select
  to authenticated
  using (auth.uid() = reporter_id);
