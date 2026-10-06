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
