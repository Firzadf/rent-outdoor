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
satu ink, satu aksen oranye, konten penuh per section, bukti tidak dikarang.
Identitas hijau forest dan oranye dipertahankan dari template.

Upgrade UI 18 Nov 2026 (brief user: modern, 3D, animasi, transisi):
penyimpangan yang dicatat di komentar atas `globals.css`, sama seperti
`depth.dart` di aplikasi Flutter, arah 3D dari user menang atas larangan
gradien, kaca, dan bayangan di design.md §2. Yang ditambahkan: gradien
hutan di hero dan footer, gradien oranye di tombol primer, panel kaca
di picker tanggal, chip kategori, dan chip hero, bayangan berlapis di
kartu, tilt 3D mengikuti pointer (`components/Tilt.tsx`, hanya mouse dan
tanpa reduced motion), transisi antar halaman lewat View Transitions,
scroll reveal lewat CSS `animation-timeline: view()` dengan fallback
konten tetap terlihat, animasi kata per kata di headline hero, zoom
lambat di foto hero, chip mengambang, dan micro-interaction di tombol,
kartu, dan form. Semua gerakan memakai transform dan opacity saja, dan
mati di `prefers-reduced-motion`.

Referensi live yang dibuka 18 Nov 2026: Land-book (galeri landing,
pola hero besar dan section penuh), React Bits (komponen animasi sebagai
source yang dimiliki sendiri, pola teks dan background beranimasi),
Magic UI (150+ komponen animasi React, pola bento dan efek sorotan,
yang diambil hanya prinsip satu efek fokus per layar), Typewolf
(di luar zona nyaman, pasangan font dan hierarki tipografi, yang diambil
hanya disiplin ukuran display). Yang sengaja tidak disalin: rating,
testimoni, dan statistik dari situs referensi, karena bukan milik
OutdoorRent. Referensi sewa yang sudah dipakai sebelumnya: Basecamp
Rental Co, Wilderness Rentals Canmore, Louez.io.

Skill yang dipakai: modern-web-guidance (motion, cross-document
transitions, parallax, retrieve dulu sebelum menulis kode),
taste-frontend (arah dan house style), hallmark (floor token dan
focus-visible), impeccable (mode Persuade untuk halaman publik,
Operate untuk admin dan checkout), emil-design-eng (tekan 0,97,
ease-out, tanpa transition: all), make-interfaces-feel-better
(radius konsentris, shadow berlapis, angka tabular, stagger),
animation-principles dan kinetic-typography (headline kata per kata).
GSAP dan stageshow tidak dipakai: animasi scroll dan timeline sudah
tercakup CSS scroll-driven dan View Transitions tanpa dependensi baru,
dan hero memakai foto asli, bukan faux UI. Watermelon UI dicek dan
tidak dipakai: sistem CSS polos proyek ini sudah cukup, menambah
600 komponen hanya menambah bobot.
