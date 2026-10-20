# Checklist pindah ke Supabase cloud

Langkah wajib sebelum aplikasi memakai project Supabase cloud. Menurut D-10, cukup mengganti URL dan kunci publik, tetapi pengaturan di bawah ini **tidak ikut terbawa** oleh migrasi SQL. Semuanya diatur di dashboard oleh pemilik project.

## 1. Template email OTP

Template bawaan hanya berisi tautan, tanpa kode 6 digit, sehingga pendaftar tidak bisa menyelesaikan L5 (#27).

Di **Authentication → Emails → Templates**, ubah tiga template berikut supaya memakai `{{ .Token }}`. Isinya boleh disalin dari `supabase/templates/otp.html`:

- **Confirm signup**: dikirim ke email baru.
- **Magic link**: dikirim ke email yang sudah ada.
- **Reset password**: dikirim saat Lupa kata sandi (#34).

Subjek yang dipakai lokal: `BeeKas verification code / Kode verifikasi BeeKas`.

## 2. Jeda kirim ulang email: 60 detik

Di **Authentication → Rate Limits**, pastikan jeda minimum antar email adalah **60 detik**. Ini nilai bawaan cloud dan sama dengan `max_frequency = "60s"` di `supabase/config.toml`. Aturan "kirim ulang aktif setelah 60 detik" (PRD L5) ditegakkan oleh nilai ini, bukan oleh aplikasi.

## 3. Admin cloud dibuat terpisah (D-18)

Buat akun admin cloud secara manual, dengan kata sandi yang **tidak pernah** ditulis di repo, issue, PR, atau chat. Akun `admin@beekas.test` dari seed hanya untuk lokal.

## 4. Jangan jalankan `seed.sql` ke cloud

`supabase/seed.sql` berisi kata sandi admin lokal. Hindari perintah berikut (PR #44):

- `supabase db reset --linked` tanpa `--no-seed`
- `supabase db push --include-seed`
- versi `--db-url` dari kedua perintah di atas

Untuk cloud, pakai `supabase db push` (tanpa `--include-seed`).

## 5. Firewall lokal tidak relevan

Aturan Windows Firewall dan peringatan `com.docker.backend.exe` di `docs/local-setup.md` hanya berlaku untuk Supabase lokal di laptop. Project cloud tidak memerlukannya, dan `adb reverse` juga tidak dibutuhkan.

## 6. Email keputusan verifikasi (#33)

Email disetujui/ditolak dikirim Edge Function `send-decision-emails` lewat **API HTTP** penyedia email, bukan SMTP: Edge Functions cloud memblokir port keluar 25 dan 587 ([Supabase: Limits](https://supabase.com/docs/guides/functions/limits)). Penyedia belum dipilih. Pilihannya harus punya API kirim HTTP dan domain pengirim terverifikasi. Pengirim untuk penyedia itu baru ditulis di `supabase/functions/send-decision-emails/index.ts` setelah dipilih.

1. Deploy function: `supabase functions deploy send-decision-emails --no-verify-jwt`.
2. Di **Edge Functions → Secrets**, isi `EMAIL_API` (nama mode penyedia), `EMAIL_FROM`, dan kunci API penyedia. Kunci **tidak pernah** ditulis di repo, issue, PR, atau chat. Selama `EMAIL_API` kosong atau belum dikenal, function hanya mencatat peringatan dan antrean tetap `pending` tanpa menambah `attempts`.
3. Di SQL editor, simpan URL function dan secret bersama untuk `pg_cron` di Vault (sekali saja). `pg_cron` mengirim secret itu di header `x-cron-secret`; function membandingkannya (waktu-konstan) dengan nilai di Vault dan menolak dengan 401 bila tidak cocok. Buat nilai acak yang panjang, mis. `openssl rand -hex 32`, dan **jangan** pakai nilai lokal dari `seed.sql`. Nilainya tidak pernah ditulis di repo, issue, PR, atau chat:
   ```sql
   select vault.create_secret('https://<project-ref>.supabase.co/functions/v1/send-decision-emails', 'decision_emails_url');
   select vault.create_secret('<nilai acak>', 'decision_emails_cron_secret');
   ```
   Untuk mengganti secret: `select vault.update_secret(id, '<nilai baru>') from vault.secrets where name = 'decision_emails_cron_secret';`
4. Pantau dan antrekan ulang. Baris yang gagal kirim 5 kali berstatus `failed` dan tidak dicoba lagi:
   ```sql
   -- Melihat yang gagal
   select id, profile_id, kind, attempts, last_error, created_at
   from public.decision_emails where status = 'failed' order by id;

   -- Mengantrekan ulang (setelah penyebabnya diperbaiki)
   update public.decision_emails
   set status = 'pending', attempts = 0, last_error = null
   where status = 'failed';
   ```
   Pengiriman bersifat *at-least-once*: bila function mati setelah email terkirim tapi sebelum ditandai `sent`, email bisa terkirim dua kali.

## 7. Penghapusan foto 30 hari (#41, D-07)

Edge Function `delete-expired-photos` dipanggil `pg_cron` setiap hari pukul 03:00 UTC (10:00 WIB). Function menghapus foto kartu dan selfie sebuah percobaan yang diputuskan lebih dari 29 hari lalu (disetujui: `approved_at`; ditolak: `rejected_at` percobaan itu), sehingga foto selalu terhapus paling lambat hari ke-30. Percobaan yang tidak pernah dikirim dihapus dengan cara yang sama, dihitung dari unggahan terakhirnya (#65); kolom `reason` di `photo_deletions` membedakan `decided` dan `never_submitted`. Tidak ada function atau secret baru. Penghapusan lewat Storage API, karena `DELETE` lewat SQL di `storage.objects` membuat file yatim di bucket ([Supabase: Delete Objects](https://supabase.com/docs/guides/storage/management/delete-objects)).

1. Deploy: `supabase functions deploy delete-expired-photos --no-verify-jwt`.
2. Di SQL editor, simpan URL dan secret bersama di Vault (sekali saja). Buat nilai acak baru (mis. `openssl rand -hex 32`), **bukan** nilai lokal dari `seed.sql` dan bukan secret email keputusan. Nilainya tidak pernah ditulis di repo, issue, PR, atau chat:
   ```sql
   select vault.create_secret('https://<project-ref>.supabase.co/functions/v1/delete-expired-photos', 'photo_retention_url');
   select vault.create_secret('<nilai acak>', 'photo_retention_cron_secret');
   ```
3. Bukti penghapusan dan pemantauan:
   ```sql
   -- Penghapusan yang sudah dijalankan
   select profile_id, attempt, objects, deleted_at from public.photo_deletions order by deleted_at desc;

   -- Foto yang sudah jatuh tempo tapi belum terhapus (harus kosong setelah run harian)
   select * from public.expired_verification_photos();

   -- Hasil panggilan pg_cron
   select status, return_message, start_time from cron.job_run_details
   where jobid = (select jobid from cron.job where jobname = 'delete-expired-photos')
   order by start_time desc limit 5;
   ```
   Kegagalan per percobaan tercatat di log function sebagai `delete-expired-photos: <profile>/<attempt> failed: ...` dan dicoba lagi pada run berikutnya.
