# Keputusan BeeKas

Keputusan resmi BeeKas versi Flutter. Format D-xx, dimulai dari D-01. Keputusan versi web (tag `web-nextjs-final`) tidak berlaku kecuali dibawa ulang di sini.

Status: **Disetujui CTO** = cukup CTO. **Default, menunggu tim** = berlaku sampai tim memutuskan lewat kuesioner.

---

## D-01 — Yang boleh mendaftar: pemilik email BINUS aktif

**Status:** Disetujui CTO, 5 Oktober 2026

**Keputusan:** Pendaftaran hanya menerima `@binus.ac.id` dan `@binus.edu`. Tidak ada jalur alumni terpisah (D-15). Pengunjung tanpa email BINUS hanya bisa menjadi tamu (D-06).

**Alasan:** Akun yang terikat pada identitas kampus adalah dasar kepercayaan BeeKas. Aturan ini sama dengan D-03 versi web.

**Konsekuensi:** Domain email divalidasi di `lib/domain/` dan ditegakkan juga di backend.

---

## D-02 — Verifikasi identitas penuh: foto kartu dan selfie, diperiksa manual oleh admin

**Status:** Disetujui CTO, 5 Oktober 2026

**Keputusan:** Setelah email terverifikasi, pendaftar memotret kartu identitas dan mengambil selfie. Admin membandingkan wajah di selfie dengan foto di kartu, lalu memeriksa nama dan data di kartu terhadap data pendaftaran. Tidak ada pencocokan wajah otomatis. Foto hanya bisa diambil dengan kamera; galeri tidak tersedia.

**Alasan:** Email BINUS tidak mencegah akun dipinjamkan atau dipakai orang lain. Pemeriksaan manual tidak membutuhkan biaya dan tidak melibatkan pihak ketiga yang memproses data biometrik. Hanya kamera supaya foto lama atau milik orang lain tidak bisa diunggah.

**Alternatif yang ditolak:** email + OTP saja; foto kartu tanpa selfie; layanan KYC berbayar.

**Konsekuensi:** Ada SLA pemeriksaan 1×24 jam dan layar admin (D-09). Data biometrik diatur oleh D-07.

---

## D-03 — Email diverifikasi dengan OTP sebelum akun dibuat, lalu kata sandi dibuat

**Status:** Disetujui CTO, 5 Oktober 2026

**Keputusan:** Urutan pendaftarannya:
1. Isi data diri.
2. Masukkan kode OTP 6 digit yang dikirim ke email BINUS.
3. Buat kata sandi.

Akun baru terbentuk setelah OTP benar. Aturan kata sandi: minimal 8 karakter, sedikitnya satu huruf dan satu angka, dengan konfirmasi.

**Alasan:** Kepemilikan email terbukti sejak awal, sehingga orang tidak bisa mendaftar memakai email orang lain dan admin tidak memeriksa pendaftaran palsu. Kode lebih mudah dipakai di lingkungan lokal daripada magic link karena tidak butuh deep link.

---

## D-04 — Masuk dengan email atau nomor HP + kata sandi

**Status:** Disetujui CTO, 5 Oktober 2026

**Keputusan:**
- Layar Masuk punya satu kolom "email atau nomor HP" dan satu kolom kata sandi.
- Nomor HP wajib unik, tetapi tidak diverifikasi.
- Lupa kata sandi hanya lewat email: OTP, lalu sandi baru.
- "Ingat saya" (default tercentang) membuat sesi bertahan setelah aplikasi ditutup. Bila tidak dicentang, pengguna keluar saat aplikasi ditutup.
- Penguncian setelah salah berulang kali diserahkan ke rate limit Supabase.

**Alasan:** Mengikuti frame Masuk. OTP SMS membutuhkan layanan berbayar.

---

## D-05 — SSO Microsoft BINUS ditunda

**Status:** Disetujui CTO, 5 Oktober 2026

**Keputusan:** Tombol "Masuk dengan SSO" tetap tampil sesuai desain. Di prototype tombol ini menampilkan pesan bahwa SSO segera hadir. SSO dibangun bila IT BINUS memberi izin. Pengguna SSO nantinya tidak perlu OTP email, karena SSO sudah membuktikan kepemilikan email.

**Alasan:** Izin IT BINUS belum ada, dan alur email tidak bergantung padanya.

---

## D-06 — Status akun dan aksesnya

**Status:** Default, menunggu tim (akses selama menunggu mengubah notulen)

**Keputusan:**

| Status | Arti | Akses |
|---|---|---|
| tamu (tanpa akun) | belum mendaftar | lihat katalog |
| `incomplete` | email terverifikasi, berkas belum dikirim | lihat katalog; saat masuk diarahkan melanjutkan verifikasi |
| `pending` | berkas menunggu admin | lihat katalog |
| `rejected` | berkas ditolak | lihat katalog; bisa kirim ulang berkas |
| `approved` | disetujui | semua fitur |

"Lihat katalog" berarti hanya melihat: tidak bisa menghubungi penjual dan tidak bisa memasang barang.

**Alasan:** Pengunjung BINUS Festival bisa langsung melihat isi aplikasi. Kepercayaan baru dibutuhkan saat kontak atau transaksi. Sejalan dengan D-17 versi web.

**Konsekuensi:** Aturan akses ditulis di `lib/domain/` dengan tes dan ditegakkan juga di RLS.

---

## D-07 — Perlakuan data kartu dan selfie (UU PDP)

**Status:** Disetujui CTO; masa simpan menunggu tim

**Keputusan:**
- **Persetujuan:** layar persetujuan eksplisit sebelum foto kartu. Isinya data apa yang diambil, tujuannya, siapa yang melihat, dan masa simpannya. Tanpa centang, pendaftaran tidak bisa lanjut.
- **Akses:** hanya akun admin.
- **Penyimpanan:** bucket storage privat di Supabase, tidak dapat diakses publik.
- **Penghapusan:** foto kartu dan selfie dihapus paling lambat 30 hari setelah disetujui atau ditolak. Yang disimpan hanya status, admin yang memeriksa, waktu, dan alasan penolakan.
- **Kebijakan Privasi dan Syarat & Ketentuan:** layar teks statis. Isinya ditulis tim. Prototype memakai teks sementara yang ditandai jelas.

**Alasan:** Foto wajah adalah data biometrik, termasuk data pribadi spesifik menurut UU PDP.

---

## D-08 — Penolakan dan pengiriman ulang

**Status:** Disetujui CTO, 5 Oktober 2026

**Keputusan:** Admin wajib menulis alasan saat menolak. Alasan dikirim lewat email dan ditampilkan di aplikasi. Pengguna `rejected` bisa mengirim ulang foto kartu dan selfie tanpa mengisi ulang data diri, lalu statusnya kembali `pending`. Belum ada batas jumlah pengiriman ulang dan belum ada fitur blokir.

---

## D-09 — Layar admin di aplikasi yang sama

**Status:** Disetujui CTO, 5 Oktober 2026

**Keputusan:** Layar admin hanya muncul untuk akun berperan admin. Isinya daftar pendaftar `pending`, foto kartu, selfie, data diri, serta tombol setujui atau tolak dengan alasan. Akun admin dibuat lewat seed, tidak lewat pendaftaran.

**Alasan:** Satu codebase, dan alur bisa diuji end-to-end di lingkungan lokal.

---

## D-10 — Lingkungan lokal: Supabase lokal di laptop, beberapa HP di jaringan yang sama

**Status:** Disetujui CTO, 5 Oktober 2026

**Keputusan:** Selama pengembangan, backend adalah Supabase lokal (Docker) di laptop. HP atau emulator terhubung lewat Wi-Fi atau hotspot yang sama. Email OTP dan email persetujuan ditangkap mail server lokal Supabase, tidak keluar ke internet. Aturan bisnis tetap ditulis di `lib/domain/` (Dart murni) dan data diakses lewat repository interface.

**Alasan:** Pendaftar dan admin bisa diuji di dua perangkat secara bersamaan. Pindah ke project Supabase cloud cukup dengan mengganti URL dan anon key; migrasi SQL dan RLS ikut terbawa.

**Alternatif yang ditolak:** satu perangkat dengan database di HP, karena seluruh data layer harus ditulis ulang saat dipublikasikan.

**Konsekuensi:** Butuh Docker di laptop. Wi-Fi kampus mungkin memblokir koneksi antarperangkat; pakai hotspot.

---

## D-11 — Dua bahasa, Inggris sebagai bahasa utama

**Status:** Disetujui CTO, 5 Oktober 2026

**Keputusan:** Antarmuka tersedia dalam bahasa Inggris (default) dan Indonesia. Tombol EN | ID ada di splash/onboarding, Masuk, dan nanti di Profil. Pilihan bahasa disimpan di perangkat. Semua teks ada di `lib/config/copy.dart` dalam dua map, tanpa library lokalisasi.

**Alasan:** Dua map cukup untuk teks statis. `intl` ditambahkan bila nanti butuh format tanggal atau angka.

---

## D-12 — Daftar kampus dibawa dari versi web (D-16 lama)

**Status:** Disetujui tim, 24 September 2026 (dibawa dari D-16 versi web)

**Keputusan:** Kode kampus: `kemanggisan`, `senayan`, `alam_sutera`, `base`, `bekasi`, `bandung`, `malang`, `semarang`, `online`. Kampus yang berdekatan digabung per area (Kemanggisan: Anggrek, Syahdan, Kijang; Senayan: JWC, fX). BINUS Online tidak punya kampus fisik. Label tampilan mengikuti format desain, misalnya "Kampus Binus Alam Sutera".

**Konsekuensi:** Bila daftar jurusan dibutuhkan, diambil dari tag yang sama. Empat poin terbukanya masuk kuesioner.

---

## D-13 — Dependency untuk login

**Status:** Disetujui CTO, 5 Oktober 2026

**Keputusan:** Tiga dependency ditambahkan:
- `supabase_flutter` untuk auth, database, dan storage.
- `shared_preferences` untuk bahasa dan status onboarding.
- `image_picker` hanya dengan `ImageSource.camera`: kamera belakang untuk kartu, kamera depan untuk selfie.

---

## D-14 — Kartu digital sementara dihapus; Bantuan lewat WhatsApp

**Status:** Disetujui CTO, 5 Oktober 2026

**Keputusan:** Layar "Pendaftaran berhasil + kartu digital" dari notulen tidak dibangun; konfirmasinya digabung ke layar "Verifikasi Sedang Diproses". Tombol "Bantuan" membuka WhatsApp tim BeeKas dengan pesan awal berisi nama dan email.

**Alasan:** Kartu digital belum punya fungsi. WhatsApp sudah menjadi kanal komunikasi (D-04 versi web).

---

## D-15 — Tipe akun dari domain email, tanpa jalur alumni

**Status:** Disetujui (dibawa dari versi web: PRD F1.3, F2.2, dan D-03 lama); dukungan alumni menjadi pertanyaan terbuka untuk tim

**Keputusan:**
- Tipe akun diturunkan dari domain email, tidak dipilih bebas. `@binus.ac.id` = mahasiswa, tanpa pilihan. `@binus.edu` = dosen atau staf, pengguna wajib memilih salah satu.
- Tipe akun menentukan kartu yang diminta: mahasiswa = Flazz, dosen = ID card dosen, staf = ID card staf.
- Tidak ada jalur verifikasi terpisah untuk alumni. Alumni yang email `@binus.ac.id`-nya masih aktif mendaftar sebagai mahasiswa dan tetap diminta Flazz.

**Alasan:** Domain email sudah membedakan mahasiswa dari dosen/staf, sehingga pilihan bebas hanya membuka ruang salah isi. Keputusan versi web dibawa ulang.

**Konsekuensi:** Pilihan Dosen/Staf untuk `@binus.edu` menambah satu isian yang belum ada di frame Daftar 405:9246.
