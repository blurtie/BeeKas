-- T9 (#87, D-38 K-22-K-26, D-29, PRD-katalog 5.9, 6.13, 7.5): Lapor (K16) and the admin
-- report console (K19).
-- - Approved, unfrozen members report a listing, or the other party of a conversation.
--   One open report per reporter and object.
-- - Admins take a reported listing down (reason required) or dismiss its reports.
-- - Cancelling as an admin goes through admin_cancel_order (one order) and
--   admin_cancel_listing (every running order and active bid of a listing). Both mark the
--   order cancel_reason = 'admin_removed' with the admin as cancelled_by: admins may also
--   buy, so is_admin(cancelled_by) does not tell moderation apart. Freezes (T10, #88)
--   and admin_cancel_order for Booking 24 Jam (D-50) call these helpers.
-- - K-24: admin_report_messages reads a reported chat while its report is open. The app
--   does not call it until the privacy policy says so (docs/privacy-k24-draft.md).

create type public.report_reason as enum (
  'prohibited', 'scam', 'not_as_described', 'inappropriate', 'spam', 'other'
);
create type public.report_status as enum ('open', 'actioned', 'dismissed');

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles on delete cascade,
  -- Either a listing, or a member reported from a conversation with them.
  listing_id uuid references public.listings on delete cascade,
  reported_id uuid references public.profiles on delete cascade,
  conversation_id uuid references public.conversations on delete cascade,
  reason public.report_reason not null,
  note text check (btrim(note) <> '' and char_length(note) <= 500),
  status public.report_status not null default 'open',
  resolved_by uuid references public.profiles on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  constraint reports_target check (
    (listing_id is null) <> (reported_id is null)
    and (reported_id is null) = (conversation_id is null)
  ),
  constraint reports_not_self check (reported_id is distinct from reporter_id),
  -- 6.13: Lainnya needs a note.
  constraint reports_note check (reason <> 'other' or note is not null),
  constraint reports_resolved check ((status = 'open') = (resolved_at is null))
);

create unique index reports_one_open_listing on public.reports (reporter_id, listing_id)
  where status = 'open' and listing_id is not null;
create unique index reports_one_open_member on public.reports (reporter_id, reported_id)
  where status = 'open' and reported_id is not null;
create index reports_open on public.reports (created_at) where status = 'open';

-- Reporters see only that a report was sent; everything else goes through functions.
alter table public.reports enable row level security;
revoke all on public.reports from anon, authenticated;

-- Lapor. p_listing, or p_conversation for its other party.
create function public.submit_report(
  p_reason public.report_reason,
  p_note text default null,
  p_listing uuid default null,
  p_conversation uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note text := nullif(btrim(p_note), '');
  v_other uuid;
  v_id uuid;
begin
  if auth.uid() is null or not public.is_listed_seller(auth.uid()) then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  if p_reason is null or (p_listing is null) = (p_conversation is null) then
    raise exception 'report_invalid' using errcode = 'check_violation';
  end if;
  if p_reason = 'other' and v_note is null then
    raise exception 'note_missing' using errcode = 'check_violation';
  end if;
  if p_listing is not null then
    select seller_id into v_other from public.listings where id = p_listing and removed_at is null;
    if v_other is null then
      raise exception 'listing_unavailable' using errcode = 'check_violation';
    end if;
    if v_other = auth.uid() then
      raise exception 'own_listing' using errcode = 'check_violation';
    end if;
  else
    select case when buyer_id = auth.uid() then seller_id else buyer_id end into v_other
      from public.conversations where id = p_conversation and auth.uid() in (buyer_id, seller_id);
    if v_other is null then
      raise exception 'not_participant' using errcode = 'insufficient_privilege';
    end if;
  end if;
  begin
    insert into public.reports (reporter_id, listing_id, reported_id, conversation_id, reason, note)
    values (auth.uid(), p_listing, case when p_listing is null then v_other end,
      p_conversation, p_reason, v_note)
    returning id into v_id;
  exception when unique_violation then
    raise exception 'already_reported' using errcode = 'check_violation';
  end;
  return v_id;
end;
$$;

-- K19: open reports, one row per object, oldest first.
create function public.admin_open_reports()
returns table (
  report_id uuid, listing_id uuid, listing_title text, reported_id uuid,
  reported_name text, conversation_ids uuid[], reporters integer,
  reasons public.report_reason[], notes text[], first_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = 'insufficient_privilege';
  end if;
  return query
  select (array_agg(r.id order by r.created_at))[1], r.listing_id, l.title, r.reported_id,
    p.full_name, array_remove(array_agg(distinct r.conversation_id), null),
    count(*)::int, array_agg(r.reason order by r.created_at),
    array_remove(array_agg(r.note order by r.created_at), null), min(r.created_at)
  from public.reports r
  left join public.listings l on l.id = r.listing_id
  left join public.profiles p on p.id = r.reported_id
  where r.status = 'open'
  group by r.listing_id, l.title, r.reported_id, p.full_name
  order by min(r.created_at);
end;
$$;

-- Closes every open report on the object of p_report.
create function public.close_reports(p_report uuid, p_status public.report_status)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.reports r set status = p_status, resolved_by = auth.uid(), resolved_at = now()
  from public.reports t
  where t.id = p_report and r.status = 'open'
    and (r.listing_id = t.listing_id or r.reported_id = t.reported_id);
$$;

-- Abaikan.
create function public.dismiss_report(p_report uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = 'insufficient_privilege';
  end if;
  if not exists (select 1 from public.reports where id = p_report and status = 'open') then
    raise exception 'report_closed' using errcode = 'check_violation';
  end if;
  perform public.close_reports(p_report, 'dismissed');
end;
$$;

-- K-23: cancels one running order as the calling admin; its unit returns, and a donation
-- winner gets their tokens back (refund_cancelled_donation). False when it was not running.
create function public.admin_cancel_order(p_order uuid, p_note text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_listing uuid;
begin
  update public.orders set status = 'cancelled', cancel_reason = 'admin_removed',
      cancel_note = nullif(btrim(p_note), ''), cancelled_by = auth.uid(), cancelled_at = now()
    where id = p_order and status in ('waiting', 'processing')
    returning listing_id into v_listing;
  if not found then
    return false;
  end if;
  update public.listings set stock_left = stock_left + 1 where id = v_listing;
  return true;
end;
$$;

-- Every running order and active bid of p_listing: orders as above, bids refunded now
-- rather than when the 24-hour window closes.
create function public.admin_cancel_listing(p_listing uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order uuid;
  v_bid public.donation_bids;
begin
  perform 1 from public.listings where id = p_listing for update;
  for v_order in
    select id from public.orders where listing_id = p_listing and status in ('waiting', 'processing')
  loop
    perform public.admin_cancel_order(v_order, p_note);
  end loop;
  for v_bid in
    update public.donation_bids set status = 'refunded', closed_at = now()
    where listing_id = p_listing and status = 'active'
    returning *
  loop
    perform public.refund_bid_tokens(v_bid.bidder_id, v_bid.amount, p_listing);
  end loop;
  update public.listings set bid_ends_at = null where id = p_listing;
end;
$$;

-- K-26 for the freeze in T10 (#88): the member's listings as above, plus their own
-- running orders and active bids as a buyer.
create function public.admin_cancel_member(p_member uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_bid public.donation_bids;
begin
  for v_id in select id from public.listings where seller_id = p_member loop
    perform public.admin_cancel_listing(v_id, p_note);
  end loop;
  for v_id in
    select id from public.orders where buyer_id = p_member and status in ('waiting', 'processing')
  loop
    perform public.admin_cancel_order(v_id, p_note);
  end loop;
  for v_bid in
    update public.donation_bids set status = 'refunded', closed_at = now()
    where bidder_id = p_member and status = 'active'
    returning *
  loop
    perform public.refund_bid_tokens(v_bid.bidder_id, v_bid.amount, v_bid.listing_id);
  end loop;
end;
$$;

-- Turunkan listing. Closes the listing's open reports as actioned.
create function public.remove_listing(p_listing uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = 'insufficient_privilege';
  end if;
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'reason_missing' using errcode = 'check_violation';
  end if;
  update public.listings set removed_at = now(), removed_by = auth.uid(),
      removal_reason = btrim(p_reason)
    where id = p_listing and removed_at is null;
  if not found then
    raise exception 'listing_unavailable' using errcode = 'check_violation';
  end if;
  perform public.admin_cancel_listing(p_listing, btrim(p_reason));
  update public.reports set status = 'actioned', resolved_by = auth.uid(), resolved_at = now()
    where listing_id = p_listing and status = 'open';
end;
$$;

-- Kembalikan kuota (D-29: the admin's mistake), with a note; +1 as a ledger correction.
create function public.restore_quota(p_member uuid, p_note text, p_listing uuid default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = 'insufficient_privilege';
  end if;
  if coalesce(btrim(p_note), '') = '' then
    raise exception 'note_missing' using errcode = 'check_violation';
  end if;
  insert into public.quota_balances (member_id, balance) values (p_member, 1)
    on conflict (member_id) do update set balance = public.quota_balances.balance + 1;
  insert into public.quota_ledger (member_id, delta, reason, listing_id, admin_id, note)
  values (p_member, 1, 'correction', p_listing, auth.uid(), btrim(p_note));
end;
$$;

-- K-24: the messages of a reported conversation, only while one of its reports is open.
create function public.admin_report_messages(p_conversation uuid)
returns table (id uuid, sender_id uuid, sender_name text, body text, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = 'insufficient_privilege';
  end if;
  if not exists (select 1 from public.reports
      where conversation_id = p_conversation and status = 'open') then
    raise exception 'no_open_report' using errcode = 'insufficient_privilege';
  end if;
  return query
  select m.id, m.sender_id, p.full_name, m.body, m.created_at
  from public.messages m join public.profiles p on p.id = m.sender_id
  where m.conversation_id = p_conversation
  order by m.created_at, m.id;
end;
$$;

-- As in 20261118120100, also refunding a winner whose order moderation cancelled.
create or replace function public.refund_cancelled_donation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bid public.donation_bids;
begin
  if new.cancelled_by is null or new.cancelled_by = new.seller_id
      or new.cancel_reason = 'admin_removed' then
    update public.donation_bids set status = 'refunded'
      where order_id = new.id and status = 'won'
      returning * into v_bid;
    if found then
      perform public.refund_bid_tokens(v_bid.bidder_id, v_bid.amount, v_bid.listing_id);
    end if;
  end if;
  return null;
end;
$$;

-- As in 20261107120000, also refusing when the other party is no longer listed (K-26).
create or replace function public.send_message(
  p_body text, p_conversation uuid default null, p_listing uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_seller uuid;
  v_id uuid := p_conversation;
  v_conv public.conversations;
  v_card uuid;
begin
  if auth.uid() is null or not public.is_listed_seller(auth.uid()) then
    raise exception 'chat_not_allowed' using errcode = 'insufficient_privilege';
  end if;
  if p_listing is not null then
    select seller_id into v_seller from public.listings where id = p_listing;
  end if;
  if v_id is null then
    if v_seller is null or v_seller = auth.uid()
        or not (public.is_live_listing(p_listing) or public.has_running_order(p_listing, auth.uid())) then
      raise exception 'listing_unavailable' using errcode = 'check_violation';
    end if;
    if not public.is_listed_seller(v_seller) then
      raise exception 'chat_not_allowed' using errcode = 'insufficient_privilege';
    end if;
    insert into public.conversations (buyer_id, seller_id)
      values (auth.uid(), v_seller)
      on conflict (buyer_id, seller_id) do update set buyer_id = excluded.buyer_id
      returning id into v_id;
    v_card := p_listing;
  else
    select * into v_conv from public.conversations
      where id = v_id and auth.uid() in (buyer_id, seller_id);
    if not found then
      raise exception 'not_participant' using errcode = 'insufficient_privilege';
    end if;
    if not public.is_listed_seller(
        case when v_conv.buyer_id = auth.uid() then v_conv.seller_id else v_conv.buyer_id end) then
      raise exception 'chat_not_allowed' using errcode = 'insufficient_privilege';
    end if;
    if p_listing is not null then
      if v_seller is distinct from v_conv.seller_id then
        raise exception 'listing_unavailable' using errcode = 'check_violation';
      end if;
      if public.is_live_listing(p_listing) or public.has_running_order(p_listing, v_conv.buyer_id) then
        v_card := p_listing;
      end if;
    end if;
  end if;
  insert into public.messages (conversation_id, sender_id, body, listing_id)
    values (v_id, auth.uid(), p_body, v_card);
  update public.conversations
    set last_message_at = clock_timestamp(),
        listing_id = coalesce(v_card, listing_id)
    where id = v_id;
  return v_id;
end;
$$;

revoke execute on function public.close_reports(uuid, public.report_status),
  public.admin_cancel_order(uuid, text), public.admin_cancel_listing(uuid, text),
  public.admin_cancel_member(uuid, text)
  from public, anon, authenticated;
revoke execute on function
  public.submit_report(public.report_reason, text, uuid, uuid),
  public.admin_open_reports(), public.dismiss_report(uuid),
  public.remove_listing(uuid, text), public.restore_quota(uuid, text, uuid),
  public.admin_report_messages(uuid)
  from public, anon;
grant execute on function
  public.submit_report(public.report_reason, text, uuid, uuid),
  public.admin_open_reports(), public.dismiss_report(uuid),
  public.remove_listing(uuid, text), public.restore_quota(uuid, text, uuid),
  public.admin_report_messages(uuid)
  to authenticated;
