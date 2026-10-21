# PRD BeeKas (Flutter) — Katalog, Jual-Beli, dan Pindah ke Cloud

Versi 0.2 (draf), 21 Oktober 2026. Sumber: D-22, D-26, D-27–D-33 di `docs/decisions.md`, ekspor Figma 20 Oktober di `docs/design/`, issue #13, #73, #76, #77, dan PR #75 (katalog baca). Istilah di `CONTEXT.md`; PRD login di `docs/PRD.md`. Keputusan K-01–K-41 dicatat sebagai D-34–D-40 (21 Oktober 2026).

Semua pertanyaan K-xx sudah diputuskan (D-34–D-40), kecuali **K-11** yang menunggu persetujuan CFO. Tanda **[KEPUTUSAN]** = belum diputuskan dan tidak boleh dikerjakan sebelum disetujui. Ringkasannya ada di bagian 13.

Tenggat: **BINUS Festival, 23–25 November 2026** (D-27). Pengguna sungguhan memakai Supabase cloud, Android saja, tanpa fitur listing AI.

## 1. Masalah

Katalog baca (#75) sudah bisa dilihat tamu dan member, tetapi isinya data seed. Member `approved` belum bisa memasang barang, menghubungi penjual, atau menahan dan membeli barang. Tim juga belum punya cara menerima bayaran kuota, menurunkan barang terlarang, atau membekukan akun yang menyalahgunakan aplikasi. Semua ini masih berjalan di Supabase lokal, sehingga pengunjung Festival belum bisa memakainya dari HP sendiri.

## 2. Solusi

Member `approved` memasang barang dengan kuota yang dibeli lewat QRIS dan dikonfirmasi admin. Pembeli menahan barang dengan Booking 24 Jam atau berjanji membeli dengan Beli Sekarang, lalu menyepakati lokasi dan waktu COD lewat chat teks di aplikasi. Pengguna bisa melapor; admin menurunkan listing dan membekukan akun dengan persetujuan dua admin. Penjual bisa membayar Boost atau Featured agar barangnya lebih terlihat. Backend pindah ke Supabase cloud dengan langkah yang tercatat dan diperiksa sebelum dibuka ke pengguna.

## 3. Pengguna dan akses

| Aktor | Akses (D-06, D-31) |
|---|---|
| Tamu, `incomplete`, `pending`, `rejected` | Lihat katalog, detail barang, dan profil penjual. Tidak bisa chat, booking, beli, pasang barang, favorit, atau lapor. |
| Member `approved` | Semua fitur di PRD ini. |
| Member `approved` yang dibekukan | Lihat bagian 5.9 (K-26). |
| Admin | Fitur member + layar admin: konfirmasi pembayaran, laporan, turunkan listing, pembekuan, pengumuman Admin BeeKas. |

Semua aturan akses ditegakkan di `lib/domain/` (tombol, layar) **dan** di backend (RLS/RPC). Aplikasi tidak pernah menjadi satu-satunya penjaga.

## 4. Lingkup

**Termasuk (D-27):** katalog (paginasi dan pencarian di server, favorit), pasang dan kelola barang, kuota dan pembayaran QRIS dengan konfirmasi admin, Booking 24 Jam, Beli Sekarang, Pesanan Saya, chat teks, lapor, moderasi (turunkan listing, pembekuan dua admin), Boost dan Featured (paling akhir), dan pindah ke Supabase cloud.

**Tidak termasuk:** ulasan/rating, follow, notifikasi push (setelah Festival, D-27); blokir pengguna (D-31); iOS; listing AI; pengiriman barang (D-22.3); pembayaran barang lewat aplikasi (COD saja); gateway pembayaran otomatis; refund otomatis.

**K-01 Notifikasi untuk Festival (D-37).** Badge jumlah di tab **Pesanan Saya** dan **Chat** masuk lingkup Festival, tanpa push: Pesanan Saya menghitung pesanan yang menunggu tindakan saya (penjual: pesanan Menunggu; pembeli: perubahan status oleh pihak lain sejak terakhir dibuka), Chat menghitung percakapan dengan pesan baru sejak terakhir dibuka. Daftar notifikasi lengkap (`daftar-10.png`) dibangun bila sempat (T15, setelah titik potong). Email untuk hal penting dikirim setelah penyedia email dipilih (K-38, T0). Ini memenuhi D-33 secara bertahap.

## 5. Alur dan layar per fitur

Kolom "Desain" berisi file ekspor 20 Oktober di `docs/design/` (D-22), atau **Tanpa desain**: dibangun dari komponen Material 3 dan `lib/ui/`, mengikuti CLAUDE.md, ditandai "belum ada desain" di PR. Teks putih di atas kuning pada frame diganti warna token (D-22.6).

| # | Layar | Desain |
|---|---|---|
| K1 | Beranda | `home.png` (dibangun di #75) |
| K2 | Kategori | `daftar-12.png` (dibangun di #75) |
| K3 | Detail Barang | `daftar-14.png` (dibangun di #75) |
| K4 | Favorit | Tanpa desain |
| K5 | Tambah Barang (langkah 1: jenis, kategori, foto, nama, deskripsi) | `daftar-11.png` |
| K6 | Tambah Barang (langkah 2: kondisi, harga, stok, garansi, spesifikasi, lokasi) | Tanpa desain |
| K7 | Barang Saya (kelola, edit, turunkan, sisa masa tayang) | Tanpa desain |
| K8 | Kuota dan beli paket (QRIS, unggah bukti) | Tanpa desain |
| K9 | Booking Barang (konfirmasi) | `daftar-13.png` |
| K10 | Status Booking | `daftar-5.png` |
| K11 | Checkout Beli Sekarang | `daftar-7.png` (dengan koreksi COD) |
| K12 | Pesanan Saya (pembeli) dan Pesanan Masuk (penjual) | `daftar-8.png` (dengan koreksi COD) |
| K13 | Detail Pesanan (status, Lokasi COD, waktu COD, batal, selesai) | Tanpa desain |
| K14 | Daftar Chat | `daftar-9.png` |
| K15 | Ruang Chat (kartu barang, pesan teks, peringatan kontak) | Tanpa desain |
| K16 | Lapor (listing atau pengguna) | Tanpa desain |
| K17 | Profil (versi Festival) | `daftar-6.png` (sebagian; lihat 5.10) |
| K18 | Admin: konfirmasi pembayaran | Tanpa desain |
| K19 | Admin: laporan dan turunkan listing | Tanpa desain |
| K20 | Admin: pembekuan akun (usul dan setujui) | Tanpa desain |
| K21 | Admin: kirim pengumuman Admin BeeKas | Tanpa desain |
| K22 | Boost dan Featured (beli untuk satu listing) | Tanpa desain |

### 5.1 Katalog (K1–K4)

Sudah ada dari #75: Beranda dengan 5 pintasan kategori, grid Rekomendasi, Kategori dengan chip, Detail dengan harga coret, pencarian di aplikasi. Perubahan di PRD ini:

- **Paginasi dan pencarian di server (#77, D-28).** `catalog_listings` menerima kata kunci, kategori (atau grup pintasan), batas, dan cursor keyset `(created_at, id)`. Server mencocokkan kata kunci dengan nama barang dan nama penjual, tidak peka huruf besar-kecil; kategori dari label digabung dengan OR (K-02). Beranda dan Kategori memuat bertahap saat digulir, dengan keadaan memuat/kosong/error di ujung daftar. `matchesSearch` di aplikasi dihapus setelah server menggantikannya.
  - **K-02 Pencarian label kategori dua bahasa.** Label kategori ada di `copy.dart` (D-11), bukan di database. Diputuskan (D-41): kata kunci yang sama dengan salah satu kata label kategori EN atau ID (tidak peka huruf besar-kecil, "&" diabaikan) diubah aplikasi menjadi kode kategori. Hasilnya listing yang nama barang atau nama penjualnya memuat kata kunci ATAU kategorinya cocok. Kata kunci yang tidak cocok dengan kata label mana pun hanya menjadi pencarian teks. Grup pintasan tetap membatasi hasil. Alternatif: tabel label kategori EN/ID di database.
- **Hanya penjual `approved` dan tidak dibekukan (#76).** Listing penjual yang tidak lagi `approved` atau sedang dibekukan tidak tampil, baik lewat RPC maupun tabel langsung. Pembekuan memakai kolom terpisah (D-33), sehingga pertanyaan "status dibekukan di enum" di #76 terjawab: tidak menambah enum.
- **Stok habis.** Listing dengan sisa stok 0 tidak tampil di katalog (lihat 6.4).
- **Masa tayang 60 hari (D-28).** Listing yang melewati masa tayang tidak tampil.
- **Favorit (D-28):** ikon hati di kartu dan detail menyimpan barang ke K4, hanya terlihat oleh pemiliknya. Tamu yang menekan hati diarahkan ke Masuk. Barang yang sudah tidak tayang tetap ada di Favorit dengan label "Tidak tersedia".
- **Profil penjual publik.** **K-03** Apakah Festival butuh halaman profil penjual (nama, Verified BINUS, kampus, barang aktif)? D-32 mengizinkan tamu melihat profil, tetapi ulasan dan follow menyusul. Diputuskan: belum; detail barang sudah menampilkan nama, kampus, dan Verified. Tetap Segera hadir.
- **"Lihat semua"** di Beranda tetap tidak dibuat (grid sudah bergulir tanpa batas).

### 5.2 Pasang dan kelola barang (K5–K7)

Alur: tombol **+** → (bukan `approved`: pesan sesuai status, D-06) → K5 → K6 → Pasang. Saat Pasang, server memotong 1 kuota dan listing langsung tayang (D-28, D-29). Bila kuota habis, tombol Pasang membuka K8 dan isian tidak hilang.

- **K5 (`daftar-11.png`):** Jual Barang atau Donasi Barang; Pilih Kategori (9 kategori, D-28); Foto Produk 1–5 dari kamera atau galeri (D-28); Nama Produk; Deskripsi.
  - Koreksi kecil terhadap frame: penghitung deskripsi di frame "0/500", sedangkan tabel saat ini mengizinkan 2.000 karakter. **K-04** Batas deskripsi: 500 (ikut frame, butuh migrasi constraint) atau 2.000 (ikut skema #75)? Diputuskan: 500, ikut desain.
  - Dropdown kategori di frame menunjukkan "Elektronik" (nama grup). Yang dipilih adalah 9 kategori, bukan grup.
- **K6 (tanpa desain):** Kondisi (3 pilihan, D-28); Harga (Rp1.000–Rp50.000.000; disembunyikan dan bernilai Rp0 untuk donasi); Stok (≥ 1); Garansi (opsional); Spesifikasi (opsional, 1–10 baris); Lokasi = kampus, default kampus di profil penjual (D-28). Ringkasan sisa kuota di atas tombol Pasang.
- **Foto (K-05, D-34):** galeri diizinkan untuk listing (beda dari verifikasi, D-02). Aplikasi menerima JPEG, PNG, dan WebP, lalu mengonversi semuanya ke JPEG sebelum unggah, dengan metadata lokasi dibuang (`stripJpegMetadata` yang sudah ada dipakai setelah konversi). Bucket hanya menerima JPEG. Konversi memakai kompresi bawaan `image_picker` (`imageQuality`), tanpa dependency baru; bila ternyata tidak menghasilkan JPEG untuk semua format, berhenti dan ajukan opsi.
- **K7 Barang Saya:** daftar listing milik sendiri dengan status (Tayang, Habis, Kedaluwarsa, Diturunkan admin, Diturunkan sendiri), sisa hari tayang, sisa stok, dan tombol Edit / Turunkan.
- **Edit (D-28):** boleh mengubah harga, deskripsi, stok, kondisi, garansi, spesifikasi, lokasi. Tidak boleh mengganti foto. "Tidak boleh mengganti barang": **K-06** diputuskan: nama barang, kategori, dan jenis (jual/donasi) dikunci setelah tayang. Harga turun → harga coret otomatis (trigger dari #75).
- **Turunkan sendiri:** listing tidak tayang lagi; kuota tidak kembali (D-29: tanpa refund). Bila ada pesanan berjalan, turunkan ditolak sampai pesanan selesai/dibatalkan.
- **Kedaluwarsa 60 hari (K-07, D-34):** listing kedaluwarsa bisa ditayangkan ulang oleh penjual **gratis, tanpa memotong kuota** (jawaban kuesioner 2.10); masa tayang mulai lagi 60 hari.
- **Barang terlarang (D-33):** alkohol, rokok/vape, makanan, hewan, obat. Ditampilkan sebagai pengingat di K5; penegakannya lewat laporan dan admin, bukan saringan otomatis.

### 5.3 Kuota dan pembayaran QRIS (K8, K18)

Paket: Rp15.000 = 3 listing, berlaku juga untuk donasi. Penjual baru mendapat 1 listing gratis. Kuota tidak kedaluwarsa. Tanpa refund kecuali kesalahan sistem atau admin (D-29).

Alur member (K8, tanpa desain):
1. Lihat sisa kuota dan riwayat pembelian.
2. Pilih "Beli paket" → tampil gambar QRIS atas nama CFO dan nominal Rp15.000.
3. Bayar di aplikasi bank/e-wallet, lalu unggah tangkapan layar bukti bayar.
4. Status "Menunggu konfirmasi admin (maks. 1×24 jam)".
5. Admin mengonfirmasi → kuota bertambah 3. Admin menolak → alasan tampil, member bisa mengunggah ulang.

Alur admin (K18, tanpa desain): daftar pembayaran menunggu, terlama di atas; buka bukti; masukkan nominal yang benar-benar diterima; Konfirmasi atau Tolak dengan alasan. Setelah dikonfirmasi atau ditolak, file bukti dihapus; yang tersimpan hanya nominal, waktu, dan admin pemeriksa (D-29).

- **"1 listing gratis":** **K-08** diputuskan: setiap akun mendapat saldo kuota awal 1 saat pertama kali menjadi `approved`, sekali seumur akun.
- **Gambar QRIS:** aset statis di aplikasi atau file di storage? **K-09** diputuskan: file di storage publik yang bisa diganti tanpa rilis ulang APK. Gambar QRIS dan nama CFO tidak dianggap secret, tetapi tidak di-commit sampai CFO setuju.
- **Bukti ditolak:** **K-10** Bukti yang ditolak juga dihapus? Diputuskan: ya, dihapus saat ditolak; yang tersimpan alasan, waktu, admin. Bila tidak ada keputusan dalam 30 hari, bukti dihapus seperti foto verifikasi (D-07 sebagai pola).
- **Satu jalur untuk semua pembayaran:** pembelian paket, Boost, dan Featured memakai tabel dan layar admin yang sama, dibedakan jenisnya (5.11).
- **Nominal tidak cocok** (bayar kurang/lebih): usulan admin menolak dengan alasan dan uang dikembalikan manual oleh CFO di luar aplikasi. [KEPUTUSAN] **K-11: menunggu persetujuan CFO** (menyentuh aturan refund D-29). Sampai disetujui, bagian ini tidak dikerjakan di T6.

### 5.4 Booking 24 Jam (K9, K10, K12, K13)

Booking = menahan 1 unit barang tanpa janji beli. Tidak ada pembayaran saat booking (D-30, `daftar-13.png`).

Alur: Detail Barang → **Booking 24 Jam** → K9 (konfirmasi: "Barang akan ditahan selama 24 jam … Tidak ada pembayaran saat booking") → **Booking Sekarang** → K10 (Berhasil di-booking, hitung mundur, Chat Penjual, Kembali).

- Stok berkurang 1 saat booking dibuat (D-28).
- Status mengikuti D-30: Menunggu konfirmasi penjual → Diproses → Selesai / Dibatalkan.
- **Hitung mundur 24 jam** dimulai saat booking dibuat. **K-12** Apakah 24 jam tetap berjalan setelah penjual mengonfirmasi (Diproses), atau berhenti karena barang sudah disepakati? Diputuskan: berjalan sampai Diproses; setelah Diproses tidak ada batas 24 jam lagi, tetapi waktu COD wajib diisi (lihat 5.6).
- **Batal otomatis** setelah 24 jam bila belum Diproses; stok kembali +1. Dijalankan `pg_cron` di server, bukan di aplikasi.
- **Perpanjang sekali (D-30)** atas persetujuan penjual: pembeli meminta, penjual menyetujui di K13, batas bertambah 24 jam. **K-13** Lama perpanjangan: diputuskan +24 jam.
- **Booking → beli:** **K-14** Bila pembeli memutuskan membeli, apakah booking diubah menjadi Beli Sekarang (tanpa melepas stok), atau cukup penjual mengonfirmasi booking menjadi Diproses? Diputuskan: booking yang dikonfirmasi penjual (Diproses) sudah berarti transaksi berjalan; tidak ada konversi terpisah.
- Pembeli tidak bisa mem-booking barangnya sendiri, dan tidak bisa punya dua pesanan berjalan untuk listing yang sama.

### 5.5 Beli Sekarang (K11, K12, K13)

Beli Sekarang = janji beli dengan harga listing (D-30). Alur: Detail → **Beli Sekarang** → K11 Checkout → **Konfirmasi Pesanan** → Pesanan Saya.

**Koreksi desain D-22.3 di K11 (`daftar-7.png`):**
- Kartu "Alamat Pengiriman" diganti **"Lokasi COD"**: pilihan kampus (default kampus listing) + teks bebas (mis. "Lobi Anggrek, depan ATM") (D-30). Tombol "Ubah" membuka isian itu.
- Metode pembayaran tetap "COD", tetapi teks "Bayar langsung saat barang diterima" dan "Cash on Delicery" diperbaiki menjadi teks COD di kampus (typo di frame).
- "Biaya Lainnya" dihapus: tidak ada biaya lain.
- qty selalu 1 (D-28: setiap pembelian = 1 unit).

- Stok berkurang 1 saat pesanan dibuat. Dibatalkan → stok +1.
- Harga yang tersimpan di pesanan adalah harga listing saat pesanan dibuat. Tawar-menawar lewat chat; bila sepakat, penjual menurunkan harga listing **sebelum** pembeli memesan (D-30).
- **K-15** Pesanan Beli Sekarang yang tidak dikonfirmasi penjual: batal otomatis setelah berapa lama? D-30 hanya mengatur batas untuk booking. Diputuskan: 24 jam, sama dengan booking.

### 5.6 Pesanan Saya, status, COD, selesai, batal (K12, K13)

**Koreksi desain D-22.3 di K12 (`daftar-8.png`):** chip "Dikirim" dan badge "Dalam perjalanan" diganti. Chip (K-16 terkait, D-36): **Semua · Menunggu · Diproses · Selesai · Dibatalkan**, sesuai status D-30. Badge menampilkan status yang sama, dan untuk booking juga sisa waktu.

- K12 punya dua tab: **Pembelian** (saya pembeli) dan **Penjualan** (saya penjual). **K-16** Diputuskan: daftar penjual = tab Penjualan di Pesanan Saya.
- **K13 Detail Pesanan:** barang, harga, jenis (Booking / Beli Sekarang), status, Lokasi COD, waktu COD, tombol Chat, serta aksi sesuai peran dan status:
  - Penjual, Menunggu: **Terima** (→ Diproses) atau **Tolak/Batalkan** (alasan wajib).
  - Pembeli, Menunggu atau Diproses: **Batalkan** (alasan wajib, tanpa sanksi, D-30).
  - Penjual, Diproses: **Batalkan** (alasan wajib).
  - Pembeli, Diproses: **Sudah diterima** (→ Selesai).
  - Booking, Menunggu: pembeli **Minta perpanjangan**; penjual **Setujui perpanjangan**.
- **Waktu COD:** D-30 menyebut Selesai otomatis 3 hari setelah waktu COD, sehingga waktu COD harus tersimpan. **K-17** Siapa yang mengisi waktu COD dan kapan? Diputuskan: penjual wajib mengisi tanggal-jam COD saat Terima (Diproses), setelah disepakati di chat; bisa diubah kedua pihak selama Diproses. Lokasi COD diisi pembeli saat checkout/booking dan bisa diubah selama belum Selesai.
- **Selesai otomatis** 3 hari setelah waktu COD bila pembeli belum menekan Sudah diterima (`pg_cron`).
- **Alasan batal:** **K-18** daftar kode tetap + catatan (pola D-25) atau teks bebas? Diputuskan: kode tetap (berubah pikiran, barang tidak sesuai, tidak bisa bertemu, sudah terjual di luar, lainnya) + catatan wajib bila Lainnya, supaya dua bahasa.

### 5.7 Donasi

Donasi = listing dengan harga Rp0 (D-28), dipesan lewat Booking 24 Jam atau Beli Sekarang seperti barang biasa. "Siapa cepat dia dapat" = pesanan pertama yang masuk mendapat unitnya; tidak ada antrean atau seleksi oleh penjual.

- **Maksimal 2 donasi berjalan per orang (D-30):** pesanan donasi berstatus Menunggu atau Diproses dihitung; Selesai dan Dibatalkan tidak. Pesanan ketiga ditolak server dengan pesan yang jelas.
- **K-19** Bolehkah penjual donasi menolak pemesan pertama (mis. tidak membalas chat)? Diputuskan: boleh, lewat Batalkan dengan alasan; unit kembali ke stok untuk pemesan berikutnya.

### 5.8 Chat teks (K14, K15; #13)

- Satu percakapan per pasangan pembeli–penjual (D-31), tidak per barang. Percakapan dimulai dari tombol **Chat Penjual** di Detail Barang atau Status Booking; kartu barang terakhir yang dibicarakan menempel di atas ruang chat.
- Hanya `approved` (D-31). Penjual tidak bisa memulai chat dengan pembeli yang belum pernah menghubunginya.
- Teks saja; tanpa tanda dibaca dan tanpa status online (D-31). Pesan baru tampil langsung lewat Supabase Realtime (sudah termasuk di `supabase_flutter`, tanpa dependency baru).
- K14 (`daftar-9.png`): chip Semua / Penjual, nama, cuplikan pesan terakhir, waktu. Avatar: ikon (belum ada foto profil, sama dengan #75). "Penjual" = percakapan tempat saya pembeli.
- **Admin BeeKas (D-31):** kanal pengumuman satu arah, tampil di daftar chat semua member. Member tidak bisa membalas. Admin mengirim lewat K21.
- **Peringatan kontak (D-31, K-20, D-37):** bila teks yang akan dikirim terlihat seperti nomor HP, tautan WhatsApp/Telegram, atau username media sosial, muncul peringatan keamanan sebelum terkirim; pengguna tetap boleh mengirim. Deteksinya aturan domain di `lib/domain/`. Pola: nomor `08…`/`+62…`/`62…` 9+ digit (spasi/strip boleh), `wa.me`, `t.me`, `@username`, dan kata "WA", "whatsapp", "line", "ig", "telegram". **Semua pola kata memakai batas kata**, sehingga "online", "deadline", "big", dan harga "1.500.000" tidak terdeteksi; tes wajib memuat contoh-contoh negatif ini.
- **Lapor** dari ruang chat tersedia (5.9). Blokir menyusul (D-31).
- Batas panjang pesan: **K-21** diputuskan: 1.000 karakter.

### 5.9 Lapor dan moderasi (K16, K19, K20, K21)

**Lapor (K16, tanpa desain):** dari Detail Barang (melaporkan listing) dan dari ruang chat (melaporkan pengguna). Hanya `approved`. Isi: alasan dari daftar kode + catatan opsional (wajib bila Lainnya).
- **K-22** Daftar alasan lapor. Diputuskan: barang terlarang (D-33), penipuan, barang tidak sesuai, konten tidak pantas, spam, lainnya.
- Satu pelapor hanya bisa melapor objek yang sama sekali selama laporan masih terbuka.
- Pelapor tidak melihat hasil tindak lanjut selain "Laporan terkirim".

**Turunkan listing (K19, D-28):** admin melihat laporan terbuka (dikelompokkan per objek, jumlah pelapor), membuka listing atau cuplikan chat yang dilaporkan, lalu **Turunkan listing** (alasan wajib) atau **Abaikan**. Listing yang diturunkan tidak tayang; penjual melihat status dan alasannya di Barang Saya. Kuota tidak kembali, kecuali admin menurunkan karena kesalahan admin (D-29), lewat tombol "Kembalikan kuota" dengan catatan.
- **K-23** Pesanan berjalan pada listing yang diturunkan: diputuskan dibatalkan otomatis dengan alasan "Listing diturunkan admin".
- **K-24 (D-38)** Admin membaca isi chat hanya pada percakapan yang dilaporkan, dan hanya selama laporan terbuka. **Kebijakan Privasi wajib memuat aturan ini** sebelum aplikasi dibuka ke pengguna (lihat 8.2).

**Pembekuan akun (K20, D-33, #76):**
- Disimpan di kolom/tabel terpisah dari status akun; status `approved` tidak berubah.
- Butuh dua admin: admin A mengusulkan dengan alasan; admin **lain** (B ≠ A) menyetujui atau menolak usulan. Pembekuan baru berlaku setelah disetujui B. Mencairkan juga butuh dua admin **K-25** (diputuskan: ya, pola yang sama).
- Admin tidak bisa mengusulkan atau menyetujui pembekuan akunnya sendiri.
- Akibat pembekuan: **K-26** diputuskan: listing tidak tayang (#76), tidak bisa pasang barang, pesan, chat, atau melapor; pesanan berjalan dibatalkan otomatis dengan alasan "Akun dibekukan"; akun tetap bisa masuk dan melihat katalog, dengan banner "Akunmu dibekukan" dan tombol Bantuan.
- Banding lewat Bantuan (D-14), diperiksa admin yang tidak terlibat dalam pembekuan (D-33). Penegakan "admin lain" untuk banding dilakukan manual; aplikasi menampilkan siapa pengusul dan penyetuju.

**Pengumuman Admin BeeKas (K21):** admin menulis teks, pratinjau, kirim ke semua member. Tidak bisa diedit setelah terkirim. Opt-in promo (D-33): **K-27** diputuskan: untuk Festival tidak ada pengumuman promo; Admin BeeKas hanya untuk informasi layanan, sehingga opt-in belum dibutuhkan.

**#73 (cari akun dari nomor HP):** tidak termasuk PRD ini kecuali diputuskan lain; tetap di backlog admin.

### 5.10 Profil versi Festival (K17, `daftar-6.png`)

Yang dibangun: nama, badge Verified BINUS (`approved`), Pesanan Saya (Semua/Diproses/Selesai), Barang Saya, Kuota, Bantuan, Bahasa EN/ID, Keluar. Menu admin muncul untuk admin.

**Koreksi desain D-22.3 di K17:** menu **"Alamat Saya"** dihapus (tidak ada pengiriman). "Metode Pembayaran (COD)" dihapus karena hanya ada COD **K-28** (diputuskan: hapus).

Belum dibangun (setelah Festival, D-27/D-32): @username (D-32: tanpa username, frame perlu dikoreksi desainer), angka Mengikuti/Pengikut, badge BINUSIAN, Edit Profil.

### 5.11 Boost dan Featured (K22) — dikerjakan paling akhir

Harga: Boost Rp3.000 per 3 hari, Featured Rp5.000 per 3 hari (D-29). Dibayar lewat jalur QRIS yang sama (5.3), satu pembayaran per listing per periode. Masa 3 hari mulai saat admin mengonfirmasi pembayaran.

**K-29 Definisi tampilan (D-39):**
- **Boost** = listing naik ke urutan atas di Rekomendasi (Beranda) dan hasil Kategori selama 3 hari. Di antara listing yang di-boost, urutan terbaru dulu. Hasil pencarian dengan kata kunci tidak terpengaruh **K-30** (diputuskan: tidak, supaya pencarian tetap jujur). Kartu boost diberi label kecil "Dipromosikan" **K-31** (diputuskan: ya; transparansi untuk pembeli).
- **Featured** = listing tampil di banner Beranda (posisi kartu "Dari Binusian, Untuk Binusian" di `home.png`) selama 3 hari. Banner berganti otomatis antar listing featured; bila tidak ada, banner bawaan tampil.

Yang belum jelas:
- **K-32** Jumlah slot Featured bersamaan. Diputuskan: maksimal 5; bila penuh, pembelian ditolak sebelum bayar dengan perkiraan kapan slot kosong.
- **K-33** Boost/Featured pada listing donasi: diputuskan boleh.
- **K-34** Listing yang habis, kedaluwarsa, atau diturunkan selama masa promosi: diputuskan promosi berhenti tanpa refund, kecuali diturunkan karena kesalahan admin.
- **K-35** Boost/Featured bisa diperpanjang sebelum habis (masa ditambahkan di ujung): diputuskan ya.
- **K-36** Boost dan Featured juga berlaku di paginasi: listing boost tidak boleh tampil dua kali (di atas dan di posisi aslinya). Diputuskan: urutan server = `(boosted desc, created_at desc, id)` dan cursor ikut menyimpan status boost.

## 6. Aturan domain (`lib/domain/`, Dart murni, dengan tes di `test/domain/`)

| # | Aturan | Modul |
|---|---|---|
| 1 | Validasi listing: harga Rp1.000–Rp50.000.000, donasi Rp0; stok ≥ 1; foto 1–5; nama dan deskripsi tidak kosong dan dalam batas; spesifikasi 1–10 baris; kondisi dan kategori dari daftar tetap. | `catalog` (diperluas) |
| 2 | Field yang boleh diedit setelah tayang (K-06). | `catalog` |
| 3 | Status listing untuk penjual: Tayang / Habis / Kedaluwarsa / Diturunkan admin / Diturunkan sendiri, dari data mentah dan waktu sekarang. | `catalog` |
| 4 | Kuota: cukup untuk memasang? sisa setelah pasang; saldo awal 1 (K-08). | `quota` (baru) |
| 5 | Pembayaran: jenis (paket, Boost, Featured), nominal sesuai jenis, status Menunggu/Dikonfirmasi/Ditolak, alasan tolak wajib. | `payment` (baru) |
| 6 | Mesin status pesanan: transisi yang sah per peran (pembeli/penjual) dan status; alasan batal wajib; perpanjangan booking hanya sekali; waktu COD wajib saat Diproses (K-17). | `order` (baru) |
| 7 | Waktu: sisa waktu booking, kapan batal otomatis, kapan selesai otomatis (3 hari setelah waktu COD). Fungsi murni dengan `now` sebagai parameter. | `order` |
| 8 | Batas 2 donasi berjalan per orang. | `order` |
| 9 | Akses: `canChat`, `canOrder`, `canCreateListing`, `canReport`, `canFavorite` = `approved` dan tidak dibekukan; aksi admin hanya admin. | `access` (diperluas) |
| 10 | Deteksi kontak di pesan chat (K-20). | `chat` (baru) |
| 11 | Validasi pesan: tidak kosong, ≤ batas (K-21). | `chat` |
| 12 | Pembekuan: pengusul ≠ penyetuju; admin tidak membekukan dirinya sendiri. | `moderation` (baru) |
| 13 | Alasan lapor dan alasan batal dari daftar kode, catatan wajib bila Lainnya (pola D-25). | `moderation`, `order` |
| 14 | Boost/Featured: aktif pada waktu tertentu, sisa hari, perpanjangan di ujung masa (K-35). | `promotion` (baru) |

Modul baru hanya dibuat saat tiketnya dikerjakan. Repository interface per area (listing, pesanan, chat, pembayaran, moderasi) mengikuti pola `CatalogRepository` dengan implementasi Supabase dan palsu untuk tes.

## 7. Aturan backend (RLS, RPC, constraint)

Prinsip yang dibawa dari PRD login dan #75: member tidak punya INSERT/UPDATE/DELETE langsung pada tabel yang menjaga uang, stok, atau akses; semuanya lewat fungsi `security definer` dengan `search_path = ''` yang memeriksa `auth.uid()`, status `approved`, dan pembekuan. Setiap fungsi dan policy diuji pgTAP. Data penjual ke publik hanya nama, kampus, Verified (D-26).

### 7.1 Katalog dan listing
- `catalog_listings(query, category/group, limit, cursor)`: hanya listing aktif, belum kedaluwarsa, stok tersisa > 0, penjual `approved` dan tidak dibekukan (#76). Urutan keyset `(created_at desc, id)`; dengan Boost (K-36) urutan berubah.
- Policy select `listings`/`listing_photos` mensyaratkan hal yang sama (#76).
- `create_listing(...)`: hanya `approved` tak dibekukan; dalam satu transaksi memeriksa saldo kuota ≥ 1, mengurangi 1, mengisi `expires_at = now() + 60 hari`, menyimpan listing dan foto. Saldo kuota tidak boleh negatif (constraint `check (balance >= 0)`).
- `update_listing(...)`: hanya pemilik; kolom terkunci (K-06) ditolak; foto tidak bisa diubah.
- `withdraw_listing(id)`: hanya pemilik; ditolak bila ada pesanan berjalan.
- Kolom baru di `listings`: `expires_at`, `removed_at` + `removed_by` + `removal_reason` (admin), `withdrawn_at` (penjual). `is_active` dari #75 diganti/diturunkan dari kolom ini (detail teknis, diputuskan di tiket).
- Stok: `stock` = stok awal; sisa stok = `stock − pesanan berjalan/selesai`, atau kolom `stock_left` yang diubah hanya oleh fungsi pesanan dengan `check (stock_left between 0 and stock)`. Usulan: kolom `stock_left`, karena dikunci `select … for update` di fungsi pesanan sehingga dua pembeli tidak bisa mengambil unit terakhir bersamaan.
- Bucket `listing-photos`: unggah hanya ke folder `<user id>/…` milik sendiri, JPEG ≤ 5 MB, hanya `approved` tak dibekukan. Baca publik (sudah ada).
- Favorit: tabel `(member_id, listing_id)`, RLS hanya pemilik yang membaca/menulis.

### 7.2 Kuota dan pembayaran
- `quota_balances(member_id, balance)` dengan `check (balance >= 0)`; tidak ada grant tulis ke member. Saldo awal 1 diberikan oleh fungsi persetujuan verifikasi (K-08), idempoten.
- Riwayat perubahan kuota (`quota_ledger`: +3 pembelian, −1 pasang, +1 koreksi admin, dengan admin dan catatan) supaya saldo bisa diaudit. Usulan; bisa dipangkas menjadi saldo saja bila waktu sempit.
- `payments`: jenis, nominal yang diharapkan, listing (untuk Boost/Featured), status, path bukti, nominal diterima, admin, waktu. Member hanya membaca miliknya; menulis lewat `submit_payment(jenis, listing?)`.
- Bucket `payment-proofs` privat: member hanya mengunggah ke folder sendiri (pola D-19); tidak bisa membaca bukti, kecuali bukti di foldernya sendiri yang belum tercatat di pembayaran mana pun, semata agar aplikasi bisa menghapus bukti yang gagal (D-44); admin membaca.
- `confirm_payment(id, nominal)` / `reject_payment(id, alasan)`: hanya admin; menambah kuota atau mengaktifkan promosi dalam transaksi yang sama; menandai bukti untuk dihapus.
- Bukti dihapus lewat Storage API oleh Edge Function terjadwal (pola `delete-expired-photos`), bukan `DELETE` SQL di `storage.objects`. Bisa diperluas dari function yang ada.

### 7.3 Pesanan
- `orders`: listing, pembeli, penjual, jenis (booking/buy), harga saat pesan, `is_donation`, status, `hold_until`, `extended`, `cod_campus`, `cod_place`, `cod_at`, alasan batal (kode + catatan), siapa membatalkan, waktu-waktu status.
- Member membaca pesanan tempat ia pembeli atau penjual; tidak ada tulis langsung.
- `place_order(listing, jenis, cod_campus, cod_place)`: `approved` tak dibekukan; bukan listing sendiri; listing tayang; mengunci listing, `stock_left − 1` (gagal bila 0); untuk donasi menghitung pesanan donasi berjalan < 2; tidak ada pesanan berjalan lain untuk pasangan pembeli–listing yang sama.
- `accept_order(id, cod_at)`, `cancel_order(id, kode, catatan)`, `complete_order(id)`, `request_extension(id)`, `approve_extension(id)`, `update_cod(id, …)`: memeriksa peran dan transisi sah (sama dengan aturan domain 6); batal mengembalikan `stock_left + 1`.
- `pg_cron` tiap 5–15 menit: batal otomatis booking/pesanan yang lewat `hold_until` dan belum Diproses; Selesai otomatis 3 hari setelah `cod_at`. Satu fungsi SQL, tanpa Edge Function.
- Constraint: status dari enum; `hold_until` wajib untuk Menunggu; `cod_at` wajib untuk Diproses/Selesai (K-17).

### 7.4 Chat
- `conversations(buyer_id, seller_id)` unik per pasangan; `messages(conversation_id, sender_id, body, listing_id?, created_at)` dengan `check (char_length(body) between 1 and N)`.
- Member hanya membaca percakapan tempat ia peserta. Menulis lewat `send_message(seller_or_conversation, body, listing?)`: `approved` tak dibekukan; percakapan baru hanya dari pembeli ke penjual sebuah listing tayang.
- Admin BeeKas: tabel `announcements` dibaca semua member yang masuk, ditulis hanya lewat `post_announcement` oleh admin.
- Realtime: publikasi `messages` dengan RLS aktif (Realtime menghormati RLS untuk Postgres Changes).
- Admin membaca pesan hanya lewat fungsi yang mensyaratkan laporan terbuka atas percakapan itu (K-24).

### 7.5 Lapor dan moderasi
- `reports`: pelapor, objek (listing atau member + percakapan), kode, catatan, status (terbuka/ditindak/diabaikan), admin, waktu. Unik per (pelapor, objek) selama terbuka. Ditulis lewat `submit_report`; dibaca hanya admin (pelapor hanya miliknya).
- `remove_listing(id, alasan)`, `dismiss_report(id)`, `restore_quota(member, catatan)`: hanya admin.
- `freezes`: member, alasan, diusulkan oleh + waktu, disetujui oleh + waktu, dicairkan (usul/setuju) + waktu. Constraint `check (approved_by <> proposed_by)` dan `check (member_id <> proposed_by and member_id <> approved_by)`. Ditulis hanya lewat `propose_freeze`, `approve_freeze`, `reject_freeze`, `propose_unfreeze`, `approve_unfreeze`.
- Fungsi `is_frozen(member)` dipakai di semua RPC member di atas dan di policy katalog.

### 7.6 Boost dan Featured
- `promotions(listing_id, kind, starts_at, ends_at, payment_id)`; dibuat hanya oleh `confirm_payment`. Constraint slot Featured (K-32) diperiksa di `submit_payment` dan lagi di `confirm_payment` (dengan kunci) supaya tidak melebihi slot.
- `catalog_listings` mengurutkan boost aktif dulu (K-36); `featured_listings()` untuk banner.

## 8. Pindah ke Supabase cloud (bagian tersendiri)

Menjalankan migrasi ke cloud **wajib persetujuan pemilik project** (CLAUDE.md). Bagian ini hanya menyusun urutan dan checklist; eksekusinya dilakukan manusia atau dengan persetujuan eksplisit per langkah.

### 8.1 Urutan
0. **Penyedia email (K-38, D-40, T0) — penghambat Festival.** Di cloud, OTP pendaftaran (D-03) dan lupa kata sandi butuh SMTP penyedia email sendiri; SMTP bawaan Supabase hanya untuk percobaan. Pilih penyedia yang punya SMTP (untuk Auth) dan API HTTP (untuk `send-decision-emails`, cloud-checklist 6), periksa batas paket gratisnya (email per hari/bulan, domain pengirim) **dari dokumentasi resmi penyedia**, dan bandingkan dengan perkiraan pendaftar Festival. Pemilihan penyedia = layanan baru, jadi diajukan dengan 2–3 opsi untuk disetujui. Kunci API di Edge Function Secrets dan pengaturan SMTP di dashboard, tidak di repo.
1. **Siapkan project cloud** (manusia), K-37 (D-40): region **Singapura**; paket diputuskan **CFO**. Bila paket Free: project bisa di-pause saat tidak dipakai dan tidak ada backup harian, sehingga backup manual wajib (K-41) dan project harus dipastikan aktif sebelum dan selama Festival. Catat project-ref di luar repo.
2. **Migrasi login** (sudah ada, `20261006…` s.d. `20261026…`) + `20261027120000_listings.sql`, dengan `supabase db push` **tanpa** `--include-seed` (cloud-checklist 4). Seed lokal dan `config.toml` bucket tidak terbawa; bucket `listing-photos` dibuat oleh migrasi.
3. **Langkah dashboard login** dari `docs/cloud-checklist.md` 1–3: template email OTP (`{{ .Token }}`), jeda 60 detik, admin cloud.
4. **Function dan Vault:** deploy `send-decision-emails` dan `delete-expired-photos` (`--no-verify-jwt`), isi Vault: `decision_emails_url`, `decision_emails_cron_secret`, `photo_retention_url`, `photo_retention_cron_secret` (nilai acak baru, bukan dari `seed.sql`, tidak pernah ditulis di repo/issue/PR/chat). Penyedia email sudah terpasang dari T0 (K-38).
5. **Migrasi PRD ini** didorong bertahap sesuai urutan tiket (bagian 11); setiap migrasi yang menambah `pg_cron` atau function ikut menambah langkah Vault di cloud-checklist pada PR yang sama.
6. **Admin cloud per orang (D-21, K-39):** lima akun admin, satu per anggota tim, dibuat manual; peran admin diberikan lewat SQL manual satu kali per orang oleh pemilik project. Kata sandi dibuat masing-masing orang, tidak dibagikan. Tidak ada akun admin bersama. `admin@beekas.test` tidak pernah ada di cloud.
7. **Build APK cloud (K-40, D-40):** URL dan anon key cloud lewat `--dart-define`, tidak di-commit. Distribusi **APK langsung lewat QR di booth**, bukan Play Store. APK rilis ditandatangani kunci signing rilis yang dibuat di T12: keystore dan kata sandinya disimpan di luar repo (mis. pengelola kata sandi tim, minimal dua pemegang), `key.properties` dan `*.jks` masuk `.gitignore`. Kunci yang hilang berarti pengguna harus uninstall untuk memperbarui, jadi cadangannya wajib.

### 8.2 Pemeriksaan sebelum dibuka ke pengguna
Ditambahkan ke `docs/cloud-checklist.md` sebagai bagian baru:
- `supabase db lint` dan Security Advisor di dashboard tanpa peringatan RLS (tabel tanpa RLS, fungsi `security definer` tanpa `search_path`).
- pgTAP dijalankan terhadap salinan lokal dari migrasi yang sama: semua lolos.
- Uji asap dua HP di jaringan seluler (bukan Wi-Fi yang sama): daftar → admin setujui → pasang barang (kuota gratis) → HP lain booking → chat → Diproses → Selesai.
- Akun tamu dan `pending` tidak bisa memanggil RPC tulis (cek dengan anon key lewat `curl`).
- Tidak ada `seed.sql` di cloud: `select count(*) from auth.users where email like '%@beekas.test'` = 0.
- Vault berisi semua secret yang dibutuhkan; `cron.job_run_details` menunjukkan run sukses untuk setiap job.
- Bucket privat (`verification-photos`, `payment-proofs`) tidak bisa dibaca dengan anon key.
- Gambar QRIS menampilkan nama CFO yang benar dan pembayaran uji Rp15.000 terkonfirmasi dan tercatat.
- Kebijakan Privasi memuat tujuan nomor HP (D-26), bukti bayar, dan aturan pembacaan chat oleh admin (K-24, D-38) sebelum dibuka.
- OTP pendaftaran dan lupa kata sandi terkirim ke email BINUS sungguhan lewat penyedia dari T0.
- APK di QR booth adalah build rilis yang ditandatangani kunci rilis, dan cadangan kuncinya tersimpan di luar repo.
- Backup (K-41, D-40): `pg_dump` manual sebelum Festival dan setiap hari selama Festival bila memakai paket Free.

## 9. Pengujian

**Tes yang baik** memeriksa perilaku yang terlihat dari luar: input → keputusan atau keadaan layar, bukan detail implementasi. Satu seam per lapisan:

- **Aturan domain:** unit test Dart murni di `test/domain/`, satu file per modul (contoh: `catalog_test.dart`, `access_test.dart`, `rejection_test.dart`). Waktu disuntikkan sebagai parameter, tidak memakai jam sistem.
- **Backend:** pgTAP di `supabase/tests/database/` per area (contoh: `listings.test.sql` dari #75). Wajib untuk setiap RPC dan policy: siapa boleh/tidak (anon, `pending`, `approved`, dibekukan, admin), transisi status, stok tidak negatif, batas donasi, kuota tidak negatif, dua admin berbeda untuk pembekuan, perebutan unit terakhir (dua transaksi). `pg_cron` diuji dengan memanggil fungsi SQL-nya langsung dengan waktu yang dimajukan.
- **Layar:** widget test di `test/screens/` dengan repository palsu di `test/support/` (contoh: `fake_catalog_repository.dart`, `catalog_test.dart`), mencakup memuat/kosong/error dan aturan akses per status.

Seam yang dipakai sudah ada: repository interface + implementasi palsu, dan RPC sebagai batas aplikasi–database. Tidak ada seam baru. **Mohon dikonfirmasi** bahwa seam ini sesuai harapan.

## 10. User stories

**Tamu dan member belum disetujui**
1. Sebagai tamu, saya ingin menggulir katalog tanpa batas, supaya bisa melihat semua barang meski jumlahnya banyak.
2. Sebagai tamu, saya ingin mencari berdasarkan nama barang, kategori, atau nama penjual, supaya cepat menemukan barang.
3. Sebagai tamu, saya ingin tombol chat, booking, dan beli mengarahkan saya ke Masuk/Daftar, supaya tahu langkah berikutnya.
4. Sebagai member `pending`, saya ingin diberi tahu bahwa saya bisa bertransaksi setelah disetujui, supaya tidak bingung kenapa tombolnya tidak jalan.
5. Sebagai pengunjung, saya ingin tidak melihat barang dari akun yang dibekukan atau tidak lagi disetujui, supaya katalog bisa dipercaya.

**Penjual**
6. Sebagai penjual baru, saya ingin memasang barang pertama tanpa membayar, supaya bisa mencoba BeeKas.
7. Sebagai penjual, saya ingin memilih Jual atau Donasi, supaya harga otomatis Rp0 untuk donasi.
8. Sebagai penjual, saya ingin memotret atau memilih 1–5 foto dari galeri, supaya barang terlihat jelas.
9. Sebagai penjual, saya ingin lokasi di foto saya dibuang otomatis, supaya alamat rumah saya tidak bocor.
10. Sebagai penjual, saya ingin lokasi barang terisi kampus saya, supaya tidak perlu mengetik ulang.
11. Sebagai penjual, saya ingin mengisi stok lebih dari 1, supaya tidak memasang barang yang sama berkali-kali.
12. Sebagai penjual, saya ingin listing langsung tayang setelah dipasang, supaya cepat laku.
13. Sebagai penjual, saya ingin melihat sisa kuota sebelum memasang, supaya tidak kaget.
14. Sebagai penjual, saya ingin isian tidak hilang saat kuota habis dan saya membeli paket, supaya tidak mengisi ulang.
15. Sebagai penjual, saya ingin membeli paket 3 listing lewat QRIS dan mengunggah bukti, supaya bisa terus berjualan.
16. Sebagai penjual, saya ingin melihat status pembayaran saya dan alasan bila ditolak, supaya bisa memperbaikinya.
17. Sebagai penjual, saya ingin menurunkan harga dan pembeli melihat harga coret, supaya barang menarik.
18. Sebagai penjual, saya ingin mengedit deskripsi, stok, dan detail lain, supaya listing tetap akurat.
19. Sebagai penjual, saya ingin melihat semua barang saya beserta status dan sisa hari tayang, supaya bisa mengelolanya.
20. Sebagai penjual, saya ingin menurunkan listing sendiri, supaya barang yang sudah laku di luar tidak dipesan.
21. Sebagai penjual, saya ingin tahu kenapa listing saya diturunkan admin, supaya tidak mengulanginya.
22. Sebagai penjual, saya ingin menerima atau menolak pesanan masuk, supaya hanya bertemu pembeli yang sudah sepakat.
23. Sebagai penjual, saya ingin mengisi waktu COD saat menerima pesanan, supaya kedua pihak punya patokan.
24. Sebagai penjual, saya ingin menyetujui perpanjangan booking sekali, supaya pembeli yang serius punya waktu tambahan.
25. Sebagai penjual, saya ingin pesanan selesai otomatis bila pembeli lupa mengonfirmasi, supaya catatannya tidak menggantung.
26. Sebagai penjual, saya ingin membayar Boost agar barang naik ke atas selama 3 hari, supaya lebih cepat terlihat.
27. Sebagai penjual, saya ingin membayar Featured agar barang tampil di banner Beranda selama 3 hari, supaya dilihat semua orang.
28. Sebagai donatur, saya ingin barang donasi diambil yang pertama memesan, supaya tidak perlu memilih penerima.

**Pembeli**
29. Sebagai pembeli, saya ingin menahan barang 24 jam tanpa membayar, supaya sempat bertanya ke penjual.
30. Sebagai pembeli, saya ingin melihat hitung mundur booking, supaya tahu kapan habis.
31. Sebagai pembeli, saya ingin meminta perpanjangan booking, supaya tidak kehilangan barang karena jadwal.
32. Sebagai pembeli, saya ingin Beli Sekarang dengan harga listing dan memilih Lokasi COD di kampus, supaya transaksi cepat.
33. Sebagai pembeli, saya ingin melihat pesanan saya per status (Menunggu, Diproses, Selesai, Dibatalkan), supaya tahu yang perlu saya lakukan.
34. Sebagai pembeli, saya ingin membatalkan pesanan dengan alasan tanpa sanksi, supaya tidak terpaksa membeli.
35. Sebagai pembeli, saya ingin menekan "Sudah diterima" setelah COD, supaya transaksi tercatat selesai.
36. Sebagai pembeli, saya ingin stok yang saya pesan tidak bisa diambil orang lain bersamaan, supaya tidak berebut unit terakhir.
37. Sebagai penerima donasi, saya ingin tahu bahwa saya hanya bisa punya 2 donasi berjalan, supaya donasi terbagi rata.
38. Sebagai pembeli, saya ingin menyimpan barang ke Favorit secara pribadi, supaya bisa kembali nanti.

**Chat**
39. Sebagai pembeli, saya ingin memulai chat dari halaman barang dan melihat kartu barangnya, supaya penjual tahu barang yang ditanya.
40. Sebagai member, saya ingin satu percakapan per lawan bicara, supaya riwayat tidak tercecer.
41. Sebagai member, saya ingin pesan baru muncul tanpa memuat ulang, supaya bisa bernegosiasi lancar.
42. Sebagai member, saya ingin diperingatkan saat membagikan nomor HP atau akun media sosial, supaya terhindar dari penipuan di luar aplikasi.
43. Sebagai member, saya ingin membaca pengumuman dari Admin BeeKas di daftar chat, supaya tahu info layanan.
44. Sebagai member, saya ingin nomor HP saya tidak pernah terlihat oleh lawan chat, supaya privasi terjaga (D-26).

**Lapor dan moderasi**
45. Sebagai member, saya ingin melaporkan listing barang terlarang, supaya katalog tetap aman.
46. Sebagai member, saya ingin melaporkan pengguna dari ruang chat, supaya admin bisa menindak.
47. Sebagai admin, saya ingin melihat laporan dikelompokkan per objek dengan jumlah pelapor, supaya bisa memprioritaskan.
48. Sebagai admin, saya ingin menurunkan listing dengan alasan, supaya penjual tahu kesalahannya.
49. Sebagai admin, saya ingin mengembalikan kuota bila penurunan adalah kesalahan admin, sesuai aturan refund.
50. Sebagai admin, saya ingin mengusulkan pembekuan akun dengan alasan, supaya admin lain memeriksanya.
51. Sebagai admin, saya ingin menyetujui atau menolak usulan pembekuan dari admin lain, supaya tidak ada satu orang yang membekukan sendirian.
52. Sebagai admin, saya ingin sistem menolak bila saya menyetujui usulan saya sendiri, supaya aturan dua admin tidak bisa dilewati.
53. Sebagai member yang dibekukan, saya ingin melihat bahwa akun saya dibekukan dan cara banding lewat Bantuan, supaya tahu langkah berikutnya.
54. Sebagai admin, saya ingin mengirim pengumuman ke semua member, supaya informasi Festival tersampaikan.

**Pembayaran (admin)**
55. Sebagai admin, saya ingin daftar pembayaran menunggu urut dari yang terlama, supaya janji 1×24 jam terpenuhi.
56. Sebagai admin, saya ingin melihat bukti bayar dan mengisi nominal yang diterima, supaya catatan keuangan akurat.
57. Sebagai admin, saya ingin bukti bayar terhapus setelah saya memutuskan, supaya data pribadi di bukti tidak menumpuk.
58. Sebagai CFO, saya ingin setiap konfirmasi tercatat dengan nama admin dan nominal, supaya bisa mencocokkan mutasi QRIS.

**Cloud dan operasional**
59. Sebagai anggota tim, saya ingin akun admin cloud sendiri, supaya catatan "dikonfirmasi oleh" akurat (D-21).
60. Sebagai pemilik project, saya ingin checklist sebelum membuka aplikasi, supaya tidak ada secret, seed, atau RLS yang terlewat.
61. Sebagai pengunjung Festival, saya ingin memasang APK dan langsung memakai aplikasi lewat data seluler, supaya tidak bergantung pada laptop tim.

## 11. Urutan tiket dan ukuran

Ukuran: **S** ≤ 1 hari, **M** 2–3 hari, **L** 4–5 hari (satu orang + agent). Sisa waktu dari 22 Oktober sampai 22 November ≈ 4,5 minggu. Setiap tiket menyertakan migrasi, pgTAP, aturan domain + tes, layar + widget test.

| # | Tiket | Ukuran | Bergantung pada |
|---|---|---|---|
| T0 | Pilih dan pasang penyedia email: opsi + batas paket gratis dari dokumentasi resmi, SMTP Auth dan API untuk `send-decision-emails` di cloud (K-38) | S | — (selesai sebelum T12) |
| T1 | Katalog: hanya penjual `approved` + kolom pembekuan dan `is_frozen` (tanpa layar pembekuan) (#76) | S | — |
| T2 | Katalog: paginasi dan pencarian di server (#77, K-02) | M | T1 |
| T3 | Kuota: saldo, 1 gratis, `create_listing` memotong kuota (K-08) | S | T1 |
| T4 | Pasang barang K5–K6 + unggah foto + hapus metadata (K-04, K-05) | L | T3 |
| T5 | Barang Saya K7: edit, turunkan sendiri, kedaluwarsa 60 hari (K-06, K-07) | M | T4 |
| T6 | Pembayaran QRIS K8 + admin konfirmasi K18 + hapus bukti (K-09–K-11) | L | T3 |
| T7 | Pesanan: Booking 24 Jam + Beli Sekarang + stok + batas donasi + pg_cron (K9–K13, K-12–K-19) | L | T4 |
| T8 | Chat teks K14–K15 + Realtime + peringatan kontak + Admin BeeKas (#13, K-20, K-21) | L | T4 |
| T9 | Lapor K16 + admin laporan & turunkan listing K19 (K-22–K-24) | M | T4, T8 |
| T10 | Pembekuan dua admin K20 (K-25, K-26) | M | T1, T7 |
| T11 | Profil versi Festival K17 + Favorit K4 (K-28) | S | T5, T7 |
| T11b | Badge jumlah di tab Pesanan Saya dan Chat (K-01) | S | T7, T8 |
| T12 | Pindah ke cloud: urutan migrasi, Vault, function, admin per orang, kunci signing rilis + penyimpanan di luar repo, APK untuk QR booth, checklist (bagian 8) | M | T0 (eksekusi butuh persetujuan) |
| — | **Titik potong 1.** T0–T12 (termasuk T11b) = fitur inti Festival. Bila waktu habis, berhenti di sini. | | |
| T13 | Boost (K-29–K-31, K-34–K-36) | M | T6, T2 |
| T14 | Featured (K-29, K-32–K-35) | M | T6, T13 |
| T15 | Daftar notifikasi in-app `daftar-10.png` (K-01, bila sempat) | M | T7, T8 |

Perkiraan: T1–T12 ≈ 26–33 hari kerja satu orang; perlu dikerjakan paralel (mis. T6 dan T8 bersamaan setelah T4) agar muat. Target: T1–T12 selesai 15 November, satu minggu untuk uji di cloud, perbaikan, dan T13–T14 bila sempat. T12 dimulai paling lambat 10 November agar uji asap di cloud punya waktu; T0 selesai sebelumnya.

**Titik potong 2 (8 November).** Bila pada 8 November pekerjaan masih tertinggal dari target: T10 diganti tindakan manual SQL oleh CTO (pembekuan diterapkan langsung di database cloud, dengan persetujuan admin kedua dicatat di luar aplikasi), dan T13–T14 dilepas dari lingkup Festival. Kolom pembekuan dan `is_frozen` dari T1 tetap ada, sehingga katalog dan RPC tetap menghormati pembekuan manual.

## 12. Di luar lingkup

Ulasan/rating, follow, notifikasi push, blokir pengguna, profil penjual publik (K-03), Edit Profil dan BINUSIAN, layar Notifikasi (K-01; T15 bila sempat), cari akun dari nomor HP (#73), refund otomatis, iOS, pengiriman, pembayaran barang di aplikasi, listing AI, pencarian/saringan lanjutan (harga, kondisi, kampus).

## 13. Keputusan K-01–K-41 (D-34–D-40)

| Kode | Pertanyaan | Keputusan |
|---|---|---|
| K-01 | Daftar notifikasi in-app dan email penting masuk Festival? | Badge Pesanan Saya dan Chat masuk Festival; daftar lengkap bila sempat; email setelah penyedia dipilih (D-37) |
| K-02 | Pencarian label kategori EN/ID | Aplikasi memetakan label ke kode kategori |
| K-03 | Halaman profil penjual publik untuk Festival | Belum |
| K-04 | Batas deskripsi 500 atau 2.000 | 500 (desain) |
| K-05 | Format foto listing | JPEG/PNG/WebP diterima, dikonversi ke JPEG tanpa metadata lokasi (D-34) |
| K-06 | Field yang dikunci setelah tayang | Nama, kategori, jual/donasi, foto |
| K-07 | Tayang ulang listing kedaluwarsa | Boleh, gratis, tidak memotong kuota (D-34) |
| K-08 | Arti "1 listing gratis" | Saldo awal 1 saat pertama `approved` |
| K-09 | Letak gambar QRIS | Storage publik, bisa diganti tanpa rilis |
| K-10 | Bukti yang ditolak/tak diputuskan | Dihapus saat ditolak; maks. 30 hari |
| K-11 | Nominal bayar tidak cocok | **Menunggu persetujuan CFO** (usulan: ditolak, dikembalikan manual oleh CFO) |
| K-12 | 24 jam booking setelah Diproses | Berhenti; diganti waktu COD |
| K-13 | Lama perpanjangan booking | +24 jam |
| K-14 | Booking → beli | Diterima penjual = transaksi berjalan |
| K-15 | Batas konfirmasi Beli Sekarang | 24 jam, batal otomatis |
| K-16 | Letak daftar pesanan penjual | Tab Penjualan di Pesanan Saya |
| K-17 | Siapa/kapan mengisi waktu COD | Penjual saat Terima; bisa diubah kedua pihak |
| K-18 | Format alasan batal | Kode tetap + catatan |
| K-19 | Penjual donasi menolak pemesan pertama | Boleh, dengan alasan |
| K-20 | Pola deteksi kontak dan teks peringatan | Pola dengan batas kata; tes memuat contoh negatif (D-37) |
| K-21 | Batas panjang pesan chat | 1.000 karakter |
| K-22 | Daftar alasan lapor | Lihat 5.9 |
| K-23 | Pesanan pada listing yang diturunkan | Batal otomatis |
| K-24 | Admin membaca chat | Hanya percakapan yang dilaporkan, selama laporan terbuka; wajib di Kebijakan Privasi (D-38) |
| K-25 | Mencairkan pembekuan butuh dua admin | Ya |
| K-26 | Akibat pembekuan | Lihat 5.9 |
| K-27 | Promo/opt-in untuk Festival | Tidak ada promo |
| K-28 | Menu Profil "Metode Pembayaran (COD)" | Hapus |
| K-29 | Definisi Boost dan Featured | Lihat 5.11 |
| K-30 | Boost memengaruhi hasil pencarian | Tidak |
| K-31 | Label "Dipromosikan" | Ya |
| K-32 | Slot Featured bersamaan | Maks. 5 |
| K-33 | Boost/Featured untuk donasi | Boleh |
| K-34 | Promosi saat listing tidak tayang | Berhenti tanpa refund |
| K-35 | Perpanjangan promosi | Ya, ditambahkan di ujung |
| K-36 | Urutan paginasi dengan Boost | Boost dulu, cursor ikut menyimpan |
| K-37 | Region dan paket Supabase cloud | Singapura; paket diputuskan CFO; bila Free, risiko pause + backup manual wajib (D-40) |
| K-38 | Penyedia email (HTTP API) | Penghambat Festival; tiket T0 (D-40) |
| K-39 | Cara memberi peran admin di cloud | SQL manual per orang |
| K-40 | Distribusi APK Festival | APK langsung lewat QR di booth; kunci signing di luar repo (D-40) |
| K-41 | Backup selama Festival | `pg_dump` manual harian bila Free |

## 14. Catatan

- Koreksi desain yang perlu dikerjakan desainer (D-22.3 dan PRD ini): Checkout (Lokasi COD, hapus Biaya Lainnya, typo "Delicery"), Pesanan Saya (chip dan badge status COD), Profil (hapus Alamat Saya, hapus @username).
- Teks Onboarding-4 yang menyebut WhatsApp masih perlu diubah (D-22.2); masuk tiket T8.
- Layar tanpa desain di bagian 5 dibangun dari komponen yang ada; frame bisa menyusul tanpa mengubah alur.
- Setelah K-xx diputuskan, keputusan masuk `docs/decisions.md` sebagai D-34 dst. (dengan persetujuan), lalu PRD ini diperbarui dan /to-tickets dijalankan.
