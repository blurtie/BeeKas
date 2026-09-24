# Pengaturan Supabase

Daftar pengaturan di dashboard Supabase yang tidak tersimpan di repo. Project yang dipakai saat ini adalah `beekas-dev`.

**Project produksi di Fase 7 harus dibuat mengikuti daftar ini.** Setiap kali pengaturan di dashboard diubah, perbarui berkas ini dalam PR yang sama dengan perubahan kode terkait.

## Project

| Pengaturan | Nilai | Alasan |
|---|---|---|
| Region | Singapore | Terdekat dengan pengguna di Jakarta. |
| Data API | Aktif | supabase-js memakai Data API (PostgREST). |
| Automatically expose new tables | Nonaktif | Tabel baru tidak terbuka sampai ada `GRANT` eksplisit di migrasi. |
| Automatic RLS | Aktif | Setiap tabel baru langsung memakai Row Level Security; akses dibuka lewat policy di migrasi. |

## Auth: URL

| Pengaturan | Nilai | Alasan |
|---|---|---|
| Site URL | `https://beekas.netlify.app` | URL default yang dipakai Supabase Auth. |
| Redirect URLs | `https://beekas.netlify.app`, `https://beekas.netlify.app/**`, `https://*--beekas.netlify.app/**`, `http://localhost:3000`, `http://localhost:3000/**` | Pengembangan lokal, produksi, dan semua Deploy Preview Netlify. |

Login hanya memakai kode 6 digit, sehingga Redirect URLs tidak dipakai oleh alur login saat ini. Daftar ini tetap dijaga untuk fitur Auth lain.

## Auth: email

| Pengaturan | Nilai | Alasan |
|---|---|---|
| SMTP | Kustom: Gmail, akun `beekas2026@gmail.com` dengan App Password | SMTP bawaan punya batas kirim rendah dan template tidak dapat diubah (D-14). SMTP transaksional dengan domain sendiri menyusul di Fase 7. |
| SMTP host dan port | `smtp.gmail.com`, port 465 | Port 465 memakai SSL/TLS langsung. |
| Nama pengirim | BeeKas | |
| Password SMTP | Tidak dicatat di repo | Kredensial. Disimpan hanya di dashboard. |
| Template "Magic Link" | Hanya berisi `{{ .Token }}`, tanpa tautan | Login lewat tautan gagal di Outlook BINUS (D-14). |
| Template "Confirm signup" | Hanya berisi `{{ .Token }}`, tanpa tautan | Sama dengan di atas. Pendaftaran baru memakai template ini. |
| Email OTP Length | 6 | Harus sama dengan `OTP_LENGTH` di `src/lib/domain/otp.ts`. Nilai default Supabase (8) membuat kode ditolak oleh formulir. |
| Minimum interval antar email | 60 detik | Mencegah pengiriman kode beruntun ke alamat yang sama. |
| Rate limit email per jam | 30 | Batas ini perlu dinaikkan sebelum promosi di BINUS Festival (D-01). |

## Migrasi basis data

Migrasi dijalankan manual lewat SQL Editor, berurutan sesuai nomor berkas di `supabase/migrations/`:

1. `0001_profiles.sql`: tabel `profiles`, validasi domain email kampus, pemblokiran perubahan email, RLS, dan `get_public_profile`.
2. `0002_majors_campuses.sql`: daftar kampus final, daftar jurusan, jurusan wajib untuk mahasiswa (diisi bersama BINUSIAN).

Setelah menjalankan migrasi, jalankan `node --env-file=.env.local scripts/rls-check.mjs` untuk memastikan RLS berjalan. Skrip ini membutuhkan `SUPABASE_SERVICE_ROLE_KEY` di `.env.local`.
