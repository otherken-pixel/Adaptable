-- One Apple original_transaction_id can bind to only one account.
-- Manual/ops grants leave this null and are excluded.
create unique index if not exists plus_entitlements_original_txn_uidx
  on public.plus_entitlements (original_transaction_id)
  where original_transaction_id is not null;
