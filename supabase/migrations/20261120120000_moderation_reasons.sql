-- T9 (#87, K-23): orders cancelled by moderation. On its own so the next migration can
-- use it (a new enum value cannot be used in the transaction that adds it).
alter type public.cancel_reason add value if not exists 'admin_removed';
