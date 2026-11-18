-- D-46: token ledger reasons for donation bids. On their own so the next migration can
-- use them (a new enum value cannot be used in the transaction that adds it).
alter type public.quota_reason add value if not exists 'bid';
alter type public.quota_reason add value if not exists 'bid_refund';
