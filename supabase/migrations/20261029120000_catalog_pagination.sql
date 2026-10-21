-- Catalog pages and search on the server (#77, D-28). Keyset (created_at desc, id):
-- pass the last row's created_at and id to get the next page. The query matches the
-- title or the seller's name, any case, or a category in p_query_categories: the app
-- maps a query equal to a label word (EN or ID) to those codes (K-02, D-41). A Beranda
-- shortcut sends its group as p_categories, which always restricts.

drop function public.catalog_listings();

create function public.catalog_listings(
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
  where l.is_active and public.is_listed_seller(l.seller_id)
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

revoke execute on function public.catalog_listings(text, public.listing_category[], integer, timestamptz, uuid, public.listing_category[]) from public;
grant execute on function public.catalog_listings(text, public.listing_category[], integer, timestamptz, uuid, public.listing_category[]) to anon, authenticated;

-- Serves the keyset order; the (created_at desc) index from #74 cannot break ties.
drop index public.listings_active_newest;
create index listings_active_page on public.listings (created_at desc, id) where is_active;
