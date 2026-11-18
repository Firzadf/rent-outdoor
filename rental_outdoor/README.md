# OutdoorRent

Aplikasi rental alat outdoor berbasis Flutter untuk web dan Android. Customer
dapat mencari alat, mengecek ketersediaan, memesan, dan mengunggah bukti
pembayaran. Admin mengelola katalog, kategori, pesanan, pembayaran, dan user.

## Fitur

- Autentikasi: login, register, profil, ganti password (token disimpan di
  `flutter_secure_storage`).
- Katalog: daftar & pencarian alat, filter kategori, detail alat, galeri foto,
  ulasan dan rating.
- Keranjang lokal: pilih rentang tanggal sewa, cek ketersediaan stok dari
  server, lanjut ke checkout.
- Pesanan: buat pesanan, daftar & detail pesanan, batalkan pesanan.
- Pembayaran: rekening tujuan, hitung mundur batas bayar, unggah bukti transfer,
  status verifikasi dan alasan penolakan.
- Admin:
  - Dashboard ringkasan pesanan dan pendapatan.
  - Kelola alat (tambah/ubah/hapus, unggah & hapus foto galeri).
  - Kelola kategori.
  - Verifikasi pembayaran (setujui/tolak).
  - Kelola status pesanan.
  - Kelola user (aktif/nonaktif).
- Tampilan responsif dari 360 px sampai desktop, loading/kosong/error yang
  konsisten, dan pesan error server berbahasa Indonesia.

## Prasyarat

- Flutter SDK (Dart 3).
- Backend sesuai kontrak `docs/API_DOCS.md`, dapat diakses dari perangkat/emulator.

## Konfigurasi API

Base URL API diatur saat build lewat `--dart-define=API_BASE_URL=...`.
Nilai default:

- Web / desktop: `http://localhost/outdoorrent/api`
- Android: `http://10.0.2.2/outdoorrent/api` (alamat host dari emulator)

Nilai tanpa `http://`/`https://` tidak valid. Slash di akhir otomatis dibuang.
URL gambar (`uploads/...`) diturunkan dari base URL yang sama.

## Menjalankan di Chrome

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost/outdoorrent/api
```

Bila backend berjalan di host/port lain:

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://127.0.0.1:8080/outdoorrent/api
```

## Build web

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.contoh.com/outdoorrent/api
```

Hasil build ada di `build/web`. Unggah ke hosting statis; backend harus
mengizinkan CORS dari domain web tersebut.

## Build APK

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.contoh.com/outdoorrent/api
```

Hasil build ada di `build/app/outputs/flutter-apk/app-release.apk`.

`usesCleartextTraffic` hanya aktif pada manifest debug
(`android/app/src/debug/AndroidManifest.xml`), sehingga HTTP biasa masih bisa
dipakai untuk pengembangan di emulator/perangkat. Build release tidak
mengizinkan HTTP plaintext; gunakan HTTPS.

## Opsi HTTPS untuk rilis

1. **HTTPS di server (disarankan).** Pasang sertifikat TLS (mis. Let's Encrypt)
   pada domain backend, lalu isi `API_BASE_URL` dengan `https://...`. Tidak ada
   perubahan kode aplikasi.
2. **Reverse proxy.** Letakkan Nginx/Apache/Caddy di depan backend PHP untuk
   menangani TLS, lalu arahkan `API_BASE_URL` ke domain proxy tersebut.
3. **HTTP sementara untuk uji internal.** Jalankan build debug, atau tambahkan
   konfigurasi network security khusus bila memang terpaksa; jangan kirim build
   release yang masih memakai HTTP karena token dan data user tidak terenkripsi.

## Akun uji

Gunakan data seed backend. Contoh akun yang dipakai pada dokumentasi dan widget
test:

| Peran    | Email              | Password      |
| -------- | ------------------ | ------------- |
| Customer | `customer@test.com`| `password123` |
| Admin    | `admin@test.com`   | `password123` |

Bila seed backend berbeda, sesuaikan email/password. Widget test memakai adapter
Dio palsu, jadi kredensial di atas tidak melakukan request jaringan.

## Pemeriksaan kualitas

```bash
flutter analyze
flutter test
```

Widget test alur rilis ada di `test/features/release/release_flow_test.dart`
(login customer, tambah keranjang sampai checkout, login admin, dan penolakan
customer ke `/admin`) dan dijalankan pada lebar 360, 620, dan 1200 px.

## Struktur singkat

```
lib/
  core/        # konfigurasi, jaringan, router, tema, widget bersama
  features/    # auth, catalog, cart, booking, payment, profile, admin
test/          # unit + widget test
docs/          # kontrak API
web/           # entry web (judul & manifest OutdoorRent)
android/       # konfigurasi Android (label & cleartext debug-only)
```
