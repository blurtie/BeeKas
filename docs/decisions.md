# Catatan Keputusan

Setiap keputusan yang memengaruhi produk atau arsitektur dicatat di sini beserta alasannya. Keputusan baru ditambahkan di bawah, bukan menimpa yang lama. Kalau sebuah keputusan diganti, tandai yang lama sebagai **Diganti oleh D-xx**.

Asisten koding tidak boleh menambah atau mengubah isi dokumen ini tanpa persetujuan tim.

---

## D-01 — Stack aplikasi

**Status:** Disetujui, 23 September 2026

**Keputusan**

| Bagian | Pilihan |
|---|---|
| Framework | Next.js (App Router) + TypeScript + Tailwind CSS |
| Basis data | Supabase Postgres, akses data dijaga Row Level Security |
| Autentikasi | Supabase Auth dengan kode OTP ke email |
| Penyimpanan gambar | Supabase Storage |
| Email OTP | Penyedia SMTP kustom, bukan SMTP bawaan Supabase |
| Model AI | Claude API, dipanggil dari Route Handler di server |
| Validasi data | Zod, untuk masukan pengguna dan keluaran AI |

**Alasan**

- Aplikasi harus dapat dibuka dari tautan tanpa pemasangan, dan tautan listing yang dibagikan di WhatsApp harus menampilkan pratinjau foto serta harga barang tersebut. Aplikasi web dengan render di server memenuhi keduanya. SPA murni dan Flutter Web tidak.
- Next.js menyediakan sisi server dalam proyek yang sama, sehingga kredensial AI dan basis data tidak pernah sampai ke peramban.
- Supabase menyediakan autentikasi, basis data, dan penyimpanan berkas sekaligus, sehingga waktu semester tidak habis untuk membangun infrastruktur.
- CTO sudah pernah mempelajari React, dan Next.js dibangun di atas React.

**Konsekuensi**

- SMTP bawaan Supabase punya batas kirim yang rendah dan, untuk proyek Free baru, template email tidak dapat diubah. Waktu pemasangan SMTP kustom diatur di D-14.
- Supabase Free dapat menjeda proyek yang tidak aktif selama 7 hari, dan backup tidak dapat diunduh. Perlu backup terjadwal atau upgrade setelah ada transaksi.
- Batas default pendaftaran dengan SMTP kustom adalah 30 pengguna baru per jam. Batas ini dinaikkan sebelum promosi di BINUS Festival.

## D-02 — Aplikasi dibangun sebagai PWA

**Status:** Disetujui, 23 September 2026

**Keputusan:** Aplikasi web dijadikan Progressive Web App sejak tahap pertama pengerjaan: dapat dipasang ke layar utama, tampil tanpa bilah alamat, dan menampilkan kerangka aplikasi saat sinyal buruk.

**Alasan:** Tim ingin BeeKas terasa seperti aplikasi di ponsel tanpa kehilangan kemampuan dibuka dari tautan. Aplikasi native ditunda sampai ada bukti pengguna mau memasangnya.

**Konsekuensi**

- Di iPhone, pemasangan dilakukan manual lewat menu Share, sehingga perlu layar kecil yang memandu pengguna iPhone.
- Notifikasi push tidak termasuk rilis pertama.
- Kalau nanti dibutuhkan kehadiran di Play Store, aplikasi web dapat dibungkus tanpa ditulis ulang. Kemungkinan ini perlu diverifikasi saat dibutuhkan.

## D-03 — Domain email yang diterima

**Status:** Disetujui

**Keputusan:** Pendaftaran hanya menerima email `@binus.ac.id` (mahasiswa) dan `@binus.edu` (dosen dan staf). Domain lain ditolak di server.

**Alasan:** Identitas pengguna yang terikat pada akun kampus adalah dasar kepercayaan BeeKas.

**Konsekuensi:** Tidak ada jalur verifikasi terpisah untuk alumni. Alumni yang email kampusnya sudah tidak aktif tidak dapat mendaftar. Keputusan ini disetujui tim pada September 2026.

**Perlu dicek:** pengiriman kode OTP ke kedua domain belum diuji. Filter email kampus dapat mengarantina email dari domain baru. Uji ke beberapa akun anggota tim sebelum membangun fitur di atas autentikasi.

## D-04 — Kanal komunikasi pembeli dan penjual lewat WhatsApp

**Status:** Disetujui, 23 September 2026

**Keputusan:** Halaman detail listing memiliki tombol yang membuka WhatsApp penjual dengan pesan awal yang sudah terisi. Tidak ada fitur chat di dalam aplikasi.

**Alasan:** Chat internal membutuhkan pesan realtime, penyimpanan percakapan, dan moderasi, dengan usaha pengembangan beberapa minggu. WhatsApp sudah dipakai semua calon pengguna.

**Konsekuensi**

- Nomor WhatsApp penjual hanya terlihat oleh pengguna terverifikasi, dan hanya di halaman detail listing.
- Percakapan dan kesepakatan terjadi di luar aplikasi, sehingga BeeKas tidak memiliki catatannya. Status booking dan harga akhir dicatat oleh penjual di aplikasi.

## D-05 — Model pendapatan: fee listing Rp1.000

**Status:** Disetujui

**Keputusan:** Penjual membayar Rp1.000 untuk setiap listing yang diterbitkan, termasuk listing donasi. Model ini menggantikan skema potongan persentase dari harga jual.

**Alasan:** Potongan persentase terlalu besar untuk barang preloved yang umumnya murah. Fee kecil yang tetap tidak banyak menghambat penjual. Pada listing donasi, fee berfungsi menyaring listing spam dan asal-asalan, bukan untuk mencari untung dari barang yang diberikan gratis.

## D-06 — Pembayaran fee lewat kuota listing, QRIS statis, dan konfirmasi manual

**Status:** Disetujui, 23 September 2026

**Keputusan**

1. Penjual membeli **paket kuota listing**. Satu kuota setara satu listing seharga Rp1.000.
2. Pembayaran dilakukan ke **QRIS statis milik tim**, yang gambarnya ditampilkan di aplikasi beserta nominal paket.
3. Penjual mengunggah bukti bayar. Pembelian berstatus menunggu konfirmasi.
4. Admin mencocokkan bukti dengan mutasi yang benar-benar masuk di aplikasi merchant QRIS, lalu mengonfirmasi atau menolak.
5. Setelah dikonfirmasi, kuota bertambah. Setiap listing yang terbit mengurangi satu kuota.

**Aturan kuota**

- Istilah di antarmuka dan kode: lihat D-09 ("listing credits" / `credits`). Tidak pernah "saldo", "balance", atau "wallet".
- Kuota tidak dapat diuangkan kembali, tidak dapat dipindahkan ke akun lain, dan hanya dapat dipakai untuk menerbitkan listing.

**Alasan**

- Payment gateway otomatis umumnya mensyaratkan badan usaha. Xendit, misalnya, tidak menerima akun perorangan.
- Mulai 1 Oktober 2026, MDR QRIS 0% berlaku untuk transaksi sampai Rp100.000 di semua merchant, dan sampai Rp500.000 untuk usaha mikro, sehingga biaya pembayaran fee praktis nol. Perlu dicek ulang di siaran pers resmi Bank Indonesia.
- Paket menghindari pembayaran berulang untuk nominal Rp1.000.
- Kuota yang hanya dapat dipakai untuk jasa listing menjauhkan BeeKas dari karakteristik uang elektronik. Batas hukumnya belum diverifikasi.

**Konsekuensi**

- Admin harus mengonfirmasi pembelian dalam waktu yang wajar. Target waktunya perlu ditetapkan.
- Screenshot bukti bayar dapat dipalsukan, jadi konfirmasi wajib berdasarkan mutasi di aplikasi merchant.
- QRIS sebaiknya terdaftar atas nama usaha BeeKas, bukan rekening pribadi anggota, agar pencatatan untuk laporan keuangan terpisah.
- Butuh tabel pembelian kuota dan buku besar kuota. Isinya sekaligus menjadi data pendapatan untuk laporan.

## D-07 — Booking default 1x24 jam, dapat diperpanjang penjual

**Status:** Disetujui

**Keputusan**

- Pembeli yang melakukan booking wajib menyelesaikan COD atau pembayaran kepada penjual paling lambat 1x24 jam sejak booking.
- Penjual dapat memperpanjang batas waktu tersebut.
- Berlaku untuk listing jual maupun donasi.

**Implementasi:** batas waktu disimpan sebagai kolom `booked_until`. Listing yang `booked_until`-nya sudah lewat diperlakukan sebagai tersedia saat data dibaca, tanpa job terjadwal. Pendekatan ini tidak dapat gagal karena job yang tidak berjalan.

## D-08 — AI hanya dipanggil dari server

**Status:** Disetujui

**Keputusan:** Pemanggilan Claude API hanya terjadi di Route Handler. Kunci API hanya ada di environment server. Keluaran AI divalidasi bentuknya sebelum dikirim ke klien. Kegagalan AI tidak menghentikan pemasangan listing.

## D-09 — Antarmuka dan kode dalam bahasa Inggris

**Status:** Disetujui, 23 September 2026. Mengganti ketentuan "seluruh teks antarmuka dalam bahasa Indonesia" di PRD v0.2.

**Keputusan**

- Teks yang dilihat pengguna (label, tombol, pesan) dalam bahasa Inggris.
- Kode dalam bahasa Inggris: nama berkas, komponen, variabel, route (misalnya `/catalog`, `/my-listings`), dan nilai enum.
- Istilah untuk kuota di antarmuka adalah "listing credits". Tidak pernah "balance" atau "wallet".

**Konsekuensi**

- Semua teks antarmuka disimpan terpusat di satu berkas, tidak ditulis langsung di komponen. Tanpa library i18n. Kalau nanti bahasa diganti atau ditambah, cukup berkas itu yang diubah.
- Mata uang tetap rupiah dengan format Indonesia.
- Isi listing (judul, deskripsi) ditulis pengguna dan tidak dipaksa berbahasa Inggris.
- Arahan desain untuk tim Figma perlu diperbarui agar teks di prototype juga berbahasa Inggris.
- Dua hal turunan masih terbuka: bahasa pesan awal WhatsApp dan bahasa draf listing dari AI.

## D-10 — Logika inti tidak terikat pada Next.js

**Status:** Disetujui, 23 September 2026

**Keputusan**

1. Aturan bisnis yang menyangkut data dijalankan di **fungsi Postgres (RPC Supabase) atau Route Handler**, bukan di Server Actions. Ini termasuk pengurangan kuota saat listing terbit, konfirmasi dan penolakan pembelian kuota, penyesuaian kuota oleh admin, pembuatan, perpanjangan, dan pembatalan booking, serta penandaan terjual.
2. Aturan yang menjaga konsistensi data, misalnya kuota tidak boleh negatif dan satu listing hanya punya satu booking aktif, ditegakkan di basis data (constraint, RLS, atau fungsi Postgres), bukan hanya di kode aplikasi.
3. Logika yang tidak berhubungan dengan tampilan ditulis sebagai TypeScript murni di folder tersendiri, tanpa import dari Next.js atau React. Contohnya validasi domain email, perhitungan status booking kedaluwarsa, format rupiah, dan skema Zod.
4. Server Actions boleh dipakai hanya sebagai pembungkus tipis yang memanggil fungsi di poin 1 atau 3, tidak berisi aturan bisnis sendiri.

**Alasan:** Tim membuka kemungkinan membuat aplikasi native dengan React Native di kemudian hari. Server Actions hanya dapat dipanggil dari aplikasi Next.js itu sendiri, sehingga aturan yang ditaruh di sana harus ditulis ulang untuk klien lain. Dengan aturan di basis data dan endpoint API, klien lain cukup memanggil hal yang sama. Aturan kuota juga lebih aman bila ditegakkan di basis data, karena berlaku untuk semua klien.

**Konsekuensi**

- React Native tetap menulis ulang seluruh tampilan, tetapi dapat memakai ulang backend, tipe data, skema validasi, logika murni, berkas teks antarmuka, dan token warna.
- Flutter hanya dapat memakai ulang backend.
- Membungkus PWA dengan Capacitor tetap mungkin, tetapi aplikasi yang hanya membungkus situs web berisiko ditolak App Store. Perlu diverifikasi saat dibutuhkan.
- Keputusan ini tidak mengubah rencana rilis pertama: aplikasi tetap PWA (D-02).

---

## D-11 — Vitest sebagai test runner untuk logika di src/lib/domain/

**Status:** Disetujui, 23 September 2026

**Keputusan**

Vitest dipakai sebagai test runner untuk logika murni di `src/lib/domain/`. Tes dijalankan dengan `npm test`.

**Alasan:** Aturan keamanan seperti validasi domain email kampus harus dites ulang setiap kali ada perubahan. Kesalahan kecil, misalnya menerima `x@binus.ac.id.evil.com`, tidak terlihat dari tampilan dan baru ketahuan setelah akun yang tidak berhak berhasil mendaftar.

**Konsekuensi**

- Vitest hanya dipasang sebagai devDependency dan tidak ikut ke bundle aplikasi.
- Versi yang dipakai adalah Vitest 4, karena Vitest 5 membutuhkan `@types/node` versi 22 ke atas, sedangkan proyek masih memakai versi 20.

---

## D-12 — Hosting di Netlify

**Status:** Disetujui, 24 September 2026

**Keputusan:** Aplikasi di-deploy ke Netlify paket Free, untuk pengembangan maupun rilis.

**Alasan**

- Netlify mengizinkan penggunaan komersial di paket Free, sedangkan Vercel Hobby tidak. BeeKas memungut fee, jadi termasuk penggunaan komersial.
- Batas bulanan paket Free (sekitar 100 GB bandwidth dan 125.000 pemanggilan function, per pengumuman Netlify November 2024) jauh di atas perkiraan volume satu semester. Angka ini perlu dicek ulang di halaman harga Netlify sebelum dipakai untuk laporan.
- Biaya hosting Rp0 selama volume di bawah batas.

**Konsekuensi**

- Bila batas bulanan terlampaui, situs dihentikan sampai akhir bulan, bukan ditagih. Pantau pemakaian menjelang dan selama BINUS Festival, dan siapkan upgrade bila mendekati batas.
- Kompatibilitas Next.js versi terpasang dan service worker di Netlify belum diuji. Uji deploy dilakukan sebelum Fase 1 berjalan jauh.
- Pengembangan langsung di Netlify, tanpa Vercel, supaya tidak ada perpindahan platform di tengah jalan.
- Alternatif bila Netlify tidak cocok: Cloudflare Workers (paket $5 per bulan) atau Vercel Pro ($20 per bulan).

## D-13 — Draf listing dengan AI dipertahankan

**Status:** Disetujui, 24 September 2026

**Keputusan:** Fitur draf listing dengan Claude API tetap bagian dari produk (Fase 5 roadmap), bukan dihapus.

**Alasan:** Draf AI adalah salah satu pembeda BeeKas yang sudah dipresentasikan. Perkiraan biayanya kecil: dengan model kelas Haiku, sekitar $0,003 per draf, atau sekitar 5% dari fee Rp1.000 per listing. Angka ini perkiraan dan perlu dicek setelah implementasi.

**Konsekuensi**

- Batas jumlah draf per pengguna wajib ada (bagian 8 PRD), karena pemanggilan AI tidak mengurangi kuota.
- Kredit API kemungkinan perlu dibeli di muka. Biaya ini masuk perhitungan COGS.
- Model yang dipakai disimpan sebagai konstanta di server agar mudah diganti.
- AI tetap menjadi fitur pertama yang ditunda bila waktu tidak cukup. MVP Transaksi tidak bergantung padanya.

## D-14 — Pengiriman email OTP bertahap, domain dibeli di awal Fase 7

**Status:** Disetujui, 24 September 2026. Mengubah konsekuensi D-01 bahwa SMTP kustom dipasang sejak awal.

**Keputusan**

1. Selama pengembangan (Fase 1 sampai 6), OTP dikirim lewat SMTP bawaan Supabase. Bila batas kirimnya terlalu kecil untuk tes tim, pakai Gmail dengan App Password dari akun email tim.
2. Domain BeeKas dibeli di awal Fase 7, sebelum uji coba dengan pengguna di luar tim.
3. Setelah domain ada, SMTP kustom dipasang dengan domain pengirim terverifikasi, dan aplikasi dipindah ke domain tersebut.

**Alasan**

- Menunda biaya domain sampai benar-benar dibutuhkan.
- Pengiriman email dilakukan oleh server Supabase, jadi pilihan SMTP tidak bergantung pada platform aplikasi (PWA, React Native, atau Flutter).
- Aplikasi harus pindah ke domain sendiri sebelum banyak orang memasang PWA, karena aplikasi terpasang, sesi login, dan cache offline terikat pada alamat situs.

**Konsekuensi**

- Tes OTP di Fase 1 hanya membuktikan alur login. Keterkiriman ke email kampus dari domain sendiri baru teruji di Fase 7, sehingga domain tidak boleh dibeli menjelang Festival.
- SMTP bawaan Supabase tidak mengizinkan perubahan template email untuk project Free baru. Tampilan email OTP bawaan diterima selama pengembangan.
- Domain didaftarkan dengan akun tim, dan biaya perpanjangan tahunannya masuk perhitungan COGS.

## D-15 — Alur kerja branch, Pull Request, dan CI

**Status:** Disetujui, 24 September 2026

**Keputusan**

1. Semua perubahan masuk ke `main` lewat Pull Request dari branch fitur. Tidak ada commit langsung ke `main`.
2. GitHub Actions menjalankan lint, typecheck, test, build, dan pengecekan kredensial untuk setiap PR dan push ke `main`. PR tidak boleh di-merge bila CI merah.
3. Netlify membuat Deploy Preview untuk setiap PR. `main` otomatis ter-deploy ke produksi.
4. Merge memakai squash merge dan selalu dilakukan manusia. Asisten koding boleh membuka PR, tidak boleh merge.
5. Migrasi basis data dijalankan manual, tidak otomatis dari CI, sampai ada project Supabase produksi terpisah.
6. Rincian alur ada di [`workflow.md`](workflow.md).

**Alasan**

- Setelah D-12, setiap push ke `main` langsung live. Tanpa PR dan CI, perubahan yang belum dites bisa dipakai pengguna.
- Deploy Preview memberi tempat menguji tampilan dari desain Figma di HP sebelum masuk produksi.
- Merge oleh manusia menjadi titik persetujuan yang jelas untuk pekerjaan multi-agent.

**Konsekuensi**

- Branch protection untuk `main` harus diaktifkan oleh pemilik repo. Tanpa itu, aturan ini hanya kesepakatan.
- Node.js dikunci lewat `.nvmrc` agar versi di laptop, CI, dan Netlify sama.
- CI tidak memakai kredensial Supabase sungguhan. Tes yang butuh basis data (misalnya RLS dengan dua akun) masih dijalankan manual ke `beekas-dev` sampai ada Supabase lokal di CI.
- Deploy Preview dan produksi memakai project `beekas-dev` yang sama sampai project produksi dibuat. Data uji di Preview ikut terlihat di produksi.

---

## Keputusan yang masih terbuka

| Topik | Pertanyaan |
|---|---|
| Paket kuota | Pilihan paket dan harganya, misalnya 5 dan 10 listing. |
| Kuota gratis akun baru | Ada atau tidak, dan berapa. Membantu masalah cold start di awal. |
| Kuota saat listing dihapus | Dikembalikan atau tidak bila listing dihapus sebelum terjual. |
| Target waktu konfirmasi | Berapa jam paling lama admin mengonfirmasi pembelian kuota. |
| Batas perpanjangan booking | Berapa kali penjual boleh memperpanjang, dan berapa lama setiap perpanjangan. |
| Sanksi pembeli yang tidak datang | Misalnya pembatasan booking sementara setelah beberapa kali tidak menyelesaikan transaksi. |
| Notifikasi ke pembeli | Saat booking diperpanjang atau berakhir: lewat email, di dalam aplikasi, atau tidak ada pada rilis pertama. |
| Batas klaim donasi | Batas klaim per akun untuk mencegah barang donasi diambil lalu dijual kembali. |
| Bahasa pesan awal WhatsApp | Pesan dikirim pembeli sebagai dirinya sendiri, sehingga bahasa Indonesia mungkin lebih wajar. |
| Bahasa draf listing dari AI | Inggris mengikuti antarmuka, atau Indonesia mengikuti kebiasaan pengguna. |
