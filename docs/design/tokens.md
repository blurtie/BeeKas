# Token desain BeeKas (dari Figma halaman "BeeKas")

Sumber: PNG ekspor 2x frame Masuk (384:9135) dan Daftar (405:9246, plus frame Daftar lain) di `docs/design/`, diekspor 6 Oktober 2026. Nilai warna diambil langsung dari piksel PNG (fill rata). Ukuran dan radius diukur dari piksel dan dibulatkan; selisih ±1 dp mungkin. Tidak ada panggilan Figma MCP.

Nama di kolom "Color style" adalah dugaan pasangan dengan Color styles yang ada di file Figma (nama terlihat, hex tidak). Cocokkan bila sempat.

## Warna dari desain

| Token | Hex | Dipakai di desain | Color style (dugaan) |
|---|---|---|---|
| `brandPrimary` | `#FEAF1A` | isi tombol utama, checkbox, titik stepper aktif, garis banner | Button |
| `brandYellowText` | `#FFB81C` | tautan "Lupa password?", "Syarat & Ketentuan", "Kebijakan Privasi" | Yellow Text |
| `brandOrange` | `#FE9402` | kata "Bee" di logo/judul | Logo "Bee" / Orange Text |
| `logoKas` | `#000000` | kata "Kas" di logo/judul | Logo "Kas" |
| `textHeadingNavy` | `#213D57` | judul Masuk dan Onboarding | Bold Text |
| `textHeadingDark` | `#292929` | judul layar Daftar dan verifikasi | – |
| `textBody` | `#475F76` | teks isi Masuk, label "Ingat Saya" | Text |
| `textLabel` / `icon` | `#5C5C5C` | label isian Daftar, ikon, teks tombol SSO, panah kembali | Icon |
| `textMuted` | `#8C8C8C` | teks persetujuan, "atau", isi banner | Gray Text |
| `textSubtle` | `#A3A3A3` | subjudul layar Daftar | – |
| `placeholder` | `#DDDDDD` | placeholder isian | Placeholder |
| `border` | `#EBEBEB` | garis isian, garis pemisah, garis tombol SSO | – |
| `surface` | `#FFFFFF` | latar layar | – |
| `warningSurface` | `#FEF7E4` | isi banner peringatan | – |
| `stepperInactive` | `#FFEAC4` | garis stepper tidak aktif | – |
| `infoSurface` | `#DFECFF` | kotak tips (Verifikasi Sedang Diproses) | – |
| `success` | `#269447` | centang di Konfirmasi Foto | – |

Palet oranye 50–950 (frame Color Pallete, Page 1): 50 `#FFFAEA`, 100 `#FFF1C5`, 200 `#FFE386`, 300 `#FFCE46`, 400 `#FFB81C`, 500 `#FE9402`, 600 `#E16D00`, 700 `#BB4902`, 800 `#973809`, 900 `#7C2E0B`, 950 `#481500`.

## Penyesuaian wajib karena kontras (aturan CLAUDE.md: teks ≥ 4.5:1)

| Di desain | Kontras | Dipakai di kode | Kontras baru |
|---|---|---|---|
| Teks putih di tombol `#FEAF1A` | 1.85 | teks tombol `#213D57` | 6.08 |
| Tautan `#FFB81C` di putih | 1.73 | tautan `#BB4902` (palet 700) | 5.16 |
| Teks `#8C8C8C` di putih | 3.36 | `#5C5C5C` | 6.69 |
| Teks `#8C8C8C` di banner `#FEF7E4` | 3.14 | `#5C5C5C` | 6.25 |
| Subjudul `#A3A3A3` | 2.52 | `#5C5C5C` | 6.69 |
| Placeholder `#DDDDDD` | 1.36 | `#767676` | ≈ 4.5 |

Warna aslinya tetap disimpan sebagai token supaya mudah dikembalikan bila tim memutuskan lain. Penyimpangan ini dicatat di PR.

Tidak wajib (aturan CLAUDE.md hanya untuk teks): garis isian `#EBEBEB` hanya 1.19:1. WCAG 1.4.11 meminta ≥ 3:1 untuk batas komponen; ikuti desain dulu, catat sebagai risiko.

## Yang belum konsisten di desain (perlu keputusan)

- Warna judul: Masuk dan Onboarding memakai `#213D57` (navy), layar Daftar memakai `#292929` (hampir hitam). Pakai satu token `textHeading`; default `#213D57` sampai desainer memutuskan.
- Margin kiri-kanan: Masuk 35 dp, Daftar 38 dp. Pakai satu nilai; default 36 dp.

## Tipografi

Font: **Poppins** (dicocokkan dengan render: judul Masuk = Poppins Bold 36). File `.ttf` (OFL) di `assets/fonts/`.

| Gaya | Ukuran (dp) | Weight | Catatan |
|---|---|---|---|
| Judul layar | 36 | Bold (700) | tinggi baris ≈ 43 (1.2) |
| Teks tombol | 15–16 | Bold (700) | |
| Teks isi / subjudul | 12–13 | Regular (400) | tinggi baris ≈ 20 |
| Label isian | 12 | Medium (500) | |
| Placeholder / isi kolom | 12 | Regular (400) | |
| Teks kecil (persetujuan) | 11–12 | Regular (400) | |

Ukuran diukur dari tinggi huruf kapital dan bisa meleset ±1. Ukuran 12 untuk isi dan label cukup kecil untuk HP; pertimbangkan 14 (Material default) dan catat sebagai penyimpangan.

## Bentuk dan ukuran

| Elemen | Nilai |
|---|---|
| Tombol utama | tinggi 41 di desain (naikkan ke ≥ 48 untuk area sentuh), radius penuh (pill) |
| Kolom isian | tinggi 50, radius 8, garis 1 dp `border`, isi putih |
| Kolom isian di Masuk | kotak ikon 54 dp di kiri, dipisah garis vertikal `border` |
| Tombol sekunder (SSO) | tinggi 50, radius 8, garis 1 dp `border`, teks `textLabel` |
| Banner peringatan | radius 10, garis 1–2 dp `brandPrimary`, isi `warningSurface`, ikon `brandPrimary` |
| Checkbox | 15 dp, radius 2, isi `brandPrimary` (area sentuh tetap ≥ 48) |
| Stepper | 3 titik; aktif isi `brandPrimary`, tidak aktif garis `stepperInactive` |

## File PNG di `docs/design/` (ekspor 2x, 804×1748)

| File | Frame |
|---|---|
| `splash.png` | Onboarding / splash 372:305 |
| `onboarding-1.png` … `onboarding-4.png` | slide 384:8943, 384:8978, 384:9061, 384:9095 |
| `masuk.png` | Masuk 384:9135 |
| `daftar-data-diri.png` | Daftar, isi data diri 405:9246 |
| `verifikasi-kartu.png` | Verifikasi identitas 405:9442 |
| `konfirmasi-kartu.png` | Konfirmasi foto ID card 416:411 |
| `verifikasi-wajah.png` | Verifikasi wajah 416:507 |
| `verifikasi-diproses.png` | Verifikasi sedang diproses 459:184 |
| `home.png` | Home 462:207 (di luar lingkup login, hanya rujukan) |
