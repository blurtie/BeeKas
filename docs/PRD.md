# PRD — BeeKas

Product Requirements Document, versi 0.2 (23 September 2026)
Dokumen ini dipakai sebagai brief pengerjaan di Claude Code.

Status: **draf**. Bagian bertanda `[KEPUTUSAN]` belum diputuskan tim. Asisten koding tidak boleh menebak bagian tersebut. Implementasikan bagian lain, lalu sediakan titik yang mudah diubah (konstanta atau kolom) untuk bagian yang belum diputuskan.

Keputusan beserta alasannya dicatat di [`decisions.md`](decisions.md). Kalau dokumen ini bertentangan dengan `decisions.md`, ikuti `decisions.md` dan laporkan pertentangannya.

**Perubahan dari versi 0.1:** komisi titip jual digantikan fee listing Rp1.000 yang dibayar lewat kuota. Ditambahkan listing donasi, domain `@binus.edu`, mekanisme booking 1x24 jam, dan PWA. Kanal komunikasi ditetapkan lewat WhatsApp.

---

## 1. Ringkasan

BeeKas adalah marketplace barang preloved dan donasi khusus sivitas BINUS University. Penjual memotret barang, sistem menyusun draf listing dengan bantuan AI, lalu barang terbit di katalog yang dapat dicari. Pembeli melakukan booking, menghubungi penjual lewat WhatsApp, dan bertransaksi secara COD di kampus.

Tiga hal yang membedakannya dari jualan lewat media sosial: barang tidak tenggelam karena berbentuk katalog, status ketersediaan ditampilkan eksplisit dan dijaga batas waktu booking, dan identitas pengguna terverifikasi lewat email kampus.

## 2. Masalah yang diselesaikan

1. Unggahan jualan di media sosial dan grup chat tenggelam dalam hitungan hari, sehingga barang sulit ditemukan kembali.
2. Pembeli tidak tahu barang masih tersedia atau sudah terjual, sehingga waktu kedua pihak terbuang.
3. Identitas penjual tidak dapat diverifikasi, sehingga transaksi bernilai tinggi sering batal.
4. Tidak ada acuan harga barang bekas, sehingga penjual menebak dan pembeli tidak punya pembanding.
5. Barang yang tidak lagi bernilai jual dibuang, padahal masih dibutuhkan sivitas lain.

## 3. Tujuan dan batasan

**Tujuan rilis pertama**

- Pengguna terverifikasi dapat memasang listing dalam waktu kurang dari satu menit sejak membuka aplikasi, selama kuotanya tersedia.
- Setiap listing memiliki status ketersediaan yang akurat dan terlihat sekilas.
- Booking yang tidak ditindaklanjuti tidak menahan listing lebih lama dari batas waktunya.
- Seluruh pembelian kuota dan transaksi tercatat dan dapat diekspor sebagai CSV untuk pelaporan.
- Aplikasi dapat dibuka dari tautan di ponsel tanpa pemasangan, dan dapat dipasang ke layar utama sebagai PWA.

**Bukan tujuan rilis pertama**

- Pembayaran harga barang atau rekening bersama di dalam aplikasi. Pembayaran barang terjadi langsung antara pembeli dan penjual. Yang dibayar melalui BeeKas hanya kuota listing.
- Payment gateway otomatis. Pembelian kuota dikonfirmasi manual oleh admin.
- Chat di dalam aplikasi
- Pengiriman barang dan integrasi kurir
- Aplikasi native iOS dan Android
- Fitur sosial: umpan aktivitas, pengikut, komentar publik
- Sistem penilaian atau rating penjual
- Notifikasi push

**Ukuran keberhasilan**

| Metrik | Cara ukur |
|---|---|
| Barang terjual atau terdonasikan | Jumlah listing berstatus Terjual |
| Penjual yang kembali | Penjual dengan listing kedua atau lebih |
| Pendapatan | Total nilai pembelian kuota yang dikonfirmasi |
| Booking yang selesai | Persentase booking yang berakhir Terjual, bukan kedaluwarsa atau dibatalkan |
| Waktu pasang listing | Selisih waktu unggah foto sampai listing terbit |
| Akurasi saran harga AI | Selisih median antara harga saran dan harga terjual |

## 4. Pengguna

**Penjual** — sivitas BINUS yang punya barang menganggur. Motivasi utamanya melepas barang tanpa repot, bukan mencari untung maksimal.

**Donatur** — penjual yang memberikan barangnya secara gratis. Tetap membayar kuota listing.

**Pembeli** — sivitas BINUS, umumnya mahasiswa, yang membutuhkan barang kuliah dengan harga lebih murah atau gratis. Motivasi utamanya barang terjamin dan bisa diambil di kampus.

**Admin** — anggota tim yang mengonfirmasi pembelian kuota dan memantau data.

Satu akun dapat menjadi penjual dan pembeli sekaligus.

## 5. Alur utama

**Onboarding**
Pengguna mendaftar dengan email kampus dan memasukkan kode OTP yang dikirim ke email tersebut. Setelah terverifikasi, pengguna mengisi profil.

**Membeli kuota**
Penjual memilih paket kuota. Aplikasi menampilkan QRIS milik tim beserta nominalnya. Penjual membayar dari e-wallet atau m-banking, lalu mengunggah bukti bayar. Setelah admin mengonfirmasi, kuota bertambah.

**Memasang barang**
Penjual memilih jenis listing (jual atau donasi) dan mengunggah satu foto. Sistem mengirim foto ke model AI, yang mengembalikan draf judul, kategori, kondisi, deskripsi, dan rentang harga. Penjual mengoreksi draf, menyetujui pernyataan kepemilikan, lalu menerbitkannya. Penerbitan mengurangi satu kuota. Listing terbit dengan status Tersedia.

**Mencari dan booking**
Pembeli menelusuri katalog, membuka halaman detail, lalu menekan tombol booking. Status berubah menjadi Dibooking dengan batas waktu 1x24 jam. Pembeli menghubungi penjual lewat tombol WhatsApp untuk mengatur COD.

**Menutup transaksi**
Setelah barang berpindah tangan, penjual menandai listing Terjual dan mengisi harga akhir. Bila perlu, penjual dapat memperpanjang batas booking atau membatalkannya. Booking yang melewati batas waktu tanpa perpanjangan otomatis berakhir.

## 6. Kebutuhan fungsional

Penomoran dipakai sebagai acuan saat implementasi dan commit.

### F1 — Autentikasi dan verifikasi

- F1.1 Pendaftaran dan masuk memakai kode OTP yang dikirim ke email. Hanya domain `@binus.ac.id` dan `@binus.edu` yang diterima. Pemeriksaan domain dilakukan di server, bukan hanya di formulir.
- F1.2 Domain yang diizinkan disimpan sebagai satu konstanta, bukan ditulis di banyak tempat.
- F1.3 `[KEPUTUSAN]` Jalur verifikasi alumni yang email kampusnya sudah tidak aktif. Sampai diputuskan, jangan implementasikan. Sediakan kolom `verification_method` pada profil.
- F1.4 Pengguna yang belum masuk dapat menelusuri katalog, tetapi tidak dapat melakukan booking, memasang listing, maupun melihat nomor WhatsApp.
- F1.5 Sesi login bertahan sampai pengguna keluar secara eksplisit.

### F2 — Profil

- F2.1 Profil berisi nama panggilan, email, jenis pengguna, nomor WhatsApp, dan kampus utama.
- F2.2 Jenis pengguna diturunkan dari domain email: `@binus.ac.id` sebagai mahasiswa, `@binus.edu` sebagai dosen atau staf. Pengguna tidak memilihnya sendiri.
- F2.3 Mahasiswa wajib mengisi jurusan dan BINUSIAN. Dosen dan staf tidak mengisi keduanya.
- F2.4 Jurusan dipilih dari daftar program studi S1 BINUS, dikelompokkan per fakultas atau school, ditambah opsi "Lainnya". Daftar disimpan sebagai konstanta.
- F2.5 BINUSIAN dipilih dari daftar B27 sampai B30. Nilainya memakai tahun kelulusan, bukan tahun masuk, dan keterangan ini ditampilkan di bawah kolom isian.
- F2.6 Yang terlihat oleh pengguna lain hanya nama panggilan, jenis pengguna, jurusan, BINUSIAN, dan kampus. Email tidak pernah ditampilkan. Nomor WhatsApp hanya terlihat oleh pengguna yang sudah masuk, dan hanya di halaman detail listing.

### F3 — Kuota listing

- F3.1 Istilah di antarmuka, kode, dan basis data adalah **kuota**, bukan saldo. Satu kuota setara satu listing seharga Rp1.000.
- F3.2 Kuota tidak dapat diuangkan kembali, tidak dapat dipindahkan ke akun lain, dan hanya dapat dipakai untuk menerbitkan listing. Aturan ini ditampilkan kepada pengguna sebelum membeli.
- F3.3 `[KEPUTUSAN]` Pilihan paket dan harganya. Simpan daftar paket sebagai konstanta atau tabel, bukan ditulis di komponen.
- F3.4 `[KEPUTUSAN]` Kuota gratis untuk akun baru. Sediakan konstanta yang bernilai 0 sampai diputuskan.
- F3.5 Alur pembelian: pilih paket, tampilkan gambar QRIS dan nominal yang harus dibayar, unggah bukti bayar, lalu pembelian berstatus `pending`.
- F3.6 Bukti bayar disimpan di bucket penyimpanan privat. Hanya pemilik pembelian dan admin yang dapat melihatnya.
- F3.7 Pengguna dapat melihat riwayat pembelian beserta statusnya: menunggu konfirmasi, dikonfirmasi, atau ditolak dengan alasan.
- F3.8 Sisa kuota dihitung dari buku besar kuota (penjumlahan seluruh entri), bukan dari satu angka yang ditimpa. Setiap penambahan dan pengurangan tercatat sebagai entri tersendiri.
- F3.9 Pengurangan kuota saat listing terbit dan pembuatan listing terjadi dalam satu transaksi basis data di server. Dua permintaan bersamaan tidak boleh membuat kuota negatif.
- F3.10 `[KEPUTUSAN]` Kuota dikembalikan atau tidak bila listing dihapus sebelum terjual. Sampai diputuskan, tidak dikembalikan.

### F4 — Memasang listing

- F4.1 Penjual memilih jenis listing: `jual` atau `donasi`. Listing donasi tidak memiliki harga dan ditampilkan dengan label Gratis.
- F4.2 Unggah satu foto dari kamera atau galeri. Gambar dikompresi di sisi klien sebelum dikirim, dengan sisi terpanjang maksimal 1024 piksel.
- F4.3 Foto dikirim ke model AI melalui backend. **Tidak boleh ada pemanggilan API model langsung dari peramban.** Pemanggilan AI tidak mengurangi kuota.
- F4.4 Draf dari AI mengisi judul, kategori, kondisi, deskripsi, dan rentang harga. Seluruh kolom tetap dapat diubah pengguna. Untuk listing donasi, rentang harga diabaikan.
- F4.5 Harga ditampilkan sebagai rentang saran disertai keterangan bahwa angka tersebut estimasi, bukan data transaksi.
- F4.6 Bila pemanggilan AI gagal, form tetap muncul kosong agar dapat diisi manual. Kegagalan AI tidak boleh menghentikan alur.
- F4.7 Kategori barang terlarang ditolak sistem: obat dan suplemen, makanan dan minuman, rokok dan vape, minuman beralkohol, senjata, dokumen identitas, barang bajakan, konten dewasa, dan hewan.
- F4.8 Pengguna wajib menyetujui pernyataan bahwa barang miliknya sendiri dan data profilnya boleh ditampilkan, sebelum tombol terbit aktif.
- F4.9 Bila kuota habis, tombol terbit diganti ajakan membeli kuota. Draf yang sudah diisi tidak hilang.

### F5 — Katalog dan pencarian

- F5.1 Katalog menampilkan listing berstatus Tersedia dan Dibooking, diurutkan dari yang terbaru.
- F5.2 Pencarian teks bekerja pada judul dan deskripsi.
- F5.3 Filter jenis (jual atau donasi), kategori, dan kampus.
- F5.4 Kartu listing menampilkan foto, harga atau label Gratis, judul, kampus, dan badge status bila sedang dibooking.
- F5.5 Katalog kosong dan hasil pencarian kosong memiliki tampilan dan ajakan yang berbeda.
- F5.6 `[KEPUTUSAN]` Paginasi atau muat bertahap. Untuk volume awal, muat seluruhnya masih memadai.

### F6 — Halaman detail

- F6.1 Menampilkan foto, harga atau label Gratis, judul, status, kondisi, kategori, identitas penjual, kampus, tanggal pemasangan, dan deskripsi.
- F6.2 Halaman detail memiliki metadata Open Graph (judul, harga, foto) yang dirender di server, agar tautan yang dibagikan di WhatsApp menampilkan pratinjau barang tersebut.
- F6.3 Tombol WhatsApp membuka `https://wa.me/<nomor>?text=<pesan awal>` di tab baru. Nomor diubah ke format 62 sebelum dipakai. Pesan awal menyebut judul barang dan tautan listing.
- F6.4 Tombol booking tampil untuk pengguna yang sudah masuk bila listing Tersedia. Bila listing sedang dibooking orang lain, tampilkan sisa waktu booking.
- F6.5 Listing berstatus Terjual ditampilkan diredupkan, dan tombol booking serta WhatsApp nonaktif.
- F6.6 Pemilik listing melihat tombol pengelolaan, bukan tombol booking.

### F7 — Booking

- F7.1 Satu listing hanya dapat memiliki satu booking aktif. Penjual tidak dapat mem-booking listing miliknya sendiri.
- F7.2 Booking mencatat pembeli dan batas waktu `booked_until`, dengan nilai default 24 jam sejak booking.
- F7.3 Listing dengan `booked_until` yang sudah lewat diperlakukan sebagai Tersedia setiap kali data dibaca, tanpa job terjadwal. Booking tersebut tercatat berakhir karena kedaluwarsa.
- F7.4 Penjual dapat memperpanjang booking aktif. `[KEPUTUSAN]` Batas jumlah perpanjangan dan lamanya. Simpan sebagai konstanta.
- F7.5 Penjual dapat membatalkan booking aktif. Pembeli dapat membatalkan booking miliknya.
- F7.6 Setiap booking disimpan sebagai riwayat tersendiri beserta cara berakhirnya: terjual, kedaluwarsa, dibatalkan penjual, atau dibatalkan pembeli. Data ini dipakai untuk sanksi di kemudian hari.
- F7.7 `[KEPUTUSAN]` Sanksi bagi pembeli yang sering tidak menyelesaikan booking. Jangan implementasikan sampai diputuskan.
- F7.8 `[KEPUTUSAN]` Batas klaim listing donasi per akun. Jangan implementasikan sampai diputuskan.
- F7.9 `[KEPUTUSAN]` Notifikasi ke pembeli saat booking diperpanjang atau berakhir. Sampai diputuskan, cukup tampilkan status dan sisa waktu di halaman detail dan di daftar booking milik pembeli.

### F8 — Pengelolaan listing milik sendiri

- F8.1 Daftar listing milik pengguna beserta statusnya dan booking aktifnya.
- F8.2 Saat menandai Terjual pada listing jual, penjual wajib mengisi harga akhir yang benar-benar dibayar. Angka ini terpisah dari harga pasang dan dipakai untuk mengukur akurasi saran harga.
- F8.3 Sunting listing selama belum berstatus Terjual. Penyuntingan tidak mengurangi kuota.
- F8.4 Hapus listing selama belum berstatus Terjual dan tidak sedang dibooking.
- F8.5 Listing yang tidak diperbarui selama 30 hari ditandai perlu diperbarui, dan penjual diminta mengonfirmasi ketersediaannya.

### F9 — Panel admin

- F9.1 Akses terbatas pada akun beratribut admin, diperiksa di server. Tidak boleh memakai PIN yang tersimpan di sisi klien.
- F9.2 Daftar pembelian kuota berstatus menunggu, lengkap dengan bukti bayar, nominal, waktu, dan nama pembeli.
- F9.3 Admin mengonfirmasi atau menolak pembelian. Penolakan wajib disertai alasan. Konfirmasi menambah entri pada buku besar kuota dan mencatat admin yang mengonfirmasi.
- F9.4 Di halaman konfirmasi tampil pengingat bahwa konfirmasi harus dicocokkan dengan mutasi di aplikasi merchant QRIS, bukan hanya dengan screenshot.
- F9.5 Admin dapat menambah atau mengurangi kuota secara manual dengan alasan tertulis, misalnya untuk koreksi. Penyesuaian tercatat sebagai entri tersendiri.
- F9.6 Ringkasan angka: jumlah listing per jenis, jumlah terjual, nilai transaksi barang, pendapatan dari kuota, jumlah penjual unik, dan jumlah booking per cara berakhir.
- F9.7 Ekspor CSV untuk listing dan pembelian kuota. **Nomor WhatsApp dan email tidak ikut diekspor.**
- F9.8 `[KEPUTUSAN]` Penanganan laporan penyalahgunaan, perlu atau tidak pada rilis pertama.

## 7. Model data

Titik awal, bukan skema final. Seluruh tabel memakai Row Level Security.

**profiles**
`id` (sama dengan id pengguna Supabase Auth), `nickname`, `email`, `user_type` (`student` atau `staff`), `major`, `binusian`, `whatsapp`, `campus`, `verification_method`, `is_admin`, `created_at`

**listings**
`id`, `seller_id`, `type` (`sale` atau `donation`), `title`, `category`, `condition`, `description`, `price` (null untuk donasi), `image_path`, `status`, `sold_price`, `sold_at`, `ai_price_min`, `ai_price_max`, `ai_confidence`, `created_at`, `updated_at`

`status` bernilai `available`, `booked`, atau `sold`. Status `booked` yang booking aktifnya sudah kedaluwarsa dibaca sebagai `available`.

**bookings**
`id`, `listing_id`, `buyer_id`, `created_at`, `booked_until`, `extension_count`, `ended_at`, `end_reason` (`sold`, `expired`, `cancelled_by_seller`, `cancelled_by_buyer`, atau null bila masih aktif)

**credit_purchases**
`id`, `user_id`, `package_code`, `credits`, `amount`, `proof_path`, `status` (`pending`, `confirmed`, `rejected`), `rejection_reason`, `reviewed_by`, `reviewed_at`, `created_at`

**credit_ledger**
`id`, `user_id`, `delta` (positif atau negatif), `reason` (`purchase`, `listing_publish`, `signup_bonus`, `admin_adjustment`), `purchase_id`, `listing_id`, `note`, `created_by`, `created_at`

Nilai enum lain:
`category` bernilai `buku`, `lab`, `elektronik`, `kos`, atau `lainnya`.
`condition` bernilai `seperti_baru`, `bekas_mulus`, atau `ada_bekas_pakai`.

Nilai enum disimpan dalam bahasa Inggris atau sebagai kode. Label bahasa Indonesia berada di lapisan tampilan.

## 8. Kontrak integrasi AI

Endpoint backend: `POST /api/listing-draft`
Masukan: satu berkas gambar.
Keluaran: objek JSON dengan bentuk tetap di bawah ini.

```json
{
  "allowed": true,
  "rejection_reason": null,
  "photo_clear": true,
  "title": "string, maksimal 60 karakter",
  "category": "buku | lab | elektronik | kos | lainnya",
  "condition": "seperti_baru | bekas_mulus | ada_bekas_pakai",
  "description": "string, maksimal 200 karakter",
  "price_min": 0,
  "price_max": 0,
  "price_confidence": "rendah | sedang | tinggi"
}
```

Ketentuan:

- Model hanya boleh menyebut merek, model, atau judul buku apabila terbaca jelas pada foto. Dilarang menebak.
- Deskripsi hanya memuat hal yang terlihat pada foto, termasuk cacat yang tampak.
- Harga dalam rupiah untuk barang bekas di Indonesia, dibulatkan ke kelipatan 5.000.
- `allowed` bernilai false untuk kategori barang terlarang pada F4.7, disertai `rejection_reason` singkat.
- `photo_clear` bernilai false bila barang tidak terlihat jelas.
- Backend wajib memvalidasi bentuk keluaran sebelum dikirim ke klien. Keluaran yang tidak sesuai diperlakukan sebagai kegagalan, dan alur berlanjut ke F4.6.
- Batasi laju permintaan per pengguna untuk mencegah pembengkakan biaya, karena pemanggilan AI tidak mengurangi kuota.

## 9. Kebutuhan non-fungsional

- **Mobile-first.** Dirancang pada lebar 390 piksel, tetap rapi sampai lebar peramban desktop.
- **PWA.** Manifest, ikon, mode standalone, dan kerangka aplikasi yang tetap tampil saat jaringan buruk. Pengguna iPhone mendapat panduan singkat cara memasang ke layar utama.
- **Privasi.** Data pribadi diperlakukan sesuai UU No. 27 Tahun 2022. Nomor WhatsApp hanya tampil dalam konteks transaksi. Bukti bayar hanya dapat dilihat pemilik dan admin. Ekspor data tidak memuat kontak.
- **Keamanan.** Kredensial model AI dan basis data hanya berada di server. Otorisasi diperiksa di server dan di Row Level Security, bukan disembunyikan di antarmuka. Operasi yang menyangkut kuota berjalan di server.
- **Aksesibilitas.** Kontras teks memadai, target sentuh minimal 44 piksel, fokus papan ketik terlihat, gambar memiliki teks alternatif.
- **Kinerja.** Katalog dapat dipakai dalam waktu wajar pada jaringan seluler. Gambar dikompresi sebelum diunggah.

## 10. Arah visual

Desain rinci belum ada. Yang sudah ditetapkan baru token warna dan satu elemen pembeda.

| Peran | Nilai |
|---|---|
| Aksen utama (madu) | `#FFC93C` |
| Teks dan elemen gelap | `#241B0E` |
| Tombol utama | `#8A5A12` |
| Latar | `#FBF8F2` |
| Kartu | `#FFFFFF` |
| Garis | `#E3DCCD` |
| Teks sekunder | `#6B6154` |

Elemen pembeda: label harga berbentuk hang tag, yaitu persegi dengan ujung kiri meruncing dan titik menyerupai lubang tali, ditempel sedikit miring di pojok kanan atas foto barang. Pada listing donasi, label yang sama bertuliskan Gratis. Elemen ini menjadi satu-satunya bagian yang mencolok; sisanya dibuat tenang.

Seluruh teks antarmuka dalam bahasa Indonesia. Label tombol memakai kata kerja yang menjelaskan akibatnya, bukan "Submit" atau "OK".

## 11. Keputusan teknis

Stack sudah diputuskan. Rinciannya ada di `decisions.md` (D-01 sampai D-08).

- `[KEPUTUSAN]` Penyedia hosting. Harus mengizinkan penggunaan komersial karena BeeKas memungut fee.

## 12. Urutan pengerjaan

1. Kerangka proyek, token desain, tata letak dasar dengan navigasi bawah, dan PWA
2. Autentikasi dan profil (F1, F2), termasuk uji pengiriman OTP ke kedua domain email
3. Buku besar kuota dengan penyesuaian manual oleh admin (F3.8, F3.9, F9.5), lalu listing tanpa AI, katalog, dan halaman detail (F4 kecuali AI, F5, F6)
4. Pembelian kuota lewat QRIS dan konfirmasi admin (F3, F9.1 sampai F9.4)
5. Booking dan pengelolaan listing milik sendiri (F7, F8)
6. Integrasi AI (F4.3 sampai F4.7)
7. Ringkasan admin dan ekspor CSV (F9.6, F9.7)

Penyesuaian kuota manual dibuat lebih dulu pada tahap 3 agar listing dapat diuji tanpa menunggu alur pembelian. AI diletakkan pada tahap keenam karena tanpa katalog, kuota, dan alur transaksi yang berjalan, fitur AI tidak dapat diuji secara bermakna.

## 13. Kriteria selesai untuk rilis pertama

- Pengguna baru dengan email `@binus.ac.id` atau `@binus.edu` dapat mendaftar, membeli kuota, dan memasang listing pertama tanpa bantuan. Email domain lain ditolak.
- Pembelian kuota yang dikonfirmasi admin menambah kuota dengan tepat, dan dua penerbitan bersamaan tidak membuat kuota negatif.
- Listing yang terpasang dapat ditemukan lewat pencarian dan filter oleh akun lain.
- Tautan listing yang dibagikan di WhatsApp menampilkan pratinjau foto, judul, dan harga barang tersebut.
- Tombol WhatsApp membuka percakapan dengan pesan awal yang benar.
- Booking yang melewati batas waktu tanpa perpanjangan membuat listing kembali tersedia.
- Status dapat diubah sampai Terjual, lengkap dengan harga akhir untuk listing jual.
- Ekspor CSV dapat dibuka di spreadsheet dan tidak memuat kontak.
- Kegagalan AI tidak menghentikan proses pemasangan listing.
- Tidak ada kredensial yang dapat dilihat dari sisi klien, dan bukti bayar tidak dapat dibuka oleh pengguna lain.
