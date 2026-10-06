# PRD BeeKas (Flutter) — Onboarding, Daftar, dan Masuk

Versi 0.1, 5 Oktober 2026. Sumber: `notes/notulen-login.md`, frame Figma halaman "BeeKas", dan sesi grilling CEO–CTO. Keputusan resmi ada di `docs/decisions.md`. Istilah ada di `CONTEXT.md`.

## 1. Masalah

BeeKas adalah marketplace jual dan donasi barang bekas untuk komunitas BINUS. Kepercayaan antarpengguna bergantung pada kepastian bahwa lawan transaksi benar warga BINUS dan memakai akunnya sendiri. Bagian ini mengatur cara orang mengenal aplikasi, mendaftar, membuktikan identitas, dan masuk.

## 2. Pengguna

- **Tamu:** belum punya akun, misalnya pengunjung BINUS Festival.
- **Member:** pemilik email BINUS aktif, bertipe mahasiswa, dosen, atau staf (D-01, D-15). Tidak ada jalur alumni; alumni dengan email `@binus.ac.id` yang masih aktif terdaftar sebagai mahasiswa.
- **Admin:** anggota tim yang memeriksa berkas verifikasi (D-09).

## 3. Lingkup

**Termasuk:** splash dan onboarding, Masuk, Daftar, verifikasi email, buat kata sandi, verifikasi identitas, status menunggu, penolakan dan kirim ulang, lupa kata sandi, layar admin verifikasi, ganti bahasa, serta layar statis Kebijakan Privasi dan Syarat & Ketentuan.

**Tidak termasuk:**
- Login SSO Microsoft BINUS (D-05).
- Kartu digital (D-14).
- Verifikasi nomor HP.
- Pencocokan wajah otomatis.
- Fitur katalog itu sendiri. Bagian ini hanya mengatur siapa yang boleh mengaksesnya.
- Jurusan dan NIM tidak dikumpulkan. Angkatan (BINUSIAN) tidak dikumpulkan saat pendaftaran atau verifikasi, tetapi member boleh mengisinya sendiri di Edit Profil dari daftar label BINUSIAN (misalnya B28). Isian ini opsional dan tidak diverifikasi. Verifikasi hanya memastikan pengguna adalah Binusian.

## 4. Alur

```
Pertama kali buka: Splash → Onboarding (4 slide, bisa Lewati) → Masuk
Buka berikutnya:   Splash → (sesi aktif? → sesuai status) / Masuk

Masuk ──"Daftar"──► Daftar (data diri) → OTP email → Buat kata sandi
        → Persetujuan data → Foto kartu → Konfirmasi foto kartu → Selfie
        → Verifikasi Sedang Diproses (pending)

Masuk ──"Lewati / Lihat katalog"──► Katalog sebagai tamu
Masuk ──"Lupa kata sandi?"──► Email BINUS → OTP → Sandi baru → Masuk
```

Setelah masuk, layar yang dibuka bergantung pada status (D-06):
- `incomplete`: lanjut ke langkah verifikasi berikutnya.
- `pending`: layar Verifikasi Sedang Diproses, dengan tombol ke katalog.
- `rejected`: layar Ditolak (berisi alasan) dengan tombol kirim ulang.
- `approved`: beranda.
- admin: beranda + menu Verifikasi.

Stepper di layar Daftar (3 titik): ① Data diri, termasuk OTP dan kata sandi; ② Kartu, termasuk persetujuan dan konfirmasi; ③ Wajah.

## 5. Kebutuhan per layar

Kolom "Desain" berisi frame Figma, atau "Tanpa desain". "Tanpa desain" berarti layar dibangun tanpa desain, mengikuti aturan Desain dan UI di CLAUDE.md, dan ditandai "belum ada desain" di PR.

| # | Layar | Desain |
|---|---|---|
| L1 | Splash | 372:305 |
| L2 | Onboarding (4 slide) | 384:8943, 384:8978, 384:9061, 384:9095 |
| L3 | Masuk | 384:9135 (tanpa tombol SSO) |
| L4 | Daftar: isi data diri | 405:9246 (ditambah pilihan Dosen/Staf untuk `@binus.edu`) |
| L5 | Verifikasi email (OTP) | Tanpa desain |
| L6 | Buat kata sandi | Tanpa desain |
| L7 | Persetujuan data | Tanpa desain |
| L8 | Verifikasi identitas (foto kartu) | 405:9442 |
| L9 | Konfirmasi foto kartu | 416:411 |
| L10 | Verifikasi wajah (selfie) | 416:507 |
| L11 | Verifikasi Sedang Diproses | 459:184 |
| L12 | Verifikasi ditolak | Tanpa desain |
| L13 | Lupa kata sandi (email → OTP → sandi baru) | Tanpa desain |
| L14 | Admin: daftar pendaftar | Tanpa desain |
| L15 | Admin: detail berkas + setujui/tolak | Tanpa desain |
| L16 | Kebijakan Privasi / Syarat & Ketentuan | Tanpa desain |

### L1–L2 Splash dan onboarding
- Onboarding hanya tampil saat aplikasi pertama kali dibuka. Statusnya disimpan di perangkat.
- Ada tombol "Lewati" di setiap slide. Slide terakhir berisi tombol Masuk dan Daftar.
- Tombol EN | ID tampil di pojok kanan atas.

### L3 Masuk
- Isian: "Email atau nomor HP" dan "Kata sandi" (bisa ditampilkan atau disembunyikan).
- "Ingat saya" tercentang secara default (D-04).
- Tautan "Lupa kata sandi?" dan tombol Masuk. Tombol "Masuk dengan SSO" dan pemisah "atau" di frame tidak dibangun (D-05).
- Tautan Daftar dan tautan "Lihat katalog sebagai tamu". Tautan tamu belum ada di desain.
- Teks persetujuan dengan tautan ke Syarat & Ketentuan dan Kebijakan Privasi.
- Error ditampilkan di bawah isian:
  - Akun tidak ditemukan atau sandi salah memakai satu pesan yang sama, supaya tidak membocorkan apakah sebuah email terdaftar.
  - Bila tidak ada koneksi ke server, tampil pesan koneksi.

### L4 Daftar
- Isian:
  - Nama lengkap.
  - Email BINUS: `@binus.ac.id` atau `@binus.edu`, tidak peka huruf besar-kecil.
  - Nomor HP: diterima `08…`, `628…`, atau `+628…`, lalu dinormalisasi ke `+628…` dan disimpan setelah OTP terverifikasi (L5).
  - Tipe akun, diturunkan dari domain email (D-15): `@binus.ac.id` otomatis Mahasiswa tanpa pilihan; `@binus.edu` menampilkan pilihan wajib Dosen / Staf setelah email valid diketik.
  - Kampus asal: dropdown D-12.
- Banner "Pastikan data sudah benar dan sesuai identitas BINUS."
- Validasi saat menekan Lanjut:
  - Semua isian wajib.
  - Email harus berdomain BINUS.
  - Nomor HP harus valid. Nomor yang sudah dipakai ditolak setelah OTP terverifikasi, dengan pesan 'Nomor HP ini sudah terdaftar' dan kesempatan mengganti nomor.
  - Email yang sudah terdaftar tidak diperiksa saat Lanjut, untuk mencegah enumerasi email (D-07); pesan "Email ini sudah terdaftar" dengan tautan Masuk ditampilkan setelah OTP terverifikasi.

### L5 Verifikasi email
- Kode 6 digit dikirim ke email BINUS.
- Tombol kirim ulang aktif setelah 60 detik.
- Kode berlaku sesuai bawaan Supabase. Kode salah atau kedaluwarsa menampilkan pesan dan pilihan kirim ulang.
- Setelah kode benar, nomor HP dari L4 disimpan. Bila nomor sudah dipakai, pengguna diminta memasukkan nomor lain sebelum lanjut.
- Akun dibuat setelah kode benar, dengan status `incomplete` setelah L6.

### L6 Buat kata sandi
- Isian kata sandi dan konfirmasinya.
- Aturan UI:
  - Syarat: minimal 8 karakter, sedikitnya satu huruf dan satu angka (D-03), ditampilkan sebagai checklist yang terpenuhi sambil mengetik.
  - Teks bantuan di bawah isian: "Jangan gunakan kata sandi Binusmaya atau akun lain. Buat kata sandi khusus untuk BeeKas."
  - Teks bantuan ini hanya peringatan. Aplikasi tidak bisa memeriksa apakah kata sandi sama dengan kata sandi Binusmaya.

### L7 Persetujuan data
- Menjelaskan (D-07):
  - Data yang diambil: foto kartu dan foto wajah.
  - Tujuannya: memastikan pemilik akun adalah warga BINUS.
  - Yang melihat: hanya admin BeeKas.
  - Masa simpan: dihapus paling lambat 30 hari setelah diperiksa.
- Tautan ke Kebijakan Privasi.
- Checkbox wajib. Tombol Lanjut nonaktif sampai checkbox dicentang.
- Waktu persetujuan dan versi teks persetujuan disimpan sebagai bukti (D-20).

### L8–L9 Foto kartu dan konfirmasi
- Jenis kartu yang diminta mengikuti tipe akun (D-15).
- Panduan: cahaya cukup, foto tidak buram, nama dan data terbaca.
- Foto diambil dengan kamera belakang saja, tanpa pilihan galeri (D-02).
- Layar konfirmasi menampilkan pratinjau dengan tombol "Ulangi" dan "Gunakan foto".

### L10 Verifikasi wajah
- Selfie diambil dengan kamera depan saja.
- Tips di layar (tiga tips dari frame 416:507 diperjelas, ditambah tips keempat):
  1. "Gunakan pencahayaan yang cukup" (tetap).
  2. "Pastikan wajah terlihat jelas dan tidak tertutup" diperjelas: hijab atau kerudung boleh dipakai selama wajah terlihat jelas.
  3. "Jangan menggunakan kacamata / topi" diperluas menjadi: jangan memakai kacamata, topi, masker, atau penutup wajah lain.
  4. Baru: "Gunakan pakaian yang sopan".
- Pratinjau dengan tombol Ulangi atau Kirim.
- Kirim mengunggah kedua foto ke storage privat, lalu status berubah menjadi `pending`.
- Upload gagal: tampil pesan error, foto tetap ada di layar, dan pengguna bisa mencoba lagi.

### L11 Verifikasi Sedang Diproses
- Teks sesuai frame: tim memeriksa dalam 1×24 jam, dan notifikasi dikirim setelah selesai.
- Tombol "Bantuan" membuka aplikasi email (mailto) ke alamat tim, dengan subjek "Bantuan BeeKas" dan isi awal berisi nama, email akun, dan status akun (D-14). Bila tidak ada aplikasi email, tampil alamat email dengan tombol salin. Alamatnya konstanta konfigurasi di `lib/config/`, sementara `beekas2026@gmail.com`.
- Tombol "Lihat katalog" mengarah ke katalog dengan akses terbatas (D-06).
- Tombol Kembali pada frame diganti dengan "Lihat katalog" dan "Keluar".

### L12 Verifikasi ditolak
- Menampilkan alasan penolakan dari admin.
- Tombol "Kirim ulang" kembali ke L8. Data diri tidak perlu diisi ulang (D-08).
- Ada juga tombol Bantuan dan Lihat katalog.

### L13 Lupa kata sandi
- Alurnya: masukkan email BINUS, lalu OTP, lalu sandi baru dengan aturan L6.
- Pesan setelah email dimasukkan selalu sama, terdaftar atau tidak.

### L14–L15 Admin
- Daftar pendaftar `pending`, diurutkan dari yang paling lama menunggu, dengan tanda bila sudah lewat 24 jam.
- Detail berkas menampilkan:
  - data diri;
  - tipe akun dan jenis kartu;
  - nomor HP, untuk diperiksa admin karena nomor tidak diverifikasi (D-04);
  - foto kartu dan selfie berdampingan.
- Tombol Setujui, atau Tolak dengan alasan wajib.
- Setelah keputusan, email dikirim ke pendaftar dan statusnya berubah.
- Admin bisa melepas nomor HP dari sebuah akun, bila pemilik asli nomor itu menghubungi Bantuan karena tidak bisa mendaftar (D-04). Akun yang nomornya dilepas tidak bisa masuk dengan nomor HP sampai mengisi nomor baru.

### L16 Layar teks statis
- Kebijakan Privasi dan Syarat & Ketentuan, dalam dua bahasa.
- Prototype memakai teks sementara bertanda "[DRAF — menunggu tim]".

### Semua layar
- Area sentuh ≥ 48 dp dan kontras teks ≥ 4.5:1.
- Setiap layar punya keadaan memuat, error, dan kosong.
- Semua teks diambil dari `copy.dart` dalam bahasa EN dan ID (D-11).

## 6. Aturan domain (`lib/domain/`, Dart murni, dengan tes)

1. **Email BINUS:** domain `binus.ac.id` atau `binus.edu`, tidak peka huruf besar-kecil, spasi di awal dan akhir dibuang.
2. **Nomor HP:** normalisasi ke `+628` diikuti 8–11 digit (10–13 digit termasuk 08 di depan).
3. **Sign-in identifier:** bila mengandung `@`, diperlakukan sebagai email; selain itu nomor HP.
4. **Kata sandi:** minimal 8 karakter, ada huruf dan angka, sama dengan konfirmasinya.
5. **Tipe akun dari domain** (D-15): `binus.ac.id` → mahasiswa; `binus.edu` → dosen atau staf, wajib dipilih. Tipe akun menentukan jenis kartu.
6. **Daftar kampus:** kode dan label (D-12).
7. **Transisi status:** incomplete → pending; pending → approved | rejected; rejected → pending. Transisi lain ditolak.
8. **Aturan akses** per status dan peran (D-06), misalnya `canContactSeller` dan `canCreateListing` hanya untuk approved; `canReviewVerifications` hanya untuk admin.
9. **Penolakan wajib menyertakan alasan** yang tidak kosong.

Aturan 1, 2, 4, 7, 8, dan 9 ditegakkan juga di backend (constraint, RLS, atau fungsi Postgres).

## 7. Lingkungan dan simulasi (D-10)

| Bagian | Di lingkungan lokal |
|---|---|
| Auth, database, storage | Supabase lokal (Docker) di laptop |
| Email OTP dan email keputusan | Asli, ditangkap mail server lokal Supabase |
| Pemeriksaan admin | Asli, lewat L14–L15 di HP kedua |
| Verifikasi wajah | Manual oleh admin, tidak ada otomasi |
| Penghapusan foto setelah 30 hari | Fungsi terjadwal di backend; di lokal diuji dengan menjalankannya manual |
| Kebijakan Privasi dan S&K | Teks draf |

## 8. Kriteria selesai

- Dua HP di jaringan yang sama:
  - HP 1 bisa mendaftar sampai `pending`.
  - HP 2 (admin) bisa menyetujui.
  - HP 1 lalu menerima email di mail server lokal dan bisa memakai semua fitur.
- Jalur penolakan: menolak dengan alasan, alasan terlihat di HP 1, kirim ulang berhasil, dan status kembali `pending`.
- Tamu, `incomplete`, `pending`, dan `rejected` tidak bisa menghubungi penjual atau memasang barang, baik di aplikasi maupun langsung lewat API (RLS).
  - Uji RLS untuk menghubungi penjual dan memasang barang ditunda ke PRD katalog, karena tabel listing belum ada. Di bagian ini aturannya diuji di `lib/domain/` saja, dan tombol "Lihat katalog" serta beranda `approved` mengarah ke layar placeholder.
- Foto kartu dan selfie tidak bisa dibaca oleh akun non-admin.
- Semua aturan di bagian 6 punya unit test di `test/domain/`.
- Bahasa bisa diganti EN/ID di L1–L3 dan pilihan diingat.

## 9. Keputusan terbuka (untuk /to-questionnaire)

1. Akses lihat katalog untuk tamu dan akun yang belum disetujui (D-06), karena mengubah notulen. Default: boleh. **Terjawab:** Boleh (D-06).
2. Masa simpan foto kartu dan selfie (D-07). Default: 30 hari setelah diperiksa. **Terjawab:** 30 hari setelah diperiksa (D-07).
3. Siapa saja admin verifikasi, dan apakah SLA 1×24 jam berlaku di akhir pekan. **Terjawab:** Kelima anggota tim dengan akun admin masing-masing; SLA berlaku juga di akhir pekan dan hari libur (D-21).
4. Apakah alumni perlu didukung (D-15). Saat ini tidak ada jalur alumni. **Terjawab:** Tidak; alumni dengan email aktif mendaftar sebagai mahasiswa (D-15).
5. Isi Kebijakan Privasi dan Syarat & Ketentuan, termasuk penanggung jawab data pribadi. **Terjawab:** Penanggung jawab CTO; draf ditulis CTO dan ditinjau tim (D-21).
6. Konfirmasi penghapusan kartu digital sementara (D-14), karena notulen menyebutnya. **Terjawab:** Dihapus, disimpan sebagai ide (D-14).

## 10. Dicatat untuk sesi berikutnya (di luar lingkup login)

- Tab "Chat" di Home bertentangan dengan keputusan lama bahwa komunikasi lewat WhatsApp (D-04 versi web).
- Ikon favorit dan notifikasi di header Home.
- Kartu digital member: ide terbuka, belum punya fungsi (D-14).
- Sesi katalog: nomor WhatsApp penjual hanya terlihat oleh member `approved` (D-06). Pertimbangkan pengingat bagi penjual bahwa nomornya akan terlihat oleh pembeli.
- Sesi profil, angkatan (BINUSIAN): daftar label sebaiknya diturunkan dari tahun berjalan, tidak ditulis tetap. Nilainya ditampilkan sebagai "diisi sendiri".
- Catatan implementasi, masuk dengan nomor HP: butuh fungsi server yang mencari email dari nomor HP. Fungsi itu tidak boleh membocorkan apakah sebuah nomor terdaftar; nomor tidak dikenal dan sandi salah menghasilkan respons yang sama.
