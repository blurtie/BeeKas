# Roadmap BeeKas

Versi 0.1 (23 September 2026). Acuan kebutuhan ada di [`PRD.md`](PRD.md), keputusan di [`decisions.md`](decisions.md).

Asisten koding boleh mencentang item yang sudah selesai dan terverifikasi, tetapi tidak boleh menambah, menghapus, atau mengubah urutan fase tanpa persetujuan tim.

## Tanggal patokan

| Patokan | Tanggal |
|---|---|
| BINUS Festival | _belum diisi_ |
| Tenggat Business Report | _belum diisi_ |
| Minggu UTS | _belum diisi_ |
| Minggu UAS | _belum diisi_ |

Sampai tanggal diisi, fase di bawah hanya diurutkan, belum dijadwalkan.

## Prinsip

1. **Desain Figma bukan penghalang development.** Sebagian besar pekerjaan berupa logika dan data: auth, database, kuota, booking, AI, dan admin. Semuanya dibangun dengan tampilan sederhana yang memakai token warna. Tampilan diganti per alur begitu frame Figma berstatus `Siap dev`.
2. **Yang wajib ada sebelum BINUS Festival adalah transaksi sungguhan**, bukan fitur lengkap. Target minimumnya adalah milestone **MVP Transaksi** di bawah.
3. **Pekerjaan non-kode punya tenggatnya sendiri.** Domain, SMTP, merchant QRIS, dan keputusan bisnis sering memakan waktu tunggu. Kerjakan paralel dengan development, bukan setelahnya.

## Tiga jalur paralel

| Jalur | Penanggung jawab | Isi |
|---|---|---|
| Development | Faiqi (CTO) | Fase 1 sampai 6, integrasi desain, deploy |
| Desain | Tim Figma | Prototype per alur sesuai arahan desain |
| Operasional dan bisnis | Clarencia, Najwa, Shana, Evan | Keputusan terbuka, domain, merchant QRIS, uji coba, promosi, Festival, laporan |

---

## Fase 0 — Fondasi dokumen dan kerangka aplikasi

Status: **selesai**

- [x] PRD, catatan keputusan, dan README
- [x] Kerangka Next.js, token warna, navigasi bawah, PWA (tahap 1 PRD)
- [x] Uji deploy ke Netlify: build Next.js berhasil dan service worker berjalan (D-12)
- [ ] Alur branch, Pull Request, dan CI aktif, termasuk branch protection untuk `main` (D-15, [`workflow.md`](workflow.md))
- [ ] Uji tahap 1 di HP lewat HTTPS: dapat dipasang ke layar utama di Android dan iPhone, terbuka tanpa bilah alamat, halaman offline muncul saat mode pesawat. Android (Chrome) sudah dapat dipasang; iPhone belum diuji.

## Fase 1 — Auth dan profil (tahap 2 PRD)

**Prasyarat non-kode**

- [x] Project Supabase dibuat. Kredensial di `.env.local` dan di environment variables Netlify.
- [x] Site URL dan Redirect URLs di Supabase Auth diisi dengan URL Netlify dan `http://localhost:3000`
- [ ] Uji alur OTP ke akun `@binus.ac.id` dan `@binus.edu` milik anggota tim memakai SMTP bawaan Supabase, atau Gmail dengan App Password bila batas kirimnya terlalu kecil (D-14). Tes ini membuktikan alurnya, belum membuktikan keterkiriman dari domain sendiri. `@binus.ac.id` lolos 24 Sep 2026 (Gmail SMTP, masuk Focused Inbox kurang dari 1 menit); `@binus.edu` belum diuji.

**Development**

- [x] Strategi cache service worker diubah: halaman yang memuat data pribadi tidak disimpan untuk offline.
- [ ] Login dan pendaftaran dengan OTP, hanya dua domain kampus (F1). `@binus.ac.id` lolos 24 Sep 2026; `@binus.edu` belum diuji.
- [x] Profil mahasiswa dan dosen/staf (F2)
- [x] Row Level Security untuk tabel profil

**Selesai bila:** anggota tim dapat mendaftar dengan email kampus, email domain lain ditolak di server, dan data profil satu akun tidak dapat dibaca akun lain.

## Fase 2 — Kuota inti dan listing (tahap 3 PRD)

**Development**

- [ ] Buku besar kuota dan penyesuaian manual oleh admin, ditegakkan di basis data (F3.8, F3.9, F9.5, D-10)
- [ ] Pasang listing jual dan donasi tanpa AI (F4)
- [ ] Katalog, pencarian, dan filter (F5)
- [ ] Halaman detail dengan tombol WhatsApp dan pratinjau tautan (F6)

**Selesai bila:** admin dapat memberi kuota secara manual, pengguna dapat menerbitkan listing yang terlihat oleh akun lain, dan tautan listing yang dibagikan di WhatsApp menampilkan foto dan harga.

## Fase 3 — Pembelian kuota lewat QRIS (tahap 4 PRD)

**Prasyarat non-kode**

- [ ] Merchant QRIS atas nama usaha BeeKas terdaftar
- [ ] Pilihan paket kuota dan harganya diputuskan
- [ ] Kuota gratis untuk akun baru diputuskan
- [ ] Target waktu konfirmasi oleh admin ditetapkan, dan admin yang bertugas ditunjuk

**Development**

- [ ] Alur beli paket, tampilan QRIS, unggah bukti bayar (F3)
- [ ] Konfirmasi dan penolakan pembelian di panel admin (F9.1 sampai F9.4)

**Selesai bila:** pembelian sungguhan senilai satu paket dapat dibayar, dikonfirmasi admin, dan kuotanya bertambah dengan tepat.

## Fase 4 — Booking (tahap 5 PRD)

**Keputusan yang dibutuhkan sebelum mulai**

- [ ] Batas jumlah dan lama perpanjangan booking
- [ ] Kuota dikembalikan atau tidak bila listing dihapus sebelum terjual

**Development**

- [ ] Booking, perpanjangan, pembatalan, dan kedaluwarsa otomatis (F7)
- [ ] Pengelolaan listing milik sendiri dan penandaan terjual (F8)

**Selesai bila:** booking yang lewat batas waktu tanpa perpanjangan membuat listing kembali tersedia, dan listing dapat ditandai terjual dengan harga akhir.

## Milestone: MVP Transaksi

Fase 1 sampai 4 selesai dan ter-deploy. Pada titik ini BeeKas sudah dapat dipakai untuk transaksi sungguhan, meskipun tanpa AI dan tanpa desain Figma final. **Ini target minimum untuk BINUS Festival.**

## Fase 5 — Draf listing dengan AI (tahap 6 PRD)

**Keputusan yang dibutuhkan sebelum mulai**

- [ ] Bahasa draf listing yang dihasilkan AI

**Development**

- [ ] Endpoint draf listing dengan validasi keluaran dan batas laju (F4.3 sampai F4.7, bagian 8 PRD)

**Selesai bila:** foto barang menghasilkan draf yang dapat dikoreksi, dan kegagalan AI tidak menghentikan pemasangan listing.

## Fase 6 — Ringkasan admin dan ekspor (tahap 7 PRD)

- [ ] Ringkasan angka dan ekspor CSV tanpa kontak (F9.6, F9.7)

**Selesai bila:** CSV listing dan pembelian kuota dapat dibuka di spreadsheet dan dipakai untuk laporan.

## Integrasi desain Figma

Berjalan paralel sejak Fase 2, per alur, begitu frame berstatus `Siap dev`. Logika yang sudah ada tidak diubah, hanya lapisan tampilan.

| Alur | Dapat diintegrasikan setelah |
|---|---|
| Katalog dan detail | Fase 2 |
| Masuk dan profil | Fase 1 |
| Pasang listing | Fase 2 (tanpa AI), dilengkapi setelah Fase 5 |
| Kuota | Fase 3 |
| Booking dan listing saya | Fase 4 |
| Admin | Fase 3 |

## Fase 7 — Uji coba tertutup

**Prasyarat non-kode, dikerjakan di awal fase (D-14)**

- [ ] Domain untuk BeeKas dibeli atas nama akun tim
- [ ] Project Supabase produksi terpisah dari `beekas-dev`, dengan migrasi yang sama; Deploy Preview tetap memakai `beekas-dev` (D-15)
- [ ] Aplikasi dipindah ke domain BeeKas sebelum pengguna di luar tim memasang PWA
- [ ] SMTP kustom (misalnya Resend) dipasang dengan domain pengirim terverifikasi (SPF, DKIM, DMARC)
- [ ] Uji ulang kirim OTP ke `@binus.ac.id` dan `@binus.edu` dari domain sendiri. Email masuk ke inbox, bukan karantina.

**Uji coba**

- [ ] Uji coba dengan tim dan 10 sampai 20 pengguna di luar tim
- [ ] Minimal satu transaksi sungguhan dari awal sampai akhir: beli kuota, pasang listing, booking, COD, tandai terjual
- [ ] Perbaikan hasil uji coba

## Fase 8 — Siap produksi

**Pekerjaan**

- [ ] Pantau pemakaian Netlify dan siapkan upgrade bila mendekati batas menjelang Festival (D-12)
- [ ] Naikkan batas pendaftaran auth sebelum promosi Festival
- [ ] Backup basis data terjadwal
- [ ] Aplikasi di domain BeeKas dengan HTTPS (dipindah di Fase 7)

## Fase 9 — BINUS Festival dan laporan

- [ ] Materi promosi dan panduan pasang aplikasi untuk pengunjung
- [ ] Dokumentasi foto dan video selama Festival
- [ ] Ekspor data transaksi setelah Festival
- [ ] Refleksi validasi pasar (pivot, lanjut, atau berhenti) berdasarkan data

---

## Kalau waktu tidak cukup

Urutan yang dipotong lebih dulu, tanpa menggagalkan MVP Transaksi:

1. Draf listing dengan AI (Fase 5). Pengisian manual tetap berjalan.
2. Ringkasan admin di aplikasi (Fase 6). Data dapat diekspor langsung dari dashboard Supabase.
3. Integrasi desain Figma untuk alur admin.
4. Penanda listing yang perlu diperbarui setelah 30 hari (F8.5).

Yang tidak boleh dipotong: verifikasi email kampus, aturan kuota di basis data, Row Level Security, dan kredensial yang hanya ada di server.
