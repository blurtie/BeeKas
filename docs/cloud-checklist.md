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
2. **Admin per orang (D-40 K-39, D-21).** Tiap anggota tim mendaftar biasa lewat aplikasi (email BINUS + OTP). Lalu pemilik project memberi peran admin satu orang per perintah. Kata sandi tidak pernah dibagikan.
   ```sql
   update public.profiles set role = 'admin' where email = '<email anggota>' returning id, email, role, status;
   ```
   Harus mengembalikan tepat satu baris.

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

## 12. Smoke test dua HP lewat data seluler

Wi-Fi mati di kedua HP, supaya tidak ada ketergantungan pada LAN laptop. Pasang APK dari langkah 11.

1. HP A: daftar dengan email BINUS → OTP sampai → foto kartu dan selfie terkirim.
2. Admin menyetujui → email keputusan sampai (lewat Brevo; cek Spam). SQL: `select status, attempts, last_error from public.decision_emails order by id desc limit 3;` harus `sent`.
3. HP A pasang listing. HP B (akun lain, area sama) melihatnya di katalog, memesan, lalu chat dua arah.
4. Bayar kuota dengan QRIS asli → admin konfirmasi.
5. Lupa kata sandi di HP B → OTP sampai.

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
