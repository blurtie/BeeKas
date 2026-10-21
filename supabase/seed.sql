-- KHUSUS LOKAL. Jangan pernah jalankan seed ini ke project cloud; admin cloud dibuat terpisah dengan password yang tidak ada di repo.
--
-- Seed admin (D-09): admin@beekas.test / BeeKasAdmin1

begin;

-- The profile goes in first (deferred FK) so handle_new_user skips this user.
set constraints all deferred;

insert into public.profiles (id, full_name, email, role, status, password_set_at)
values ('00000000-0000-4000-8000-000000000001', 'Admin BeeKas', 'admin@beekas.test', 'admin', 'approved', now());

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values (
  '00000000-0000-0000-0000-000000000000', '00000000-0000-4000-8000-000000000001',
  'authenticated', 'authenticated', 'admin@beekas.test',
  extensions.crypt('BeeKasAdmin1', extensions.gen_salt('bf')), now(),
  '{"provider": "email", "providers": ["email"]}', '{}', now(), now(),
  '', '', '', ''
);

insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
values (
  gen_random_uuid(), '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001',
  'email', '{"sub": "00000000-0000-4000-8000-000000000001", "email": "admin@beekas.test"}',
  now(), now(), now()
);

commit;

-- #74: sample catalog. Fictional approved sellers (no auth login, no phone) and their
-- listings. Photos are uploaded from supabase/seed-photos/ by the CLI (config.toml).
begin;
set constraints all deferred;

insert into public.profiles (id, full_name, email, account_type, campus, status) values
  ('00000000-0000-4000-8000-0000000000a1', 'Nadia Contoh', 'contoh.nadia@binus.ac.id', 'student', 'alam_sutera', 'approved'),
  ('00000000-0000-4000-8000-0000000000a2', 'Raka Contoh', 'contoh.raka@binus.ac.id', 'student', 'kemanggisan', 'approved'),
  ('00000000-0000-4000-8000-0000000000a3', 'Tio Contoh', 'contoh.tio@binus.ac.id', 'student', 'bandung', 'approved'),
  ('00000000-0000-4000-8000-0000000000a4', 'Sinta Contoh', 'contoh.sinta@binus.ac.id', 'student', 'senayan', 'approved');

insert into auth.users (instance_id, id, aud, role, email, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, now(), now()
from public.profiles where id::text like '00000000-0000-4000-8000-0000000000a_';

insert into public.listings
  (id, seller_id, title, description, category, condition, price, stock, campus, warranty, specs, is_donation, created_at)
values
  ('00000000-0000-4000-8000-0000000001b6', '00000000-0000-4000-8000-0000000000a4', 'Buku Exploring English',
   'Buku Exploring English: Culture and Language, masih rapi. Gratis untuk yang membutuhkan.',
   'books_stationery', 'used_good', 0, 1, 'senayan', null, null, true, now() - interval '6 hours'),
  ('00000000-0000-4000-8000-0000000001b5', '00000000-0000-4000-8000-0000000000a2', 'Hoodie Hitam Polos',
   'Hoodie hitam polos ukuran L, bahan fleece tebal. Ada dua, warna dan ukuran sama.',
   'clothing', 'like_new', 150000, 2, 'kemanggisan', null, array['Ukuran L', 'Fleece'], false, now() - interval '5 hours'),
  ('00000000-0000-4000-8000-0000000001b4', '00000000-0000-4000-8000-0000000000a3', 'Jam Tangan',
   'Jam tangan wanita rantai stainless, baterai baru diganti. Ada goresan halus di kaca.',
   'accessories', 'used_flawed', 120000, 1, 'bandung', 'Garansi toko 1 bulan', null, false, now() - interval '4 hours'),
  ('00000000-0000-4000-8000-0000000001b3', '00000000-0000-4000-8000-0000000000a1', 'Buku Bahasa Inggris',
   'Paket buku ACT Reading and Writing Skills dan Study Skills. Ada sedikit coretan pensil.',
   'books_stationery', 'used_good', 35000, 1, 'alam_sutera', null, null, false, now() - interval '3 hours'),
  ('00000000-0000-4000-8000-0000000001b2', '00000000-0000-4000-8000-0000000000a2', 'Jaket Uniqlo',
   'Jaket Uniqlo navy ukuran M, jarang dipakai.',
   'clothing', 'like_new', 250000, 1, 'kemanggisan', null, array['Ukuran M', 'Navy'], false, now() - interval '2 hours'),
  ('00000000-0000-4000-8000-0000000001b1', '00000000-0000-4000-8000-0000000000a1', 'Macbook Air M1',
   'Macbook Air M1 13 inch, warna space grey. Pemakaian 1 tahun. Kondisi masih sangat baik. Sudah termasuk charger original.',
   'laptop_computer', 'used_good', 7500000, 1, 'alam_sutera', null, array['Chip Apple M1', '8GB RAM', '256GB SSD'], false, now() - interval '1 hour');

-- The price drop fills the struck-through price (listings_previous_price).
update public.listings set price = 6500000 where id = '00000000-0000-4000-8000-0000000001b1';

insert into public.listing_photos (listing_id, position, path) values
  ('00000000-0000-4000-8000-0000000001b1', 1, 'macbook-1.jpg'),
  ('00000000-0000-4000-8000-0000000001b1', 2, 'macbook-2.jpg'),
  ('00000000-0000-4000-8000-0000000001b1', 3, 'macbook-3.jpg'),
  ('00000000-0000-4000-8000-0000000001b1', 4, 'macbook-4.jpg'),
  ('00000000-0000-4000-8000-0000000001b2', 1, 'jaket-1.jpg'),
  ('00000000-0000-4000-8000-0000000001b3', 1, 'buku-act-1.jpg'),
  ('00000000-0000-4000-8000-0000000001b4', 1, 'jam-tangan-1.jpg'),
  ('00000000-0000-4000-8000-0000000001b5', 1, 'hoodie-1.jpg'),
  ('00000000-0000-4000-8000-0000000001b6', 1, 'buku-english-1.jpg');

commit;

-- #33: where pg_cron calls send-decision-emails (Kong inside the local Docker network).
select vault.create_secret(
  'http://supabase_kong_BeeKas:8000/functions/v1/send-decision-emails', 'decision_emails_url');
-- The header pg_cron sends and the function checks. Local value only; cloud sets its own.
select vault.create_secret('local-decision-emails-cron-secret', 'decision_emails_cron_secret');

-- #41: where pg_cron calls delete-expired-photos, and its header secret. Local values only.
select vault.create_secret(
  'http://supabase_kong_BeeKas:8000/functions/v1/delete-expired-photos', 'photo_retention_url');
select vault.create_secret('local-photo-retention-cron-secret', 'photo_retention_cron_secret');
