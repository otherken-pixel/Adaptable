-- ============================================================
-- Adaptable — notifications (100% Supabase, no third parties)
--
-- Postgres triggers write notification rows when someone votes,
-- comments or cooks your recipe. Clients receive them two ways:
--   1. Supabase Realtime → live in-app inbox (all platforms)
--   2. Database Webhook → push-dispatch edge function → APNs
--      directly (iOS). No Firebase anywhere in the pipeline.
-- ============================================================

create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  -- recipient
  user_id    uuid not null references public.profiles (id) on delete cascade,
  -- who did the thing (null if the account was deleted)
  actor_id   uuid references public.profiles (id) on delete set null,
  recipe_id  uuid references public.recipes (id) on delete cascade,
  type       text not null check (type in ('vote', 'comment', 'cook')),
  read       boolean not null default false,
  created_at timestamptz not null default now()
);

create index notifications_user_idx
  on public.notifications (user_id, created_at desc);
create index notifications_unread_idx
  on public.notifications (user_id) where read = false;

alter table public.notifications enable row level security;

-- Clients can only read and mark-read their own inbox. There is NO
-- insert policy: rows are created exclusively by the security-definer
-- triggers below, so users can't forge notifications.
create policy "Users can view their own notifications"
  on public.notifications for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can mark their own notifications read"
  on public.notifications for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their own notifications"
  on public.notifications for delete
  to authenticated
  using (auth.uid() = user_id);

-- Broadcast inserts over Supabase Realtime so the in-app inbox is live.
alter publication supabase_realtime add table public.notifications;

-- ------------------------------------------------------------
-- Trigger: notify the recipe author (never about their own action)
-- ------------------------------------------------------------
create or replace function public.notify_recipe_author()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  author uuid;
  kind   text;
begin
  select r.author_id into author from public.recipes r where r.id = new.recipe_id;
  if author is null or author = new.user_id then
    return new;
  end if;

  kind := tg_argv[0];

  -- Only celebrate upvotes; nobody wants a push about a downvote.
  if kind = 'vote' and new.value <> 1 then
    return new;
  end if;

  insert into public.notifications (user_id, actor_id, recipe_id, type)
  values (author, new.user_id, new.recipe_id, kind);
  return new;
end;
$$;

create trigger on_vote_notify
  after insert on public.user_votes
  for each row execute function public.notify_recipe_author('vote');

create trigger on_comment_notify
  after insert on public.comments
  for each row execute function public.notify_recipe_author('comment');

create trigger on_cook_notify
  after insert on public.cooks
  for each row execute function public.notify_recipe_author('cook');
