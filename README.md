# BeeKas

**Jual, beli, dan donasi barang bekas, khusus Binusian.**

BeeKas adalah marketplace preloved untuk mahasiswa, dosen, dan staf BINUS University. Setiap pengguna diverifikasi dengan email BINUS, foto kartu identitas, dan selfie, lalu transaksi dilakukan COD di kampus. Dibangun dengan Flutter (Android) dan Supabase, sebagai proyek akhir mata kuliah Venture Creation (ENPR6312001).

> BeeKas adalah proyek mahasiswa dan bukan layanan resmi Universitas Bina Nusantara.

**Status (22 Oktober 2026):** prototype berjalan di Supabase lokal. Target: dipakai pengguna sungguhan di BINUS Festival, 23–25 November 2026.

## Fitur

**Sudah ada:**

- **Akun dan verifikasi:** daftar dengan email `@binus.ac.id`/`@binus.edu`, kode OTP, persetujuan data, foto kartu dan selfie, pemeriksaan manual oleh admin (setujui atau tolak dengan alasan, kirim ulang), email hasil verifikasi, masuk, lupa kata sandi.
- **Katalog:** Beranda bertahap, pencarian di server (judul, kategori, penjual), 9 kategori, detail barang dengan harga coret dan stok. Tamu bisa melihat katalog.
- **Pasang barang:** jual atau donasi, 1–5 foto (metadata lokasi dibuang), Barang Saya (edit, turunkan, tayang ulang, kedaluwarsa 60 hari).
- **Kuota:** paket Rp15.000 isi 3 listing dibayar lewat QRIS, dikonfirmasi admin; 1 listing gratis untuk akun baru.
- **Transaksi:** Booking 24 Jam dan Beli Sekarang, COD di kampus, Pesanan Saya (pembelian dan penjualan), batal dan selesai otomatis.
- **Chat:** chat pembeli–penjual langsung, dengan peringatan bila berbagi kontak di luar aplikasi.
- **Lainnya:** onboarding, dua bahasa (EN/ID), Bantuan lewat email tim, Kebijakan Privasi dan S&K (draf).
- **Privasi:** foto kartu dan selfie dihapus otomatis paling lambat 30 hari setelah diperiksa; nomor HP opsional dan tidak pernah ditampilkan ke pengguna lain.

**Sedang dikerjakan (milestone BINUS Festival):** lapor dan moderasi, pembekuan akun oleh dua admin, profil, favorit, badge jumlah, Boost dan Featured, pindah ke Supabase cloud dan APK rilis. Daftar lengkapnya ada di [Issues](https://github.com/blurtie/BeeKas/issues) dan [docs/PRD-katalog.md](docs/PRD-katalog.md).

## Teknologi

| Bagian | Yang dipakai |
| --- | --- |
| Aplikasi | Flutter 3.47.x stable (Dart 3.13.x), Material 3, font Poppins |
| Backend | Supabase: Postgres dengan RLS, Auth, Storage, Realtime, Edge Functions, pg_cron |
| Pengembangan | Supabase lokal di Docker |
| Tes | `flutter test`, pgTAP (`supabase test db`), keduanya jalan di GitHub Actions |

Dependency aplikasi sengaja sedikit: `supabase_flutter`, `image_picker`, `shared_preferences`, dan `url_launcher`.

## Struktur

```
lib/
  config/    teks EN/ID (copy.dart) dan konfigurasi
  domain/    aturan bisnis, Dart murni, dengan tes
  data/      akses Supabase lewat repository
  screens/   layar
  ui/        tema, token warna, komponen
supabase/
  migrations/   skema, RLS, dan fungsi database
  functions/    Edge Functions (email keputusan, penghapusan foto)
  tests/        pgTAP dan skrip uji HTTP
docs/
  PRD.md, PRD-katalog.md   kebutuhan produk
  decisions.md             keputusan resmi (D-01, D-02, ...)
  local-setup.md           cara menjalankan di laptop
  cloud-checklist.md       langkah pindah ke cloud
  design/                  ekspor desain Figma dan screenshot
```

Istilah yang dipakai di kode dan dokumen ada di [CONTEXT.md](CONTEXT.md).

## Menjalankan

Butuh Docker Desktop, Supabase CLI, dan Flutter 3.47.x stable. Langkah lengkap untuk Windows, termasuk emulator, HP fisik, dan peringatan firewall, ada di [docs/local-setup.md](docs/local-setup.md).

```sh
flutter pub get
supabase start
cp dart_defines.example.json dart_defines.json   # isi URL dan publishable key dari `supabase status`
flutter run --dart-define-from-file=dart_defines.json
```

Email OTP dan email lain di lokal tertangkap di Mailpit: http://127.0.0.1:54324.

## Tes

```sh
flutter analyze
flutter test
supabase test db
```

## Cara kerja

- Satu issue, satu branch, satu Pull Request. Tidak ada push langsung ke `main`.
- PR di-merge dengan Squash and merge setelah CI hijau (Flutter dan pgTAP).
- Keputusan produk dicatat di [docs/decisions.md](docs/decisions.md) sebelum dibangun.
- Migration yang sudah ada di `main` tidak diubah; perubahan skema selalu lewat migration baru.

## Tim

| Peran | Nama |
| --- | --- |
| CEO | Clarencia Augustine |
| CTO | Muhammad Faiqi Harumantaka |
| CFO | Najwa Zukhrufa |
| CMO | Shanaa Salsabil Erawan |
| COO | Evan Jonathan Tjahjadi |

Versi web sebelumnya (Next.js + Supabase) tersimpan di tag [`web-nextjs-final`](https://github.com/blurtie/BeeKas/tree/web-nextjs-final).
