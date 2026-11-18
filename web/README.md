# OutdoorRent Web

Website sewa alat outdoor, Next.js 15 App Router + TypeScript + Supabase.
Satu repo dengan mentahan Flutter (`rental_outdoor/`) dan migrasi Supabase (`supabase/`).

Repo: https://github.com/Firzadf/rent-outdoor
Supabase: https://mdpmdjmorihsjsdhvsbn.supabase.co

## Halaman

- `/` Beranda, hero, picker tanggal sewa yang menghitung ulang, kategori, alat populer.
- `/katalog` Pencarian, filter kategori, urutan harga dan rating.
- `/alat/[id]` Detail alat, galeri, ulasan, tambah ke keranjang dengan tanggal sewa.
- `/keranjang` Keranjang, rincian sewa per hari dan deposit.
- `/checkout` Buat booking dan pembayaran, butuh login.
- `/pesanan` Pesanan saya, status booking dan pembayaran, upload bukti bayar ke
  bucket `payment-proofs`, batalkan pesanan.
- `/profil` Edit nama, telepon, dan alamat.
- `/masuk`, `/daftar` Supabase Auth email dan password.
- `/admin` Khusus admin: ringkasan, ubah status booking, verifikasi pembayaran,
  edit harga dan stok katalog, ubah peran pengguna.

## Jalan lokal

```bash
cd web
cp .env.local.example .env.local
# isi NEXT_PUBLIC_SUPABASE_ANON_KEY dari Supabase Dashboard, Settings > API,
# pakai publishable key, JANGAN service_role key.
npm install
npm run dev
```

## Build

```bash
npm run build
```

## Deploy ke Vercel

Buat project Vercel dari repo ini, root directory `web`. Isi environment
variable di dashboard Vercel:

- `NEXT_PUBLIC_SUPABASE_URL` = `https://mdpmdjmorihsjsdhvsbn.supabase.co`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` = publishable key Supabase

Service_role key tidak dipakai di website ini.

## Yang masih harus dijalankan di Supabase

Migrasi utama `20261118000000` sudah live. Dua migrasi susulan belum
dijalankan, jalankan berurutan di SQL Editor project rent-outdoor:

1. `supabase/migrations/20261118000001_users_insert_policy.sql`, policy INSERT
   users supaya register dari web dan APK tidak gagal RLS 403 saat membuat
   profil. Tanpa ini, checkout menampilkan pesan profil belum terbentuk.
2. `supabase/migrations/20261118000002_harden_rls_stock.sql`, RLS ketat
   pemilik dan admin, validasi tanggal dan stok, fungsi `available_stock()`.

Matikan konfirmasi email di Authentication, Sign in / Providers, Email,
supaya register langsung bisa login untuk demo tugas kuliah.

## Data

Katalog, booking, pembayaran, dan ulasan dibaca dari Supabase lewat
`@supabase/supabase-js`. Bila env Supabase belum terisi atau Supabase tidak
bisa dihubungi, halaman menampilkan data contoh dari seed migrasi dan banner
mode contoh, supaya tetap bisa dibuka dan diverifikasi. Checkout, pesanan,
dan admin tidak jalan di mode contoh.

Foto di `public/images` adalah foto referensi dari Unsplash (lisensi Unsplash,
gratis dipakai), diunduh ke proyek dan dicek isinya. Itu foto referensi
kategori, bukan foto unit yang disewakan, dan ditulis jelas di footer.
Bucket `equipment-images` di Supabase masih kosong. Begitu foto asli diunggah
ke bucket dengan nama path yang sama seperti di tabel `equipment_images`,
foto asli tampil otomatis lewat URL publik bucket.

## Desain

Mengikuti `~/workspace/design.md`: token warna di `:root`, satu ground,
satu ink, satu aksen oranye, sudut persegi, tanpa gradien dan tanpa kaca.
Identitas hijau forest dan oranye dipertahankan dari template.
Referensi yang dipakai: Basecamp Rental Co (katalog disusun per jenis
perjalanan, harga di depan), Wilderness Rentals Canmore (harga per ukuran
tenda), dan Louez.io (etalase sewa dengan deposit). Yang diambil: harga per
hari dan deposit selalu terlihat di kartu, kategori sebagai pintu masuk,
dan alur pilih tanggal, bayar, ambil, kembalikan.
