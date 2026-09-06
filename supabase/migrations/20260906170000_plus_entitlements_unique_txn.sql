-- One Apple original_transaction_id can bind to only one account.
-- Manual/ops grants leave this null and are excluded.
--
-- Collapse any pre-existing share of the same Apple purchase so the
-- unique index can apply. Keep the earliest-updated row (first claimant);
-- extra accounts lose that purchase.
delete from public.plus_entitlements pe
using (
  select
    user_id,
    row_number() over (
      partition by original_transaction_id
      order by updated_at asc, user_id asc
    ) as rn
  from public.plus_entitlements
  where original_transaction_id is not null
) ranked
where pe.user_id = ranked.user_id
  and ranked.rn > 1;

create unique index if not exists plus_entitlements_original_txn_uidx
  on public.plus_entitlements (original_transaction_id)
  where original_transaction_id is not null;
