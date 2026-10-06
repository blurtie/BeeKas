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
- Admin memeriksa nomor HP saat verifikasi identitas; nomor tampil di detail berkas. Bila pemilik asli tidak bisa mendaftar karena nomornya sudah dipakai, ia menghubungi Bantuan dan admin bisa melepas nomor itu dari akun lain.

**Alasan:** Mengikuti frame Masuk. OTP SMS membutuhkan layanan berbayar.

**Risiko:** Karena nomor HP unik tetapi tidak diverifikasi, orang lain bisa mendaftar dengan nomor milik seseorang dan memblokir pemilik aslinya. Mitigasinya pemeriksaan admin dan pelepasan nomor lewat Bantuan, yang bergantung pada tindakan manual.

---

## D-05 — Tidak ada login SSO Microsoft BINUS

**Status:** Disetujui CTO, 5 Oktober 2026

**Keputusan:** BeeKas tidak memakai login SSO Microsoft BINUS. Tombol "Masuk dengan SSO" dan pemisah "atau" di frame Masuk 384:9135 tidak dibangun. Masuk hanya dengan email atau nomor HP + kata sandi (D-04).

**Alasan:** Keputusan CTO, 5 Oktober 2026. Alur email BINUS + OTP sudah membuktikan kepemilikan email tanpa izin IT BINUS.

---

## D-06 — Status akun dan aksesnya

**Status:** Default, menunggu tim (akses selama menunggu mengubah notulen)

Dikonfirmasi tim lewat kuesioner, 7 Oktober 2026

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

Dikonfirmasi tim lewat kuesioner, 7 Oktober 2026

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

---

## D-13 — Dependency untuk login

**Status:** Disetujui CTO, 5 Oktober 2026

**Keputusan:** Empat dependency ditambahkan:
- `supabase_flutter` untuk auth, database, dan storage.
- `shared_preferences` untuk bahasa dan status onboarding.
- `image_picker` hanya dengan `ImageSource.camera`: kamera belakang untuk kartu, kamera depan untuk selfie.
- `url_launcher` untuk membuka aplikasi email (mailto) dari tombol Bantuan (D-14). Ditambahkan 5 Oktober 2026.

---

## D-14 — Kartu digital sementara dihapus; Bantuan lewat email tim

**Status:** Bantuan disetujui CTO, 5 Oktober 2026; penghapusan kartu digital menunggu konfirmasi tim

Dikonfirmasi tim lewat kuesioner, 7 Oktober 2026

**Keputusan:**
- Layar "Pendaftaran berhasil + kartu digital" dari notulen tidak dibangun. Konfirmasi pendaftaran digabung ke layar "Verifikasi Sedang Diproses".
- Tombol "Bantuan" membuka aplikasi email (mailto) dengan subjek "Bantuan BeeKas" dan isi awal berisi nama, email akun, dan status akun. Bila tidak ada aplikasi email, alamat email ditampilkan dengan tombol salin.
- Alamat email Bantuan disimpan sebagai konstanta konfigurasi, sementara `beekas2026@gmail.com`.

**Alasan:** Kartu digital belum punya fungsi. Email tim bisa diakses bersama oleh beberapa anggota tim tanpa membagikan nomor WhatsApp pribadi.

---

## D-15 — Tipe akun dari domain email, tanpa jalur alumni

**Status:** Disetujui (dibawa dari versi web: PRD F1.3, F2.2, dan D-03 lama); dukungan alumni menjadi pertanyaan terbuka untuk tim

Dikonfirmasi tim lewat kuesioner, 7 Oktober 2026

**Keputusan:**
- Tipe akun diturunkan dari domain email, tidak dipilih bebas. `@binus.ac.id` = mahasiswa, tanpa pilihan. `@binus.edu` = dosen atau staf, pengguna wajib memilih salah satu.
- Tipe akun menentukan kartu yang diminta: mahasiswa = Flazz, dosen = ID card dosen, staf = ID card staf.
- Tidak ada jalur verifikasi terpisah untuk alumni. Alumni yang email `@binus.ac.id`-nya masih aktif mendaftar sebagai mahasiswa dan tetap diminta Flazz.

**Alasan:** Domain email sudah membedakan mahasiswa dari dosen/staf, sehingga pilihan bebas hanya membuka ruang salah isi. Keputusan versi web dibawa ulang.

**Konsekuensi:** Pilihan Dosen/Staf untuk `@binus.edu` menambah satu isian yang belum ada di frame Daftar 405:9246.

---

## D-16 — Perubahan profil oleh member hanya lewat fungsi backend

**Status:** Disetujui CTO, 6 Oktober 2026

**Implementasi:** PR #44.

**Keputusan:** Member tidak punya akses UPDATE langsung ke tabel profil. Perubahan oleh member lewat fungsi backend yang hanya bekerja pada profil miliknya sendiri:
1. `submit_for_review()`: `incomplete`/`rejected` → `pending`, hanya bila foto kartu dan selfie sudah ada.
2. `set_phone(nomor)`: hanya bila nomor HP sedang kosong (dilepas admin, L14–L15); tetap unik dan formatnya sama dengan saat daftar.
3. `update_identity(nama, kampus)`: hanya selama `incomplete` atau `rejected`; terkunci saat `pending`/`approved`.

Email, tipe akun, dan peran tidak bisa diubah member. `approved` dan `rejected` hanya oleh admin.

---

## D-17 — Profil dibentuk oleh backend saat akun dibuat

**Status:** Disetujui CTO, 6 Oktober 2026

**Implementasi:** PR #44.

**Keputusan:** Profil dibuat trigger database dari data pendaftaran (nama, email, tipe akun, kampus). Nomor HP tidak ikut di data pendaftaran; nomor disimpan lewat `set_phone` setelah OTP terverifikasi, karena error dari trigger tidak sampai ke aplikasi. Peran selalu member dan status selalu `incomplete`, apa pun isi data yang dikirim. Tipe akun ditentukan dari domain email (D-15); data hanya boleh memilih Dosen/Staf untuk `@binus.edu`.

---

## D-18 — Admin lokal dibuat lewat seed khusus lokal

**Status:** Disetujui CTO, 6 Oktober 2026

**Implementasi:** PR #44.

**Keputusan:** `supabase/seed.sql` membuat `admin@beekas.test` dengan kata sandi tetap, hanya untuk Supabase lokal. Admin cloud dibuat terpisah dengan kata sandi yang tidak ada di repo.

---

## D-19 — Foto verifikasi per percobaan

**Status:** Disetujui CTO, 6 Oktober 2026

**Implementasi:** PR #44.

**Keputusan:** Setiap pengiriman foto memakai folder baru `<user id>/<attempt>/`. Member hanya bisa mengunggah, tidak bisa membaca, mengganti, atau menghapus fotonya. Kirim ulang setelah ditolak hanya diterima bila kartu dan selfie diunggah setelah penolakan terakhir. Bucket menerima JPEG/PNG sampai 5 MB.

**Alasan:** Storage butuh izin baca untuk menimpa file, sedangkan D-07 hanya mengizinkan admin membaca.

---

## D-20 — Bukti persetujuan data disimpan

**Status:** Disetujui CTO, 7 Oktober 2026

**Implementasi:** PR untuk #28.

**Keputusan:** Persetujuan di L7 (D-07) disimpan di profil sebagai waktu (`consent_at`) dan versi teks persetujuan (`consent_version`). Versi adalah konstanta di aplikasi yang diganti setiap kali teks persetujuan di `lib/config/copy.dart` berubah. Member hanya bisa mengisinya lewat `record_consent` saat status `incomplete` atau `rejected`, tidak lewat UPDATE langsung. Storage menolak unggahan foto verifikasi sebelum ada persetujuan. Penarikan persetujuan belum diatur.

**Alasan:** UU PDP meminta bukti persetujuan untuk data biometrik; centang di UI saja tidak meninggalkan jejak.

---

## D-21 — Penanggung jawab data, pemeriksa verifikasi, dan penulis Kebijakan Privasi

**Status:** Disetujui tim lewat kuesioner, 7 Oktober 2026

**Keputusan:**
- **Penanggung jawab data pribadi pengguna:** CTO, sebagai kontak yang disebut di Kebijakan Privasi.
- **Pemeriksa verifikasi:** kelima anggota tim, masing-masing dengan akun admin sendiri. Tidak ada akun admin bersama.
- **Janji 1×24 jam** (D-02) berlaku juga di akhir pekan dan hari libur.
- **Kebijakan Privasi dan Syarat & Ketentuan:** draf ditulis CTO, ditinjau tim. Sampai selesai, aplikasi memakai teks draf yang ditandai jelas (D-07).

**Alasan:** UU PDP meminta pihak yang bisa dihubungi pengguna soal data pribadinya. Akun admin per orang membuat catatan "disetujui/ditolak oleh siapa" akurat.

**Konsekuensi:** Perlu lima akun admin: lokal lewat seed (D-18, saat ini satu), cloud dibuat terpisah.
