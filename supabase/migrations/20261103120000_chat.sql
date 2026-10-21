-- Text chat K14-K15 and Admin BeeKas K21 (#86, D-31, D-37, PRD-katalog 5.8 and 7.4).
-- One conversation per buyer-seller pair; only the two read it, admins included (K-24:
-- reading reported chats comes with the reports ticket). Writes go through functions.

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles on delete cascade,
  seller_id uuid not null references public.profiles on delete cascade,
  -- The item card on top of K15: the last listing talked about.
  listing_id uuid references public.listings on delete set null,
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  unique (buyer_id, seller_id),
  check (buyer_id <> seller_id)
);

create index conversations_seller on public.conversations (seller_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations on delete cascade,
  sender_id uuid not null references public.profiles on delete cascade,
  -- K-21.
  body text not null check (btrim(body) <> '' and char_length(body) between 1 and 1000),
  listing_id uuid references public.listings on delete set null,
  created_at timestamptz not null default clock_timestamp()
);

create index messages_conversation on public.messages (conversation_id, created_at);

-- K21: one-way, read by every signed-in member; not editable once sent.
create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  body text not null check (btrim(body) <> '' and char_length(body) between 1 and 1000),
  posted_by uuid not null references public.profiles,
  created_at timestamptz not null default now()
);

alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.announcements enable row level security;
revoke all on public.conversations, public.messages, public.announcements from anon, authenticated;
grant select on public.conversations, public.messages, public.announcements to authenticated;

create policy "conversations: participants read"
  on public.conversations for select to authenticated
  using ((select auth.uid()) in (buyer_id, seller_id));

-- Realtime checks this policy for every change it sends (Postgres Changes).
create policy "messages: participants read"
  on public.messages for select to authenticated
  using (exists (select 1 from public.conversations c where c.id = conversation_id));

create policy "announcements: members read"
  on public.announcements for select to authenticated
  using (true);

alter publication supabase_realtime add table public.messages;

-- A listing that is on air: active, not expired, from a listed seller.
create function public.is_live_listing(p_listing uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.listings l
    where l.id = p_listing and l.is_active
      and (l.expires_at is null or l.expires_at > now())
      and public.is_listed_seller(l.seller_id)
  );
$$;

revoke execute on function public.is_live_listing(uuid) from public, anon, authenticated;

-- Sends into p_conversation, or, without one, starts (or reuses) the caller's chat
-- as buyer with the seller of the live p_listing: a seller never starts a chat.
-- p_listing also moves the item card. Returns the conversation.
create function public.send_message(
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
begin
  if auth.uid() is null or not public.is_listed_seller(auth.uid()) then
    raise exception 'chat_not_allowed' using errcode = 'insufficient_privilege';
  end if;
  if p_listing is not null then
    select seller_id into v_seller from public.listings
      where id = p_listing and public.is_live_listing(id);
  end if;
  if v_id is null then
    if v_seller is null or v_seller = auth.uid() then
      raise exception 'listing_unavailable' using errcode = 'check_violation';
    end if;
    insert into public.conversations (buyer_id, seller_id)
      values (auth.uid(), v_seller)
      on conflict (buyer_id, seller_id) do update set buyer_id = excluded.buyer_id
      returning id into v_id;
  elsif not exists (select 1 from public.conversations
      where id = v_id and auth.uid() in (buyer_id, seller_id)) then
    raise exception 'not_participant' using errcode = 'insufficient_privilege';
  end if;
  insert into public.messages (conversation_id, sender_id, body, listing_id)
    values (v_id, auth.uid(), p_body, p_listing);
  update public.conversations
    set last_message_at = clock_timestamp(),
        -- Only a live listing of this conversation's seller becomes the card.
        listing_id = case when v_seller = seller_id then p_listing else listing_id end
    where id = v_id;
  return v_id;
end;
$$;

-- The caller's chat as buyer with the seller of p_listing, if any.
create function public.conversation_for_listing(p_listing uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select c.id from public.conversations c
  join public.listings l on l.seller_id = c.seller_id
  where l.id = p_listing and c.buyer_id = auth.uid();
$$;

-- K14: the caller's conversations, newest first. Only the other member's name: never
-- their phone (D-26).
create function public.my_conversations()
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
  where auth.uid() in (c.buyer_id, c.seller_id)
  order by c.last_message_at desc nulls last, c.id;
$$;

create function public.post_announcement(p_body text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = 'insufficient_privilege';
  end if;
  insert into public.announcements (body, posted_by) values (btrim(p_body), auth.uid());
end;
$$;

revoke execute on function public.send_message(text, uuid, uuid),
  public.conversation_for_listing(uuid), public.my_conversations(),
  public.post_announcement(text)
  from public, anon;
grant execute on function public.send_message(text, uuid, uuid),
  public.conversation_for_listing(uuid), public.my_conversations(),
  public.post_announcement(text)
  to authenticated;
