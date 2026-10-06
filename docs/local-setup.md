# Menjalankan BeeKas secara lokal (Windows)

Backend selama pengembangan adalah Supabase lokal di Docker, di laptop (D-10). HP atau emulator tersambung ke laptop lewat Wi-Fi atau hotspot yang sama.

## 1. Pasang alat

1. **Docker Desktop:** unduh dari docker.com, pasang, lalu jalankan sampai statusnya "Engine running".
2. **Supabase CLI** lewat [scoop](https://scoop.sh):
   ```powershell
   scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
   scoop install supabase
   supabase --version
   ```
3. **Flutter 3.47.x stable** (Dart 3.13.x). Cek dengan `flutter --version`.

## 2. Nyalakan Supabase lokal

Dari folder repo:

```powershell
supabase start
```

Pertama kali, perintah ini mengunduh image Docker (beberapa menit). Migrasi di `supabase/migrations/` dan seed `supabase/seed.sql` dijalankan otomatis.

Lihat alamat dan kunci:

```powershell
supabase status
```

Perintah lain yang sering dipakai:

| Perintah | Gunanya |
|---|---|
| `supabase db reset` | Hapus data lokal, jalankan ulang semua migrasi dan seed |
| `supabase test db` | Jalankan tes database (`supabase/tests/database/`) |
| `supabase stop` | Matikan container |

Studio (tampilan tabel) ada di http://127.0.0.1:54323.

## 3. Akun admin seed

> **KHUSUS LOKAL. Jangan pernah jalankan seed ini ke project cloud; admin cloud dibuat terpisah dengan password yang tidak ada di repo.**

| Email | Kata sandi |
|---|---|
| `admin@beekas.test` | `BeeKasAdmin1` |

Hindari perintah yang menjalankan `seed.sql` ke project cloud: `supabase db reset --linked` (tanpa `--no-seed`), `supabase db push --include-seed`, dan versi `--db-url` dari keduanya.

## 4. Cari IP LAN laptop

HP tidak bisa memakai `localhost`, karena `localhost` di HP berarti HP itu sendiri. Pakai IP laptop di jaringan Wi-Fi/hotspot:

```powershell
ipconfig
```

Cari adapter yang sedang dipakai (misalnya "Wireless LAN adapter Wi-Fi") dan salin **IPv4 Address**, misalnya `192.168.1.23`. IP ini bisa berubah saat ganti jaringan; ulangi langkah ini dan perbarui `dart_defines.json`.

Wi-Fi kampus sering memblokir koneksi antarperangkat. Bila HP tidak bisa menjangkau laptop, pakai hotspot dari HP atau laptop.

### Windows Firewall

Bila HP tidak bisa membuka `http://<IP-LAN>:54321/auth/v1/health` dari browsernya, izinkan port API untuk jaringan Private. Jalankan sekali di PowerShell **sebagai Administrator**:

```powershell
New-NetFirewallRule -DisplayName "BeeKas Supabase API (54321)" -Direction Inbound -Protocol TCP -LocalPort 54321 -Action Allow -Profile Private
```

Pastikan jaringan Wi-Fi/hotspot di Windows bertipe **Private** (Settings → Network & internet → Wi-Fi → properti jaringan).

## 5. Jalankan aplikasi

1. Salin `dart_defines.example.json` menjadi `dart_defines.json` (sudah di `.gitignore`, jangan di-commit).
2. Isi `SUPABASE_URL` dengan `http://<IP-LAN>:54321` dan `SUPABASE_PUBLISHABLE_KEY` dengan nilai "Publishable key", disalin dari output `supabase status`.
3. Jalankan:
   ```powershell
   flutter run --dart-define-from-file=dart_defines.json
   ```

Tanpa file itu aplikasi berhenti dengan pesan bahwa `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` belum diisi.

Build debug Android mengizinkan `http` biasa (`android/app/src/debug/AndroidManifest.xml`) karena Supabase lokal tidak memakai HTTPS. Build release tidak.

## 6. Email OTP dan email lain

Supabase lokal tidak mengirim email ke internet. Semua email (OTP, persetujuan) ditangkap mail server lokal **Mailpit**: buka http://127.0.0.1:54324 di browser laptop.

## Masalah umum

- **Build Android gagal dengan `Could not close incremental caches ... different roots`**: terjadi bila repo dan pub cache ada di drive berbeda (misalnya repo di `D:`, pub cache di `C:`). Biasanya build tetap selesai; bila gagal, jalankan `flutter clean` lalu ulangi.
- **`supabase` atau `docker` tidak dikenal**: buka terminal baru setelah instalasi supaya PATH diperbarui.
