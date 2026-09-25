-- 0004_listing_photos.sql
-- Public-read bucket for listing photos (PRD F4.2, D-17.3).
-- Paste into the Supabase SQL Editor after 0003. Re-running is safe.
--
-- Reads go through the public URL, so no select policy is needed (and none is
-- given, so the API cannot list other Members' files). Members may only
-- insert into their own "<user_id>/" folder. No update/delete policy exists,
-- so an existing file can never be overwritten (upsert needs update).

-- Must match LISTING_PHOTO_BUCKET and PHOTO_MAX_BYTES in src/lib/domain/listing-photo.ts.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('listing-photos', 'listing-photos', true, 2097152, array['image/jpeg'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists listing_photos_insert_own on storage.objects;
create policy listing_photos_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'listing-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
