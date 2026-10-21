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
