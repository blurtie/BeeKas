-- K7 Barang Saya (#83): edit, withdraw, relist after 60 days. is_active from #74 gives
-- way to the columns below; a listing is live while none of them hides it (is_live).

-- Admin removal (D-38) needs the admin and a reason; the admin RPC comes in T10.
alter table public.listings
  add column removed_at timestamptz,
  add column removed_by uuid references public.profiles,
  add column removal_reason text check (btrim(removal_reason) <> ''),
  add column withdrawn_at timestamptz,
  add constraint listings_removal check (
    (removed_at is null) = (removed_by is null)
    and (removed_at is null) = (removal_reason is null)
  );

-- Listings from before quotas had no end; they get 60 days from their creation.
update public.listings set expires_at = created_at + interval '60 days' where expires_at is null;
alter table public.listings
  alter column expires_at set default now() + interval '60 days',
  alter column expires_at set not null;

drop policy "listings: everyone reads active from listed sellers" on public.listings;
drop index public.listings_active_page;
alter table public.listings drop column is_active;

-- PRD-katalog 7.1: not removed, not withdrawn, not expired, stock left, seller listed.
create function public.is_live(l public.listings)
returns boolean
language sql
stable
set search_path = ''
as $$
  select l.removed_at is null and l.withdrawn_at is null and l.expires_at > now()
    and l.stock_left > 0 and public.is_listed_seller(l.seller_id);
$$;

revoke execute on function public.is_live(public.listings) from public;
grant execute on function public.is_live(public.listings) to anon, authenticated;

create policy "listings: everyone reads live"
  on public.listings for select to anon, authenticated
  using (public.is_live(listings));

-- Barang Saya: the owner reads every own listing, live or not, frozen or not. The
-- listing photos policy reads through this table, so it covers their photos too.
create policy "listings: owners read own"
  on public.listings for select to authenticated
  using (seller_id = (select auth.uid()));

create index listings_live_page on public.listings (created_at desc, id)
  where removed_at is null and withdrawn_at is null;

create or replace function public.catalog_listings(
  p_query text default null,
  p_categories public.listing_category[] default null,
  p_limit integer default 20,
  p_after_created_at timestamptz default null,
  p_after_id uuid default null,
  p_query_categories public.listing_category[] default null
)
returns table (
  id uuid,
  title text,
  description text,
  category public.listing_category,
  condition public.listing_condition,
  price integer,
  previous_price integer,
  stock integer,
  campus public.campus,
  warranty text,
  specs text[],
  is_donation boolean,
  created_at timestamptz,
  photos text[],
  seller_name text,
  seller_campus public.campus,
  seller_verified boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select l.id, l.title, l.description, l.category, l.condition, l.price, l.previous_price,
    l.stock, l.campus, l.warranty, l.specs, l.is_donation, l.created_at,
    coalesce(
      (select array_agg(ph.path order by ph.position) from public.listing_photos ph
        where ph.listing_id = l.id),
      '{}'
    ),
    p.full_name, p.campus, true
  from public.listings l
  join public.profiles p on p.id = l.seller_id
  -- The removed_at/withdrawn_at tests repeat is_live inline so the planner can use
  -- listings_live_page, whose predicate is exactly these two.
  where l.removed_at is null and l.withdrawn_at is null and public.is_live(l)
    -- strpos, not ilike: % and _ in the query stay plain text.
    and (coalesce(btrim(p_query), '') = ''
      or strpos(lower(l.title), lower(btrim(p_query))) > 0
      or strpos(lower(p.full_name), lower(btrim(p_query))) > 0
      or l.category = any (p_query_categories))
    and (p_categories is null or l.category = any (p_categories))
    and (p_after_created_at is null
      or l.created_at < p_after_created_at
      or (l.created_at = p_after_created_at and l.id > p_after_id))
  order by l.created_at desc, l.id
  limit least(greatest(coalesce(p_limit, 20), 1), 100);
$$;

-- The description limit is listings_description_check (K-04, 500). It was validated
-- on every row when added (#82), so an unchanged description always passes it.
-- Edit (D-28, K-06): name, category, sale/donation and photos are not parameters, so
-- they cannot change. Added or removed stock moves stock_left with it; stock below the
-- units already taken fails listings_stock_left. A price drop is struck through by
-- listings_previous_price (#75).
create function public.update_listing(
  p_id uuid,
  p_description text,
  p_condition public.listing_condition,
  p_price integer,
  p_stock integer,
  p_campus public.campus,
  p_warranty text,
  p_specs text[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_listed_seller(auth.uid()) then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  update public.listings
    set description = p_description, condition = p_condition, price = p_price,
      stock_left = stock_left + (p_stock - stock), stock = p_stock, campus = p_campus,
      warranty = p_warranty, specs = p_specs
    where id = p_id and seller_id = auth.uid() and removed_at is null and withdrawn_at is null;
  if not found then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
end;
$$;

-- Turunkan sendiri: no quota back (D-29). A frozen owner may still withdraw.
-- Follow-up T7 (#85): refuse while the listing has a running order; the orders
-- table does not exist yet.
create function public.withdraw_listing(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.listings set withdrawn_at = now()
    where id = p_id and seller_id = auth.uid() and removed_at is null and withdrawn_at is null;
  if not found then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
end;
$$;

-- K-07: an expired listing runs another 60 days, free of quota.
create function public.relist_listing(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_listed_seller(auth.uid()) then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  update public.listings set expires_at = now() + interval '60 days'
    where id = p_id and seller_id = auth.uid() and removed_at is null
      and withdrawn_at is null and expires_at <= now();
  if not found then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
end;
$$;

revoke execute on function public.update_listing(uuid, text, public.listing_condition, integer,
  integer, public.campus, text, text[]), public.withdraw_listing(uuid),
  public.relist_listing(uuid) from public, anon;
grant execute on function public.update_listing(uuid, text, public.listing_condition, integer,
  integer, public.campus, text, text[]), public.withdraw_listing(uuid),
  public.relist_listing(uuid) to authenticated;
