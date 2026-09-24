## Ringkasan

<!-- Apa yang berubah dan kenapa. Satu atau dua kalimat. -->

## Acuan

- PRD: <!-- misalnya F1.1, F2.3 -->
- Keputusan: <!-- misalnya D-10 -->
- Roadmap: <!-- fase dan item -->

## Cara menguji

<!-- Langkah yang bisa diulang reviewer, termasuk akun atau data uji yang dipakai. -->

## Checklist

- [ ] CI hijau (lint, typecheck, test, build)
- [ ] Tes Vitest ditambah untuk logika baru di `src/lib/domain/`
- [ ] Tidak ada keputusan `[KEPUTUSAN]` yang diputuskan diam-diam
- [ ] Teks antarmuka hanya di `src/config/copy.ts`, warna hanya lewat token
- [ ] Tidak ada kredensial di sisi klien
- [ ] Migrasi basis data: tidak ada / ada dan belum dijalankan / ada dan sudah dijalankan di `beekas-dev`
- [ ] Perubahan tampilan: screenshot 390 px dilampirkan, dan dicek di Deploy Preview Netlify
- [ ] Dokumen (`docs/`) diperbarui bila perilaku produk berubah
