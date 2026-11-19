# Checklist pindah ke Supabase cloud

Urutan dari nol untuk project **`chqcvqwmeczuxtepyuvh`** (Singapura, Free). Semua perintah cloud dijalankan pemilik project di terminalnya sendiri. Kata sandi DB, App Password Gmail, API key Brevo, isi `key.properties`, dan secret Vault **tidak pernah** ditulis di repo, issue, PR, atau chat. Keputusan email: D-48.

Ikuti berurutan. Bila hasil sebuah langkah berbeda dari lokal (grant, cron, bucket, fungsi), berhenti dan selidiki dulu.

## 0. Larangan

- **Jangan** `supabase db push --include-seed`, **jangan** `supabase db reset --linked`, dan jangan versi `--db-url`-nya. `seed.sql` berisi admin lokal (`admin@beekas.test`) dan data contoh (PR #44).
- Jangan unggah `supabase/seed-qris/qris.png` (gambar contoh) ke cloud.
- Firewall Windows dan `adb reverse` (`docs/local-setup.md`) tidak dibutuhkan untuk cloud.

## 1. SMTP Gmail untuk OTP Auth

1. Di akun Google `beekas2026@gmail.com`: aktifkan Verifikasi 2 Langkah, lalu buat App Password (Akun Google → Keamanan → Sandi aplikasi).
2. Dashboard → **Authentication → Emails → SMTP Settings**: aktifkan Custom SMTP.
   - Host `smtp.gmail.com`, port `587`, username `beekas2026@gmail.com`, password = App Password.
   - Sender email `beekas2026@gmail.com`, sender name `BeeKas`.
3. **Authentication → Emails → Templates**: ubah **Confirm signup**, **Magic link**, dan **Reset password** supaya memakai `{{ .Token }}`. Body disalin dari `supabase/templates/otp.html`; subjek `BeeKas verification code / Kode verifikasi BeeKas`. Template bawaan hanya berisi tautan, sehingga L5 (#27) tidak bisa selesai.
4. **Authentication → Rate Limits**:
   - Jeda antar email per pengguna **60 detik** (sama dengan `max_frequency = "60s"` lokal; aturan kirim ulang PRD L5).
   - Batas email per jam: setelah Custom SMTP aktif, naikkan dari bawaan (30/jam) sesuai perkiraan booth, mis. 100/jam. Gmail sendiri membatasi sekitar 500 email/hari per akun.
5. Cek: daftar dengan email BINUS uji; kode 6 digit harus sampai (periksa juga folder Spam).

## 1A. Pengaturan Auth (samakan dengan `supabase/config.toml`)

Isi lewat dashboard, satu per satu. **Jangan** `supabase config push`: perintah itu ikut menimpa SMTP, template, dan URL dengan nilai lokal.

| `config.toml` | Lokal | Dashboard cloud | Isi di cloud |
|---|---|---|---|
| `[auth.email] otp_length` | `6` | Authentication → Sign In / Providers → Email → Email OTP Length | `6` (bawaan cloud 8; layar OTP aplikasi 6 kotak) |
| `[auth.email] otp_expiry` | `3600` | idem → Email OTP Expiration | `3600` |
| `[auth.email] enable_confirmations` | `false` | idem → Confirm email | Biarkan **nyala** (lihat catatan) |
| `[auth.email] double_confirm_changes` | `true` | idem → Secure email change | nyala (bawaan) |
| `[auth.email] secure_password_change` | `false` | idem → Secure password change | mati (bawaan); kalau nyala, Lupa kata sandi butuh login ulang terbaru |
| `[auth] minimum_password_length` | `8` | idem → Minimum password length | `8` (bawaan cloud 6) |
| `[auth] password_requirements` | `letters_digits` | idem → Password Requirements | Letters and digits |
| `[auth] enable_signup`, `[auth.email] enable_signup` | `true` | Sign In / Providers → Allow new users to sign up; Email provider aktif | nyala |
| `[auth] enable_anonymous_sign_ins` | `false` | Sign In / Providers → Allow anonymous sign-ins | mati |
| `[auth.email] max_frequency` | `60s` | Authentication → Rate Limits → interval per pengguna (atau SMTP Settings → Minimum interval) | `60` detik |
| `[auth.rate_limit] email_sent` | `2` / jam | Rate Limits → emails sent | `100` / jam (lokal 2 hanya untuk Mailpit; lihat langkah 1) |
| `[auth.rate_limit] sign_in_sign_ups` | `30` / 5 menit / IP | Rate Limits → sign-ups and sign-ins | `30`; naikkan ke `100` bila booth memakai satu Wi-Fi bersama |
| `[auth.rate_limit] token_verifications` | `30` / 5 menit / IP | Rate Limits → token verifications | idem |
| `[auth.rate_limit] token_refresh` | `150` | Rate Limits → token refreshes | `150` (bawaan) |
| `[auth] jwt_expiry` | `3600` | Project Settings → JWT Keys | `3600` (bawaan) |
| `[auth] enable_refresh_token_rotation`, `refresh_token_reuse_interval` | `true`, `10` | Authentication → Sessions | bawaan |
| `[auth] site_url` | `http://127.0.0.1:3000` | Authentication → URL Configuration → Site URL | URL web milik tim (mis. situs Netlify BeeKas) atau biarkan bawaan; **bukan** 127.0.0.1. Redirect URLs dikosongkan |
| SMS, MFA, OAuth, Web3 | mati | — | mati (bawaan) |

**Confirm email.** Aplikasi tidak memakai `signUp(password)`. Daftar = `signInWithOtp` (membuat user dan mengirim kode) → `verifyOTP(type: email)` → `updateUser(password)` (`lib/data/signup_repository.dart`). Lupa kata sandi = `resetPasswordForEmail` → `verifyOTP(type: recovery)`. Email dianggap terkonfirmasi saat kode diverifikasi, jadi:
- **Nyala** (sekarang): user baru menerima template *Confirm signup*. Sudah teruji di cloud.
- **Mati** (seperti lokal): user baru menerima template *Magic link*. Isinya sama (keduanya `otp.html`), jadi perilaku aplikasi tidak berubah.
Tidak perlu diubah. Kalau diubah, tes ulang 12.1 karena template yang terkirim berbeda.

**Site URL** hanya dipakai untuk tautan di email dan redirect OAuth. Template BeeKas hanya berisi `{{ .Token }}` dan tidak ada OAuth, jadi nilainya tidak memengaruhi APK. Yang penting: jangan arahkan ke alamat lokal atau domain yang bukan milik tim, dan jangan tambah Redirect URLs.

## 2. Brevo untuk email keputusan verifikasi

1. Buat akun di brevo.com (paket Free).
2. **Senders, Domains & Dedicated IPs → Senders**: tambah `beekas2026@gmail.com`, nama `BeeKas`, lalu klik tautan verifikasi yang masuk ke Gmail.
3. **SMTP & API → API Keys**: buat API key baru. Tempel langsung ke langkah 6.3; jangan disimpan di file repo.

## 3. Ekstensi

Dashboard → **Database → Extensions**: aktifkan `pg_cron` dan `pg_net` (migration juga membuatnya; ini memastikan tersedia).

## 4. Link dan push migration (tanpa seed)

```sh
supabase login
supabase link --project-ref chqcvqwmeczuxtepyuvh
supabase migration list        # kolom Remote harus kosong sebelum push pertama
supabase db push               # TANPA --include-seed
supabase migration list        # Local dan Remote harus sama persis
```

Cek tidak ada data seed (SQL editor). Semua harus `0`:

```sql
select
  (select count(*) from auth.users)                                   as users,
  (select count(*) from auth.users where email like '%@beekas.test')  as seed_users,
  (select count(*) from public.profiles)                              as profiles,
  (select count(*) from public.listings)                              as listings,
  (select count(*) from vault.secrets)                                as vault_secrets,
  (select count(*) from storage.objects)                              as objects;
```

## 5. Bandingkan dengan lokal

Jalankan query berikut di **lokal** (Studio lokal, atau `docker exec supabase_db_BeeKas psql -U postgres -c "<query>"`) dan di **cloud** (SQL editor). Hasilnya harus identik.

Grant tabel/view `public` untuk `anon` dan `authenticated`:

```sql
select table_name, grantee, string_agg(privilege_type, ',' order by privilege_type) as privs
from information_schema.role_table_grants
where table_schema = 'public' and grantee in ('anon', 'authenticated')
group by table_name, grantee order by table_name, grantee;
```

Fungsi `public` yang bisa dieksekusi `anon`/`authenticated`:

```sql
select p.proname, r.rolname
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
cross join (values ('anon'), ('authenticated')) r(rolname)
where n.nspname = 'public' and has_function_privilege(r.rolname, p.oid, 'execute')
order by 1, 2;
```

RLS aktif di semua tabel `public` (harus kosong):

```sql
select relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
```

Bucket:

```sql
select id, public, file_size_limit, allowed_mime_types from storage.buckets order by id;
```

Project dibuat dengan "grant API access to new tables" dicentang, jadi cloud bisa punya grant lebih luas daripada lokal. Bila ada selisih, berhenti; jangan menambal lewat dashboard, perbaikannya lewat migration baru.

## 6. Vault, secret function, dan deploy

1. Buat dua nilai acak baru: `openssl rand -hex 32` (dua kali). **Bukan** nilai lokal dari `seed.sql`, dan keduanya harus berbeda.
2. SQL editor:
   ```sql
   select vault.create_secret('https://chqcvqwmeczuxtepyuvh.supabase.co/functions/v1/send-decision-emails', 'decision_emails_url');
   select vault.create_secret('<nilai acak 1>', 'decision_emails_cron_secret');
   select vault.create_secret('https://chqcvqwmeczuxtepyuvh.supabase.co/functions/v1/delete-expired-photos', 'photo_retention_url');
   select vault.create_secret('<nilai acak 2>', 'photo_retention_cron_secret');
   -- Cek tanpa menampilkan nilai: harus 4 baris
   select name from vault.secrets order by name;
   ```
   Mengganti: `select vault.update_secret(id, '<nilai baru>') from vault.secrets where name = '<nama>';`
3. Secret Edge Function lewat dashboard **Edge Functions → Secrets** (bukan `supabase secrets set`, supaya API key tidak masuk riwayat shell):
   - `BREVO_API_KEY` = API key Brevo
   - `EMAIL_FROM` = `beekas2026@gmail.com`
   - `EMAIL_FROM_NAME` = `BeeKas`

   `EMAIL_API` tidak diisi di cloud (kosong berarti `brevo`; lokal memakai `mailpit` dari `config.toml`). Bila salah satu secret kosong, log function menulis `missing secrets for "brevo": <nama>` dan antrean tidak diklaim; baris tetap `pending`.
4. Deploy:
   ```sh
   supabase functions deploy send-decision-emails --no-verify-jwt
   supabase functions deploy delete-expired-photos --no-verify-jwt
   supabase functions list        # keduanya ACTIVE
   ```

## 7. Empat cron wajib

```sql
select jobname, schedule, active from cron.job order by jobname;
```

Harus tepat empat baris, semua `active = true`:

| jobname | schedule |
|---|---|
| `delete-expired-photos` | `0 3 * * *` |
| `donation-bids` | `* * * * *` |
| `order-timers` | `*/10 * * * *` |
| `send-decision-emails` | `* * * * *` |

Run terakhir (tunggu 2 menit setelah deploy; `delete-expired-photos` baru jalan 03:00 UTC):

```sql
select j.jobname, d.status, d.return_message, d.start_time
from cron.job_run_details d join cron.job j using (jobid)
where d.start_time > now() - interval '15 minutes'
order by d.start_time desc limit 20;
```

Status harus `succeeded`. Respons HTTP dari `pg_net` (401 = secret Vault tidak cocok):

```sql
select id, status_code, left(content::text, 200) as body, created
from net._http_response order by created desc limit 5;
```

`send-decision-emails` yang sehat menjawab `200` dengan `{"sent":0,"claimed":0}` bila antrean kosong. Untuk mencoba `delete-expired-photos` tanpa menunggu 03:00 UTC:

```sql
select cron.schedule('delete-expired-photos-once', '* * * * *',
  (select command from cron.job where jobname = 'delete-expired-photos'));
-- tunggu 1 menit, cek net._http_response (200), lalu:
select cron.unschedule('delete-expired-photos-once');
```

## 8. QRIS dan admin

1. **QRIS (K-09, D-29, D-35).** Setelah CFO setuju, unggah gambar QRIS asli ke bucket publik `payment-qris` dengan nama tepat `qris.png` (PNG/JPEG, ≤ 1 MB) lewat **Storage**. Gambar dan nama CFO tidak di-commit. Mengganti cukup menimpa file yang sama; aplikasi tidak perlu dirilis ulang.
2. **Dua admin untuk Festival (D-49, mengubah D-40 K-39).** Hanya Faiqi dan satu anggota lain yang jadi admin; anggota lain tetap member agar bisa demo belanja (admin belum bisa membuka katalog). Calon admin mendaftar biasa lewat aplikasi (email BINUS + OTP), lalu pemilik project memberi peran admin satu orang per perintah. Kata sandi tidak pernah dibagikan.
   ```sql
   update public.profiles set role = 'admin' where email = '<email anggota>' returning id, email, role, status;
   ```
   Harus mengembalikan tepat satu baris. Total admin harus 2: `select count(*) from public.profiles where role = 'admin';`

## 9. Security Advisor dan backup

1. Dashboard → **Advisors → Security Advisor**: tidak boleh ada temuan level ERROR. Catat WARN yang muncul.
2. Backup manual `pg_dump` (Free tidak punya backup harian; D-40 K-41), sebelum Festival dan setiap hari selama Festival. `supabase db dump` memakai `pg_dump` lewat project yang sudah di-link; kata sandi DB diketik saat diminta:
   ```sh
   supabase db dump --linked -f backup-schema-YYYYMMDD.sql
   supabase db dump --linked --data-only -f backup-data-YYYYMMDD.sql
   ```
   Simpan di luar repo (berisi data pribadi).

## 10. Signing APK rilis (#92)

Build rilis ditandatangani kunci dari `android/key.properties`. Bila file itu tidak ada atau kurang isinya, build **gagal** dengan `Release signing: android/key.properties is missing ...`; tidak pernah jatuh ke kunci debug. Keystore dan kata sandinya disimpan di luar repo dengan minimal dua pemegang. `key.properties`, `*.jks`, dan `*.keystore` ada di `android/.gitignore`.

1. Buat keystore (sekali saja), di luar repo:
   ```sh
   keytool -genkeypair -v -keystore <path di luar repo>/beekas-release.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias beekas
   ```
2. `android/key.properties` (tidak di-commit):
   ```properties
   storePassword=<kata sandi keystore>
   keyPassword=<kata sandi kunci>
   keyAlias=beekas
   storeFile=<path absolut ke beekas-release.jks>
   ```
3. Cadangkan `.jks` dan kedua kata sandi di dua tempat milik dua orang berbeda. Kunci hilang berarti APK baru tidak bisa memperbarui APK lama.

## 11. Build APK booth

1. Buat `dart_defines.cloud.json` di root repo (tidak di-commit; `dart_defines*.json` diabaikan git kecuali contoh). Isinya hanya nilai publik:
   ```json
   {
     "SUPABASE_URL": "https://chqcvqwmeczuxtepyuvh.supabase.co",
     "SUPABASE_PUBLISHABLE_KEY": "<Publishable key dari Project Settings → API Keys>"
   }
   ```
   Jangan pernah memakai `secret`/`service_role` key di sini.
2. Build:
   ```sh
   flutter build apk --release --dart-define-from-file=dart_defines.cloud.json
   ```
3. Cek tanda tangan. APK v2/v3 tidak terbaca `keytool -printcert`; pakai `apksigner` dari `<Android SDK>/build-tools/<versi>/`:
   ```sh
   apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
   ```
   Harus tanpa error dan `Signer #1 certificate DN` = sertifikat rilis, bukan `CN=Android Debug`.

## 12. Smoke test tiga perangkat lewat data seluler

Admin saat ini hanya membuka konsol admin (Verifikasi, Payments, Announcements), tanpa katalog. Jadi admin **tidak** dipakai untuk memesan atau menawar.

| Peran | Perangkat | Tugas |
|---|---|---|
| Admin | HP fisik 1, data seluler | menyetujui akun dan pembayaran |
| Member 1 | emulator, internet laptop | penjual dan donatur |
| Member 2 | HP fisik 2, data seluler (APK lewat WhatsApp/Drive, izinkan "instal dari sumber ini") | pembeli dan penawar donasi |

Semua member di area kampus yang sama (mis. Jabodetabek, D-47).

**12.A Admin.** Daftar dengan email BINUS → OTP → berkas terkirim. Jadikan admin (harus tepat 1 baris):
```sql
update public.profiles set role = 'admin', status = 'approved'
where email = '<email admin>' and status <> 'approved'
returning id, email, role, status;
```
Buka ulang aplikasi → konsol admin muncul.

**12.B Member 1 dan Member 2 disetujui lewat aplikasi.**
1. Member 1 dan Member 2 daftar → OTP sampai → foto kartu dan selfie terkirim → layar "Verification in progress".
2. Admin: Verifikasi → setujui keduanya.
3. Email keputusan sampai ke keduanya (lewat Brevo; cek Spam):
   ```sql
   select profile_id, kind, status, attempts, last_error from public.decision_emails order by id desc limit 2;
   ```
   Harus 2 baris `sent`.
4. Buka ulang aplikasi di kedua member → beranda katalog; layar Kuota menunjukkan **1**.

**12.C Pesanan, chat, kuota, lupa kata sandi.**
1. Member 1 pasang listing biasa (saldo 1 → 0).
2. Member 2 melihatnya di katalog, Booking 24 Jam atau Beli Sekarang, lalu chat dua arah dengan Member 1.
3. Member 1 beli kuota: layar QRIS tampil, unggah bukti → Admin: Payments → konfirmasi → saldo Member 1 bertambah 3. Selama QRIS masih gambar dummy, cukup cek alurnya, jangan bayar sungguhan.
4. Lupa kata sandi di Member 2 → OTP sampai → masuk dengan kata sandi baru. (Sudah teruji juga lewat pemulihan pendaftaran Admin.)

**12.D Donasi lewat tawaran token (D-46) tanpa menunggu 24 jam.** Ini **satu-satunya** perubahan data lewat SQL selama smoke test.
1. Member 1 pasang listing **donasi**. Saldo Member 1 tidak berubah: listing donasi tidak memakai kuota (D-46).
2. Member 2 cek layar Kuota: saldo harus **1** (belum dipakai karena Member 2 hanya membeli). Lalu tawar 1 token. Saldo langsung jadi 0 (token ditahan).
3. Ambil id listing:
   ```sql
   select id, title, bid_ends_at, stock_left from public.listings
   where is_donation and bid_ends_at is not null order by created_at desc;
   ```
4. Majukan waktu habis **listing itu saja**. Harus mengembalikan tepat 1 baris:
   ```sql
   update public.listings set bid_ends_at = now() - interval '1 minute'
   where id = '<id listing>' and is_donation and bid_ends_at is not null
   returning id, title, bid_ends_at;
   ```
5. Tunggu 1–2 menit (cron `donation-bids` tiap menit memanggil `close_donation_bids()`), lalu cek:
   ```sql
   select b.status, b.amount, b.order_id is not null as has_order, o.price, o.status as order_status,
     (select balance from public.quota_balances where member_id = b.bidder_id) as bidder_balance,
     l.bid_ends_at, l.stock_left
   from public.donation_bids b
   join public.listings l on l.id = b.listing_id
   left join public.orders o on o.id = b.order_id
   where b.listing_id = '<id listing>';
   ```
   Harus: `status = won`, `has_order = true`, `price = 0`, `order_status = waiting`, `bidder_balance = 0` (token pemenang terpakai, tidak dikembalikan), `bid_ends_at` null, `stock_left` berkurang 1. Member 2 melihat pesanan Rp0 di Pesanan Saya.

## Catatan booth

- Pengguna yang melihat "email sudah terdaftar" saat daftar (pendaftaran sebelumnya terputus sebelum kata sandi dibuat): arahkan ke **Sign in → Lupa kata sandi**. Kode 6 digit dikirim, kata sandi dibuat, lalu aplikasi melanjutkan ke data diri, foto kartu, dan selfie. Teruji di smoke test 12.1.

## Pemantauan

```sql
-- Email keputusan gagal 5x (tidak dicoba lagi)
select id, profile_id, kind, attempts, last_error, created_at
from public.decision_emails where status = 'failed' order by id;
-- Antrekan ulang setelah penyebabnya diperbaiki
update public.decision_emails set status = 'pending', attempts = 0, last_error = null where status = 'failed';

-- Harus kosong setelah run harian
select * from public.expired_verification_photos();
select * from public.expired_payment_proofs();

-- Pembayaran menunggu > 24 jam (D-29)
select id, member_id, created_at from public.payments
where status = 'pending' and created_at < now() - interval '24 hours' order by created_at;

-- Pesanan yang timer-nya tertinggal (harus kosong)
select id from public.orders where status = 'waiting' and hold_until < now() - interval '15 minutes';
select id from public.orders where status = 'processing' and cod_at < now() - interval '3 days 15 minutes';
```

Email keputusan bersifat *at-least-once*: bisa terkirim dua kali bila function mati setelah kirim tapi sebelum ditandai `sent`. Log `delete-expired-photos` tidak boleh berisi `NOT RECORDED`.
