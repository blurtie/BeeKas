# Checklist pindah ke Supabase cloud

Langkah wajib sebelum aplikasi memakai project Supabase cloud. Menurut D-10, cukup mengganti URL dan kunci publik, tetapi pengaturan di bawah ini **tidak ikut terbawa** oleh migrasi SQL. Semuanya diatur di dashboard oleh pemilik project.

## 1. Template email OTP

Template bawaan hanya berisi tautan, tanpa kode 6 digit, sehingga pendaftar tidak bisa menyelesaikan L5 (#27).

Di **Authentication → Emails → Templates**, ubah dua template berikut supaya memakai `{{ .Token }}`. Isinya boleh disalin dari `supabase/templates/otp.html`:

- **Confirm signup**: dikirim ke email baru.
- **Magic link**: dikirim ke email yang sudah ada.

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
