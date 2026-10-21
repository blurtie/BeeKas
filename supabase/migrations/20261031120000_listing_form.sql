-- K5-K6 Pasang barang (#82): description limit, remaining stock, photo uploads.

-- K-04: 500 characters, as in the Tambah Barang design.
alter table public.listings drop constraint listings_description_check;
alter table public.listings add constraint listings_description_check
  check (btrim(description) <> '' and char_length(description) <= 500);

-- PRD-katalog 7.1: remaining stock, changed only by the order functions (later).
alter table public.listings add column stock_left integer;
update public.listings set stock_left = stock;
alter table public.listings alter column stock_left set not null;
alter table public.listings add constraint listings_stock_left
  check (stock_left between 0 and stock);

create function public.set_stock_left()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.stock_left := new.stock;
  return new;
end;
$$;

revoke execute on function public.set_stock_left() from public, anon, authenticated;

-- A new listing starts with all its stock left.
create trigger listings_stock_left
  before insert on public.listings
  for each row execute function public.set_stock_left();

-- K-05: the app converts every photo to JPEG before upload.
update storage.buckets set allowed_mime_types = array['image/jpeg']
  where id = 'listing-photos';

-- Sellers (approved, not frozen) upload into their own folder: <uid>/<name>.jpg.
create policy "listing photos: listed sellers upload own"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'listing-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and array_length(storage.foldername(name), 1) = 1
    and storage.filename(name) ~ '^[A-Za-z0-9_-]+\.jpg$'
    and (select public.is_listed_seller(auth.uid()))
  );

-- Whether a listing (any state) uses this photo; listing_photos RLS hides inactive ones.
create function public.is_listing_photo(p_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.listing_photos where path = p_path);
$$;

revoke execute on function public.is_listing_photo(text) from public, anon;
grant execute on function public.is_listing_photo(text) to authenticated;

-- The Storage API reads a row before deleting it, so the owner needs both: the app
-- removes photos whose listing was not created. Photos a listing uses stay (D-28: no
-- photo changes after listing).
create policy "listing photos: owners read own"
  on storage.objects for select to authenticated
  using (bucket_id = 'listing-photos' and owner_id = (select auth.uid())::text);

create policy "listing photos: owners delete own"
  on storage.objects for delete to authenticated
  using (bucket_id = 'listing-photos' and owner_id = (select auth.uid())::text
    and not public.is_listing_photo(name));

-- create_listing takes the listing id from the app (one per draft), so a retry after a
-- lost answer returns the listing already made instead of taking a second quota.
drop function public.create_listing(text, text, public.listing_category,
  public.listing_condition, integer, integer, public.campus, text, text[], boolean, text[]);

create function public.create_listing(
  p_title text,
  p_description text,
  p_category public.listing_category,
  p_condition public.listing_condition,
  p_price integer,
  p_stock integer,
  p_campus public.campus,
  p_warranty text,
  p_specs text[],
  p_is_donation boolean,
  p_photos text[],
  p_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := coalesce(p_id, gen_random_uuid());
  v_seller uuid;
begin
  if auth.uid() is null or not public.is_listed_seller(auth.uid()) then
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  -- Two calls with one id wait for each other here, so only one inserts.
  perform pg_advisory_xact_lock(hashtextextended(v_id::text, 0));
  select seller_id into v_seller from public.listings where id = v_id;
  if found then
    if v_seller = auth.uid() then
      return v_id;
    end if;
    raise exception 'not_allowed' using errcode = 'insufficient_privilege';
  end if;
  -- D-28: 1-5 photos. listing_photos caps the positions at 5.
  if coalesce(cardinality(p_photos), 0) < 1 then
    raise exception 'no_photos' using errcode = 'check_violation';
  end if;
  -- PRD-katalog 7.1: sellers upload only into their own folder.
  if exists (select 1 from unnest(p_photos) path where path is null or path not like auth.uid()::text || '/%' or path like '%..%') then
    raise exception 'not_own_photo' using errcode = 'insufficient_privilege';
  end if;

  update public.quota_balances set balance = balance - 1
    where member_id = auth.uid() and balance >= 1;
  if not found then
    raise exception 'no_quota' using errcode = 'check_violation';
  end if;

  insert into public.listings (id, seller_id, title, description, category, condition,
    price, stock, campus, warranty, specs, is_donation, expires_at)
  values (v_id, auth.uid(), p_title, p_description, p_category, p_condition, p_price,
    p_stock, p_campus, p_warranty, p_specs, p_is_donation, now() + interval '60 days');

  insert into public.listing_photos (listing_id, position, path)
  select v_id, ord, path from unnest(p_photos) with ordinality as t(path, ord);

  insert into public.quota_ledger (member_id, delta, reason, listing_id)
  values (auth.uid(), -1, 'listing', v_id);
  return v_id;
end;
$$;

revoke execute on function public.create_listing(text, text, public.listing_category,
  public.listing_condition, integer, integer, public.campus, text, text[], boolean, text[],
  uuid) from public, anon;
grant execute on function public.create_listing(text, text, public.listing_category,
  public.listing_condition, integer, integer, public.campus, text, text[], boolean, text[],
  uuid) to authenticated;
