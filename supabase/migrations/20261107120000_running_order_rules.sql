-- Follow-up to #83, #85 and #86: a running order (waiting or processing) holds its
-- listing. The seller cannot withdraw it, and its buyer can still chat about it after
-- booking the last unit took it off the catalog.

-- A running order of p_buyer on p_listing.
create function public.has_running_order(p_listing uuid, p_buyer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.orders o
    where o.listing_id = p_listing and o.buyer_id = p_buyer
      and o.status in ('waiting', 'processing')
  );
$$;

revoke execute on function public.has_running_order(uuid, uuid) from public, anon, authenticated;

-- As in 20261104120000, refusing while any order on the listing runs. The listing row
-- is locked first, so place_order (which locks it too) cannot slip in between.
create or replace function public.withdraw_listing(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform 1 from public.listings
    where id = p_id and seller_id = auth.uid() and removed_at is null and withdrawn_at is null
    for update;
  if not found then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  if exists (select 1 from public.orders
      where listing_id = p_id and status in ('waiting', 'processing')) then
    raise exception 'listing_has_orders' using errcode = 'check_violation';
  end if;
  update public.listings set withdrawn_at = now() where id = p_id;
end;
$$;

-- As in 20261106120000, except:
-- - a new chat may also start from a listing the caller has a running order on;
-- - inside an existing conversation p_listing only has to be its seller's: the card
--   moves when the listing is live or the conversation's buyer has a running order on
--   it, otherwise the message still goes through and the card stays.
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

-- K13 for either party: the conversation between the order's buyer and seller, if any.
create function public.conversation_for_order(p_order uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select c.id from public.conversations c
  join public.orders o on o.buyer_id = c.buyer_id and o.seller_id = c.seller_id
  where o.id = p_order and auth.uid() in (o.buyer_id, o.seller_id);
$$;

revoke execute on function public.conversation_for_order(uuid) from public, anon;
grant execute on function public.conversation_for_order(uuid) to authenticated;

-- As in 20261106120000; the card also stays while the conversation's buyer has a
-- running order on the listing.
create or replace function public.my_conversations()
returns table (
  id uuid, other_name text, i_am_buyer boolean, last_body text, last_at timestamptz,
  listing_id uuid, listing_title text, listing_price integer, listing_donation boolean,
  listing_photo text
)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, o.full_name, c.buyer_id = auth.uid(),
    (select m.body from public.messages m where m.conversation_id = c.id
      order by m.created_at desc, m.id desc limit 1),
    c.last_message_at, l.id, l.title, l.price, l.is_donation,
    (select ph.path from public.listing_photos ph where ph.listing_id = l.id
      order by ph.position limit 1)
  from public.conversations c
  join public.profiles o on o.id = case when c.buyer_id = auth.uid() then c.seller_id else c.buyer_id end
  left join public.listings l on l.id = c.listing_id
    and (public.is_live_listing(l.id) or public.has_running_order(l.id, c.buyer_id))
  where auth.uid() in (c.buyer_id, c.seller_id)
  order by c.last_message_at desc nulls last, c.id;
$$;
