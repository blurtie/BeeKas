# Menjalankan BeeKas secara lokal (Windows)

Backend selama pengembangan adalah Supabase lokal di Docker, di laptop (D-10). Emulator tersambung lewat `adb reverse` (bagian 5). HP fisik tersambung ke laptop lewat hotspot yang sama (bagian 4).

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

## 4. HP fisik: cari IP LAN laptop

Bagian ini hanya untuk HP fisik; emulator memakai `adb reverse` (bagian 5). HP tidak bisa memakai `localhost`, karena `localhost` di HP berarti HP itu sendiri. Pakai IP laptop di jaringan Wi-Fi/hotspot:

```powershell
ipconfig
```

Cari adapter yang sedang dipakai (misalnya "Wireless LAN adapter Wi-Fi") dan salin **IPv4 Address**, misalnya `192.168.1.23`. IP ini bisa berubah saat ganti jaringan; ulangi langkah ini dan perbarui `dart_defines.json`.

Uji HP lewat **hotspot sendiri** (dari HP atau laptop) yang di Windows diatur sebagai jaringan **Private**. Jangan memakai Wi-Fi kos, kampus, atau Wi-Fi umum: port Supabase akan terlihat oleh perangkat lain di jaringan itu, dan Wi-Fi kampus juga sering memblokir koneksi antarperangkat.

### Windows Firewall

Bila HP tidak bisa membuka `http://<IP-LAN>:54321/auth/v1/health` dari browsernya, izinkan port API untuk jaringan Private. Jalankan sekali di PowerShell **sebagai Administrator**:

```powershell
New-NetFirewallRule -DisplayName "BeeKas Supabase API (54321)" -Direction Inbound -Protocol TCP -LocalPort 54321 -Action Allow -Profile Private
```

Pastikan jaringan Wi-Fi/hotspot di Windows bertipe **Private** (Settings → Network & internet → Wi-Fi → properti jaringan).

### Peringatan: aturan firewall Docker Desktop

Docker Desktop membuat aturan inbound `com.docker.backend.exe` yang juga berlaku untuk profil **Public**. Aturan itu membuka **semua** port Supabase ke jaringan tempat laptop tersambung, termasuk Postgres (54322) dan Studio (54323), sehingga siapa pun di Wi-Fi umum bisa menjangkaunya.

Cek di PowerShell:

```powershell
Get-NetFirewallRule -DisplayName "com.docker.backend.exe" | Select-Object DisplayName, Enabled, Profile, Direction, Action
```

Bila ada baris yang `Enabled` = `True`, matikan semuanya (PowerShell **sebagai Administrator**):

```powershell
Get-NetFirewallRule -DisplayName "com.docker.backend.exe" | Disable-NetFirewallRule
```

Docker tetap jalan normal untuk akses dari laptop sendiri dan emulator. HP fisik memakai aturan port 54321 khusus Private di atas. **Cek ulang setiap kali Docker Desktop diperbarui**, karena update bisa membuat aturan itu lagi.

## 5. Jalankan aplikasi

1. Salin `dart_defines.example.json` menjadi `dart_defines.json` (sudah di `.gitignore`, jangan di-commit).
2. Isi `SUPABASE_PUBLISHABLE_KEY` dengan nilai "Publishable key", disalin dari output `supabase status`, lalu isi `SUPABASE_URL`:
   - **Emulator:** `http://127.0.0.1:54321`. Sebelum menjalankan aplikasi, teruskan port dari emulator ke laptop (ulangi setiap kali emulator dinyalakan ulang):
     ```powershell
     adb reverse tcp:54321 tcp:54321
     ```
   - **HP fisik:** `http://<IP-LAN>:54321` (bagian 4).
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
