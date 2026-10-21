-- QRIS payments (#84, D-29, D-35, PRD-katalog 5.3 and 7.2): K8 member side, K18 admin side.
-- One table for packages, Boost and Featured, told apart by kind; Boost and Featured come
-- with K22, so submit_payment takes packages only for now. A mismatched amount (K-11) waits
-- for the CFO: the amount received is recorded, nothing compares it yet.

create type public.payment_kind as enum ('package', 'boost', 'featured');
create type public.payment_status as enum ('pending', 'confirmed', 'rejected');

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles on delete cascade,
  kind public.payment_kind not null,
  -- The expected amount, fixed by kind (D-29).
  amount integer not null,
  -- For Boost and Featured (K22).
  listing_id uuid references public.listings on delete set null,
  -- In payment-proofs; the file itself is deleted after the decision (K-10).
  proof_path text not null,
  status public.payment_status not null default 'pending',
  received_amount integer check (received_amount > 0),
  reason text check (btrim(reason) <> '' and char_length(reason) <= 500),
  -- No set null: a decision keeps its admin (as quota_ledger).
  decided_by uuid references public.profiles,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  constraint payments_amount check (amount = case kind
    when 'package' then 15000 when 'boost' then 3000 when 'featured' then 5000 end),
  constraint payments_decision check (case status
    when 'pending' then decided_by is null and decided_at is null
      and received_amount is null and reason is null
    when 'confirmed' then decided_by is not null and decided_at is not null
      and received_amount is not null and reason is null
    when 'rejected' then decided_by is not null and decided_at is not null and reason is not null
  end)
);

create index payments_member on public.payments (member_id, created_at desc);
create index payments_pending on public.payments (created_at) where status = 'pending';

alter table public.payments enable row level security;
revoke all on public.payments from anon, authenticated;
grant select on public.payments to authenticated;

create policy "payments: members read their own, admins read all"
  on public.payments for select to authenticated
  using (member_id = (select auth.uid()) or (select public.is_admin()));

-- A purchase in the ledger points at its payment, once.
alter table public.quota_ledger
  add column payment_id uuid unique references public.payments on delete set null;

-- Private proofs: members upload into their own folder and cannot read them back (pattern
-- of D-19); admins read. JPEG only: the app converts like listing photos (K-05).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('payment-proofs', 'payment-proofs', false, 5242880, array['image/jpeg']);

create policy "payment proofs: listed members upload own"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'payment-proofs'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and array_length(storage.foldername(name), 1) = 1
    and storage.filename(name) ~ '^[A-Za-z0-9_-]+\.jpg$'
    and (select public.is_listed_seller(auth.uid()))
  );

create policy "payment proofs: admin reads"
  on storage.objects for select to authenticated
  using (bucket_id = 'payment-proofs' and (select public.is_admin()));

-- K-09: the QRIS image lives here so it can change without a new APK. Uploaded by the
-- project owner (docs/cloud-checklist.md); locally an example image from config.toml.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('payment-qris', 'payment-qris', true, 1048576, array['image/png', 'image/jpeg']);

-- K8: the member paid and uploaded the proof.
create function public.submit_payment(p_kind public.payment_kind, p_proof text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null or not public.is_listed_seller(auth.uid()) then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  if p_kind <> 'package' then
    raise exception 'not_supported' using errcode = 'feature_not_supported';
  end if;
  if p_proof is null or p_proof not like auth.uid()::text || '/%' or p_proof like '%..%' then
    raise exception 'not_own_proof' using errcode = 'insufficient_privilege';
  end if;
  insert into public.payments (member_id, kind, amount, proof_path)
  values (auth.uid(), p_kind, 15000, p_proof)
  returning id into v_id;
  return v_id;
end;
$$;

-- K18 Konfirmasi: the amount actually received, then +3 quota in the same transaction.
create function public.confirm_payment(p_id uuid, p_received integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member uuid;
  v_kind public.payment_kind;
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = 'insufficient_privilege';
  end if;
  if p_received is null or p_received <= 0 then
    raise exception 'invalid_amount' using errcode = 'check_violation';
  end if;
  -- The row lock makes a second confirm wait, then find it decided.
  update public.payments
    set status = 'confirmed', received_amount = p_received,
        decided_by = auth.uid(), decided_at = now()
    where id = p_id and status = 'pending'
    returning member_id, kind into v_member, v_kind;
  if not found then
    raise exception 'not_pending' using errcode = 'check_violation';
  end if;
  if v_kind = 'package' then
    insert into public.quota_balances (member_id, balance) values (v_member, 3)
      on conflict (member_id) do update set balance = public.quota_balances.balance + 3;
    insert into public.quota_ledger (member_id, delta, reason, admin_id, payment_id)
    values (v_member, 3, 'purchase', auth.uid(), p_id);
  end if;
end;
$$;

-- K18 Tolak: the member reads the reason and can upload again (a new payment).
create function public.reject_payment(p_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = 'insufficient_privilege';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'reason_missing' using errcode = 'check_violation';
  end if;
  update public.payments
    set status = 'rejected', reason = btrim(p_reason),
        decided_by = auth.uid(), decided_at = now()
    where id = p_id and status = 'pending';
  if not found then
    raise exception 'not_pending' using errcode = 'check_violation';
  end if;
end;
$$;

revoke execute on function public.submit_payment(public.payment_kind, text),
  public.confirm_payment(uuid, integer), public.reject_payment(uuid, text)
  from public, anon;
grant execute on function public.submit_payment(public.payment_kind, text),
  public.confirm_payment(uuid, integer), public.reject_payment(uuid, text)
  to authenticated;

-- K-10: proofs due for deletion by delete-expired-photos (Storage API, not SQL DELETE):
-- those of decided payments, and any proof older than 29 days (undecided, or uploaded
-- without a payment), so a daily run deletes them by day 30.
create function public.expired_payment_proofs()
returns setof text
language sql
stable
security definer
set search_path = ''
as $$
  select o.name from storage.objects o
  where o.bucket_id = 'payment-proofs'
    and (o.created_at < now() - interval '29 days'
      or exists (select 1 from public.payments p
                 where p.proof_path = o.name and p.status <> 'pending'))
  order by o.name;
$$;

revoke execute on function public.expired_payment_proofs() from public, anon, authenticated;
grant execute on function public.expired_payment_proofs() to service_role;
