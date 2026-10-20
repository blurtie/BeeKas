# BeeKas -> aplikasi Venture Creation

Marketplace barang preloved dan donasi khusus sivitas BINUS University, dibangun dengan Flutter (Android dan iOS).

**Status:** prototype, PRD sedang ditulis.

Versi web sebelumnya (Next.js + Supabase) tersimpan di tag [`web-nextjs-final`](https://github.com/blurtie/BeeKas/tree/web-nextjs-final).

## Persiapan

Wajib Flutter **3.47.x stable** (Dart 3.13.x). Cek versinya:

```sh
flutter --version
```

## Menjalankan

Butuh Supabase lokal (Docker). Langkah lengkapnya, termasuk HP di jaringan yang sama, ada di [docs/local-setup.md](docs/local-setup.md).

```sh
flutter pub get
supabase start
flutter run --dart-define-from-file=dart_defines.json
```
