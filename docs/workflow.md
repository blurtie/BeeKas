# Alur Kerja Pengembangan

Cara perubahan masuk ke BeeKas, dari branch sampai produksi. Berlaku untuk anggota tim dan asisten koding. Keputusan di balik alur ini ada di D-15 pada [`decisions.md`](decisions.md).

## Ringkasan

```
branch fitur ──► commit ──► push ──► Pull Request ──► CI + Deploy Preview ──► review ──► squash merge ──► produksi
```

`main` selalu berisi versi yang sedang live di Netlify. Tidak ada yang di-commit langsung ke `main`.

## 1. Branch

Satu branch untuk satu unit kerja yang bisa di-review sendiri. Buat dari `main` terbaru.

| Awalan | Untuk | Contoh |
|---|---|---|
| `feat/` | Fitur baru | `feat/auth-otp`, `feat/ui-catalog` |
| `fix/` | Perbaikan bug | `fix/sw-offline-profile` |
| `docs/` | Dokumen saja | `docs/decision-d15` |
| `chore/` | Konfigurasi, dependency, CI | `chore/ci-workflow` |

Branch sebaiknya hidup paling lama beberapa hari. Branch yang terlalu lama tertinggal dari `main` sulit di-review dan rawan konflik.

## 2. Commit

- Format [Conventional Commits](https://www.conventionalcommits.org/): `feat: ...`, `fix: ...`, `docs: ...`, `chore: ...`, `test: ...`, `refactor: ...`.
- Bahasa Inggris, kalimat perintah, tanpa titik di akhir.
- Satu commit satu perubahan yang masuk akal sendiri.
- Tanpa atribusi AI dalam bentuk apa pun, dan author selalu identitas git pemilik akun.

## 3. Pull Request

- Buka PR ke `main` memakai template yang tersedia. Isi acuan PRD, keputusan, dan cara menguji.
- Satu PR sebaiknya di bawah sekitar 400 baris perubahan, tidak termasuk `package-lock.json`. PR besar dipecah.
- PR yang belum siap dibuka sebagai Draft.

## 4. Pemeriksaan otomatis

Setiap PR dan setiap push ke `main` menjalankan dua hal.

**CI (GitHub Actions, `.github/workflows/ci.yml`)**

1. `npm ci`
2. `npm run lint`
3. `npm run typecheck` (next typegen, lalu tsc --noEmit)
4. `npm test`
5. `npm run build`
6. Pengecekan bahwa kredensial server tidak dirujuk dari kode klien

**Deploy Preview (Netlify)**

Netlify membuat URL pratinjau untuk setiap PR. Perubahan tampilan wajib dicek di URL ini, termasuk di HP.

PR tidak boleh di-merge bila CI merah.

## 5. Review

Urutannya:

1. **Review independen oleh agent** (bila dikerjakan lewat orchestrator): reviewer yang tidak melihat proses worker, hanya tujuan, kriteria, dan diff.
2. **Review oleh CTO**: membaca diff, membuka Deploy Preview, dan menjalankan langkah "Cara menguji".
3. Perubahan yang menyentuh auth, RLS, kuota, atau pembayaran wajib diuji dengan dua akun berbeda sebelum disetujui.

## 6. Merge dan rilis

- Merge memakai **Squash and merge**, dengan judul PR sebagai pesan commit. Riwayat `main` jadi satu commit per PR.
- Branch dihapus setelah merge.
- Netlify otomatis men-deploy `main` ke produksi.
- Bila produksi rusak setelah merge: buka Netlify → Deploys, pilih deploy sebelumnya, lalu **Publish deploy** untuk rollback. Setelah itu perbaiki lewat PR baru.

## 7. Migrasi basis data

Kode di-deploy otomatis, tetapi skema basis data tidak. Migrasi dijalankan manual.

1. Berkas migrasi baru di `supabase/migrations/`, dengan nomor urut.
2. Migrasi dijalankan ke project `beekas-dev` **sebelum** PR di-merge, supaya Deploy Preview bisa diuji dengan skema baru.
3. Migrasi harus aman untuk kode lama yang masih live selama jeda antara migrasi dan merge. Hindari menghapus atau mengganti nama kolom yang masih dipakai. Lakukan dalam dua PR bila perlu.
4. Setelah ada project produksi terpisah (sebelum Fase 7), migrasi dijalankan ke produksi sesudah merge, dan dicatat di deskripsi PR.
5. Mulai Fase 7 (ada pengguna di luar tim), perubahan constraint memakai dua migrasi: *expand* (longgarkan aturan, kode lama dan baru sama-sama lolos) sebelum merge, lalu *contract* (perketat aturan) setelah kode baru live dan data lama sudah disesuaikan. Sebelum Fase 7 boleh satu migrasi, dijalankan tepat sebelum merge.

## 8. Menerjemahkan desain Figma

1. Hanya frame di page `Siap dev` yang diterjemahkan.
2. Satu alur desain satu branch, misalnya `feat/ui-catalog`.
3. Yang diganti hanya lapisan tampilan di `src/ui/` dan halaman terkait. Logika di `src/lib/domain/` dan basis data tidak diubah dalam PR desain.
4. Warna dan teks mengikuti token dan `src/config/copy.ts`. Nilai baru dari Figma ditambahkan ke sana, bukan ditulis langsung di komponen.
5. PR desain melampirkan screenshot 390 px dan tautan frame Figma yang diterjemahkan.
6. Bila desain bertentangan dengan PRD, tanyakan ke tim sebelum diterjemahkan.

## 9. Aturan untuk asisten koding

- Bekerja hanya di branch fitur. Tidak pernah commit, push, merge, atau force push ke `main`.
- Commit dan push ke branch fitur mengikuti aturan persetujuan di `CLAUDE.md` lokal.
- Membuka PR boleh. Merge selalu dilakukan manusia lewat GitHub.
- Tidak menjalankan migrasi ke project Supabase mana pun tanpa persetujuan.
- Tidak mengubah `.github/workflows/` tanpa persetujuan.

## 10. Pengaturan satu kali (dilakukan pemilik repo)

- [ ] GitHub → Settings → Branches → tambah branch protection rule untuk `main`: wajib lewat PR, wajib status check **CI / Lint, typecheck, test, build** lolos, dan branch harus up to date sebelum merge.
- [ ] GitHub → Settings → General → Pull Requests: aktifkan hanya **Allow squash merging**, dan aktifkan **Automatically delete head branches**.
- [ ] Netlify → Project configuration → Build & deploy: pastikan **Deploy Previews** aktif untuk Pull Request, dan production branch adalah `main`.
