# BeeKas

Marketplace barang preloved dan donasi khusus sivitas BINUS University.

> **Status: awal pengembangan.** Prototype fungsional sudah ada untuk keperluan validasi, dan stack aplikasi sudah ditentukan. Beberapa keputusan produk masih terbuka dan tercatat di bagian [Keputusan yang masih terbuka](#keputusan-yang-masih-terbuka).

---

## Latar belakang

Barang kuliah punya masa pakai yang pendek. Buku mata kuliah, jas lab, kalkulator, dan alat gambar biasanya hanya terpakai satu sampai dua semester, lalu menganggur di lemari sampai pemiliknya lulus. Sebagian besar berakhir dibuang, padahal masih layak pakai dan masih dibutuhkan mahasiswa angkatan di bawahnya.

Jual-beli barang bekas antar mahasiswa sebenarnya sudah berjalan, tetapi lewat kanal yang tidak dirancang untuk itu.

**Media sosial dan grup chat berbentuk lini masa.** Unggahan jualan di Twitter/X atau grup WhatsApp angkatan terlihat ramai pada hari pertama, lalu tenggelam oleh unggahan baru. Ketika ada calon pembeli yang tertarik seminggu kemudian, unggahannya sudah sulit ditemukan kembali. Masalahnya ada pada format kanalnya, bukan pada minat pembelinya.

**Status ketersediaan tidak terpantau.** Pembeli yang berhasil menemukan unggahan lama tetap harus bertanya lebih dulu apakah barangnya masih ada. Sering kali jawabannya baru datang beberapa hari kemudian, dan ternyata barang sudah lama terjual. Waktu kedua pihak terbuang.

**Identitas penjual tidak dapat diverifikasi.** Di kanal terbuka, pembeli tidak tahu siapa lawan transaksinya. Untuk barang bernilai ratusan ribu rupiah, keraguan ini cukup untuk membatalkan niat membeli.

**Tidak ada acuan harga.** Penjual menebak harga sendiri, pembeli tidak punya pembanding, dan tawar-menawar berlangsung tanpa dasar.

Marketplace umum seperti OLX dan Carousell menyelesaikan masalah pertama karena berbentuk katalog, tetapi terbuka untuk umum sehingga tidak menjawab persoalan identitas dan tempat bertemu, serta mengasumsikan pengiriman berongkir untuk transaksi yang sebenarnya bisa diselesaikan dengan berjalan kaki di kampus yang sama.

## Solusi yang diusulkan

BeeKas membatasi aksesnya pada sivitas BINUS, lalu membangun tiga hal di atas pembatasan tersebut:

1. **Katalog, bukan lini masa.** Barang disimpan dalam katalog yang dapat dicari dan difilter per kategori. Barang yang diunggah hari ini tetap dapat ditemukan bulan depan.
2. **Status ketersediaan yang eksplisit.** Setiap listing memiliki status Tersedia, Sedang dibooking, atau Terjual, sehingga pembeli tidak perlu bertanya lebih dulu.
3. **Identitas penjual yang terverifikasi.** Akun hanya dapat dibuat dengan email kampus `@binus.ac.id` (mahasiswa) atau `@binus.edu` (dosen dan staf). Profil menampilkan identitas yang terikat pada akun kampus tersebut. Transaksi dilakukan secara COD di lingkungan kampus.

Selain barang yang dijual, pengguna juga dapat memasang **listing donasi**, yaitu barang yang diberikan secara gratis kepada sesama sivitas BINUS. Fitur ini mendukung tujuan circular economy: barang yang tidak lagi bernilai jual tetap dapat dipakai ulang alih-alih dibuang.

Sebagai pelengkap, penyusunan listing dibantu model AI: penjual cukup mengunggah satu foto, lalu judul, kategori, kondisi, deskripsi, dan kisaran harga tersusun sebagai draf yang tinggal dikoreksi. Tujuannya menurunkan hambatan terbesar penjual, yaitu keharusan mengetik listing dari nol.

Saran harga yang dihasilkan AI adalah estimasi, bukan data pasar. Karena itu ditampilkan sebagai rentang dan selalu dapat diubah penjual. Setelah terkumpul cukup data transaksi, saran harga direncanakan beralih ke acuan berbasis riwayat penjualan.

## Model bisnis

**Fee listing Rp1.000 per listing**, dibayar penjual saat memasang barang. Fee ini berlaku untuk listing jual maupun listing donasi.

- Model ini menggantikan skema potongan persentase dari harga jual, yang terlalu besar untuk barang preloved yang umumnya murah.
- Nominalnya sengaja kecil supaya tidak menghambat penjual di tahap awal.
- Pada listing donasi, fee tidak dimaksudkan untuk mencari untung dari barang yang diberikan gratis. Fungsinya menyaring listing spam dan listing asal-asalan, sehingga katalog tetap berisi barang yang benar-benar tersedia.

**Cara bayar: paket kuota listing.** Penjual membeli paket kuota (satu kuota untuk satu listing) dengan membayar ke QRIS milik tim, lalu mengunggah bukti bayar. Admin mencocokkan bukti dengan mutasi yang masuk, lalu mengonfirmasi. Setiap listing yang terbit mengurangi satu kuota. Kuota tidak dapat diuangkan kembali atau dipindahkan ke akun lain.

## Mekanisme booking

1. Pembeli menekan tombol booking, lalu menghubungi penjual lewat tombol WhatsApp untuk mengatur COD. Status listing berubah menjadi **Sedang dibooking**.
2. Pembeli wajib menyelesaikan COD atau pembayaran kepada penjual **paling lambat 1x24 jam** sejak booking.
3. Penjual dapat memperpanjang batas waktu tersebut, misalnya saat booking dilakukan menjelang akhir pekan atau hari libur. Tanpa perpanjangan, batas default tetap 1x24 jam.
4. Setelah barang berpindah tangan, penjual mengubah status menjadi **Terjual**.

Batas waktu ini menjaga status barang tetap akurat, sehingga listing tidak tertahan oleh booking yang tidak ditindaklanjuti.

## Ruang lingkup

**Termasuk dalam ruang lingkup**

- Barang kuliah dan perlengkapan penunjang: buku, jas lab dan alat praktikum, elektronik kecil, perlengkapan kos
- Listing jual dan listing donasi
- Pengguna: mahasiswa, dosen, dan staf BINUS dengan email `@binus.ac.id` atau `@binus.edu`
- Transaksi tatap muka di lingkungan kampus

**Di luar ruang lingkup untuk saat ini**

- Pembayaran harga barang dan rekening bersama di dalam aplikasi. Pembayaran barang tetap terjadi langsung antara pembeli dan penjual; yang dibayar melalui BeeKas hanya fee listing
- Pengiriman barang antarkota
- Aplikasi native iOS dan Android
- Fitur sosial seperti umpan aktivitas, pengikut, dan komentar publik

Keputusan untuk menunda hal-hal di atas diambil karena tidak satu pun berkontribusi langsung terhadap terjualnya barang pada tahap validasi.

## Prinsip yang dipegang

- **Keterlihatan barang lebih penting daripada kelengkapan fitur.** Setiap penambahan fitur harus menjawab pertanyaan: apakah ini membuat barang lebih cepat ditemukan dan terjual?
- **AI menyusun draf, manusia memutuskan.** Tidak ada listing yang terbit tanpa dikoreksi penjualnya.
- **Klaim harus punya dasar.** Angka dampak yang ditampilkan terbatas pada jumlah barang yang berhasil dipakai ulang. Klaim emisi karbon tidak dicantumkan karena belum tersedia dasar perhitungan yang dapat dipertanggungjawabkan.
- **Data pengguna diperlakukan sesuai UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi.** Nomor WhatsApp dan identitas kampus hanya ditampilkan dalam konteks transaksi dan atas persetujuan pengguna.

## Status saat ini

| Bagian | Status |
|---|---|
| Rumusan masalah dan analisis kompetitor | Selesai |
| Prototype fungsional untuk validasi | Berjalan |
| Survei harga dan kebutuhan pengguna | Sedang berjalan |
| Uji coba transaksi pertama | Belum |
| Penentuan model bisnis (fee listing) | Selesai |
| Penentuan stack aplikasi | Selesai, kecuali hosting |
| Implementasi aplikasi | Berjalan: kerangka aplikasi selesai, lihat [roadmap](docs/roadmap.md) |

Prototype yang ada saat ini merupakan prototipe validasi, bukan basis kode produksi. Fungsinya membuktikan alur produk kepada calon pengguna, bukan menjadi fondasi aplikasi akhir.

## Rencana teknis

**Stack yang dipilih**

| Bagian | Pilihan |
|---|---|
| Framework | Next.js (App Router) + TypeScript + Tailwind CSS, dijadikan PWA agar dapat dipasang di layar utama ponsel |
| Basis data, autentikasi, penyimpanan gambar | Supabase (Postgres, Auth dengan kode OTP email, Storage) |
| Email OTP | Penyedia SMTP kustom |
| Model AI | Claude API, dipanggil dari server |
| Hosting | Belum ditentukan |

Kebutuhan yang menjadi dasar pemilihan:

- Antarmuka mobile-first yang dapat dibuka langsung dari tautan tanpa pemasangan aplikasi, termasuk pratinjau listing yang benar saat tautan dibagikan di WhatsApp
- Autentikasi berbasis email institusi, hanya menerima domain `@binus.ac.id` dan `@binus.edu`
- Penyimpanan berkas gambar
- Pemanggilan model AI **melalui backend**, bukan langsung dari peramban, agar kredensial tidak terekspos ke pengguna
- Pencatatan transaksi dan fee listing yang dapat diekspor untuk keperluan pelaporan

Rincian kebutuhan ada di [`docs/PRD.md`](docs/PRD.md), keputusan beserta alasannya di [`docs/decisions.md`](docs/decisions.md), dan urutan pengerjaan di [`docs/roadmap.md`](docs/roadmap.md).

## Keputusan yang masih terbuka

- [x] **Kanal komunikasi pembeli dan penjual:** lewat WhatsApp, tanpa chat di dalam aplikasi.
- [x] **Cara bayar fee listing:** paket kuota listing lewat QRIS dengan konfirmasi manual oleh admin.
- [ ] **Paket kuota:** pilihan paket dan harganya, dan ada atau tidaknya kuota gratis untuk akun baru.
- [ ] **Batas perpanjangan booking:** berapa kali penjual boleh memperpanjang, dan apa yang terjadi setelah batas waktu lewat (misalnya status otomatis kembali ke Tersedia).
- [ ] **Sanksi pembeli yang tidak datang:** misalnya pembatasan booking sementara setelah beberapa kali tidak menyelesaikan transaksi.
- [ ] **Notifikasi ke pembeli** saat booking diperpanjang atau berakhir.
- [ ] **Klaim listing donasi:** batas klaim per akun untuk mencegah barang donasi diambil lalu dijual kembali.
- [x] **Alumni:** tidak ada jalur terpisah. Alumni hanya dapat mendaftar bila email kampusnya masih aktif.
- [ ] **Hosting.** Karena BeeKas memungut fee, penyedia hosting harus mengizinkan penggunaan komersial.

## Tim

| Nama | Peran | Tanggung jawab |
|---|---|---|
| Clarencia | CEO | Arah produk, kemitraan, dokumentasi |
| Faiqi | CTO | Arsitektur, prototype, integrasi AI |
| Najwa | CFO | Struktur biaya, harga, pencatatan transaksi |
| Shana | CMO | Branding, konten, riset pengguna |
| Evan | COO | Operasional, pengujian, logistik |

## Konteks akademik

Proyek ini dikembangkan dalam mata kuliah **ENPR6312001 Venture Creation**, Binus Entrepreneurship Center, tahun akademik 2026/2027.

Sesuai ketentuan penggunaan AI kategori Type 3 (Flexible), penggunaan AI dalam proyek ini dideklarasikan sebagai berikut: AI digunakan untuk membantu pengembangan ide, penyusunan dokumentasi, dan pembuatan prototype. Keputusan bisnis, pelaksanaan riset, dan penulisan laporan akhir dilakukan oleh tim.

## Lisensi

Belum ditentukan. Selama masa pengembangan, seluruh isi repositori ini merupakan karya tim dan tidak untuk digunakan ulang tanpa izin.

---

*Nama "BeeKas" berasal dari kata "bekas" — padanan pre-loved dalam bahasa Indonesia — dan dari kata "Binusian". Ketersediaan nama ini sebagai merek dagang belum diperiksa di DJKI.*
