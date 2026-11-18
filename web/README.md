# OutdoorRent Web

Website sewa alat outdoor, Next.js 15 App Router + TypeScript + Supabase.
Satu repo dengan mentahan Flutter (`rental_outdoor/`) dan migrasi Supabase (`supabase/`).

Repo: https://github.com/Firzadf/rent-outdoor
Supabase: https://mdpmdjmorihsjsdhvsbn.supabase.co

## Halaman: pola marketplace

- **Storefront publik** `/` (header kaca + footer): hero, picker tanggal
  sewa, kategori, alat populer, cara sewa. Customer yang login **tetap
  melihat storefront yang sama**, tidak ada tampilan dashboard ala admin.
  Header publik hanya berubah di menu akun: pengunjung melihat Masuk dan
  Daftar, customer melihat menu "Halo, Nama" berisi Akun Saya, Pesanan
  Saya, Keranjang dengan jumlah, dan Profil, staf melihat Admin.
- **Customer setelah login** (layout publik yang sama, tanpa sidebar):
  `/dashboard` adalah halaman Akun Saya, sapaan nama, tautan cepat biasa,
  dan pesanan aktif sebagai daftar kartu pesanan biasa, tanpa kotak
  statistik dan tanpa tabel; `/pesanan`, `/keranjang`, `/checkout`,
  `/profil` juga di bawah layout publik yang sama. Login mengarah ke
  `/dashboard`, staf diarahkan dari sana ke `/admin`.
- **Admin/moderator** `/admin` (sidebar gelap, tab lewat `?tab=`):
  Ringkasan, Booking, Pembayaran, Katalog, Pengguna. Hanya role admin
  dan moderator yang boleh masuk, selain itu diarahkan dengan pesan.
  Moderator boleh melihat dashboard, mengubah status booking, dan
  memverifikasi pembayaran, tetapi tidak boleh mengubah peran pengguna,
  harga, atau stok (dibatasi di UI dan di RLS, migrasi 00003).
  Sidebar gelap hanya ada di sini, tidak di halaman customer.

## Bukti bayar

Bucket `payment-proofs` bersifat privat, jadi tautan publik
`/storage/v1/object/public/...` selalu gagal dengan 404 "Bucket not
found". Bukti bayar sekarang dibuka lewat signed URL 1 jam
(`resolveProofUrl` di `lib/supabase.ts`, komponen `ProofLink`),
di halaman pesanan customer dan di tab Pembayaran serta Booking admin.
Bila file tidak ada di Storage, tampil sebagai "File bukti tidak
ditemukan di Storage", bukan tautan rusak. Itu yang terjadi pada baris
seed lama `uploads/payments/pay_*.png`: seed hanya mengisi database,
file-nya tidak pernah diunggah, jadi tampil pesan itu sampai ada
bukti baru yang diunggah lewat halaman pesanan.

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

Migrasi utama `20261118000000` dan susulan `00001` serta `00002` sudah
live. Satu migrasi baru belum dijalankan, jalankan di SQL Editor
project rent-outdoor:

3. `supabase/migrations/20261118000003_moderator_role.sql`, peran
   moderator: constraint role jadi ('customer', 'admin', 'moderator'),
   helper `is_moderator()` dan `is_staff()`, dan policy RLS staf untuk
   baca dan ubah booking serta verifikasi pembayaran. Tanpa ini,
   moderator ditolak RLS saat membuka admin, dan mengubah role ke
   moderator gagal check constraint.

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

## Revisi menyeluruh 18 Nov 2026 (marketplace, hero, kartu, detail, 3D)

- **Pola marketplace (referensi Zalora, dikirim user):** fetch teks
  Zalora ditolak servernya (HTTP 403), jadi pola yang diterapkan adalah
  pola marketplace umum yang user minta: header dua baris (logo +
  pencarian + keranjang + menu akun, lalu strip kategori), kartu seragam,
  dan harga yang rapi. Tidak ada konten, foto, harga, atau teks Zalora
  yang disalin. Customer yang login tetap melihat storefront yang sama,
  hanya menu akunnya berubah.
- **Hero dan tipografi:** Fraunces (display serif editorial) untuk h1
  dan h2, Archivo (grotesque) untuk body, lewat `next/font` tanpa
  dependensi tambahan. Headline dua baris "Sewa alat outdoor, tanpa
  harus beli." di atas field datar, foto sebagai bidang dominan
  (52vh, maks 560px), picker tanggal sebagai bar datar yang menumpang
  di sambungan foto dan ground. Panel gradien, chip kaca, dan animasi
  kata per kata dihapus. Referensi tipografi: Typewolf
  (typewolf.com/recommendations, daftar font 2026).
- **Kartu seragam:** kartu kategori rasio 4/5 tetap di semua breakpoint
  (5 kolom desktop, 3 di 900px, 2 di 560px), label dua baris tetap
  (nama satu baris ellipsis + jumlah alat). Kartu alat: judul clamp
  2 baris dengan tinggi minimum, meta satu baris ellipsis, harga,
  deposit, dan chip stok sejajar, tombol menempel di bawah kartu.
- **Detail /alat/[id]:** dua kolom 7fr/6fr, foto rasio 4/3 yang dibatasi
  (penyebab foto raksasa: Tilt membuat media meregang setinggi kolom
  info yang panjang, Tilt dihapus dari media detail), breadcrumb,
  ulasan sebagai kartu (bukan tabel), alat terkait memakai gambarnya
  sendiri (dulu memakai gambar alat yang dibuka), keterangan sewa
  dari aturan proyek (deposit kembali, harga per hari, ambil-kembali).
- **Animasi 3D:** latar ambient hero (`HeroDepth`, lima bentuk redup
  melayang dengan kedalaman + kemiringan mengikuti pointer, hanya
  transform dan opacity, dua bentuk di layar kecil) dan layar loading
  3D saat pertama buka (`IntroLoader`, mark berputar masuk dan huruf
  merangkai, sekitar 1,6 detik, sekali per sesi tab, klik untuk
  lewati). Loading screen adalah momen 3D utama, latar hero dibuat
  tenang. Semua mati di `prefers-reduced-motion`. Tanpa Three.js.
- **Logo dan favicon:** mark lingkaran forest + gunung putih +
  matahari oranye (`components/LogoMark.tsx`), dipakai di header
  publik, sidebar admin, dan loading screen. Favicon di `public/`:
  `favicon.ico` (16/32/48), `icon-192.png`, `icon-512.png`,
  `apple-touch-icon.png`, plus `src/app/icon.svg`. Mark dicek
  terbaca di 16px (gunung 63 piksel, matahari 8 piksel).
- **Audit:** semua halaman dibaca ulang (landing, katalog, detail,
  keranjang, checkout, pesanan, profil, masuk, daftar, admin semua
  tab, dashboard Akun Saya, header, footer). Yang diperbaiki di luar
  laporan user: teks kedaluwarsa soal migrasi 00001/00002 di checkout,
  daftar, dan profil (migrasi sudah live), dan `.main-nav` CSS mati
  setelah header diganti strip kategori.

## Revisi tombol, gunung 3D, scroll, dan detail (18 Nov 2026)

- **Referensi yang dibuka:** Component Gallery (60 komponen dari 95
  design system nyata), 21st.dev (pola shadcn, tombol kecil teks
  medium dengan padding lega), Realtime Colors (aturan 60-30-10,
  3 warna cukup, primer hanya untuk CTA utama), shadcn/ui Button
  (varian default/outline/ghost/secondary/link, tangga ukuran,
  cursor pointer, status loading), Land-book (galeri landing),
  Refero (layar produk nyata per alur: detail produk, katalog,
  tambah ke keranjang, filter), Maxibestof (kurasi harian +
  pasangan font tiap situs), Layers (komunitas desain, di luar
  zona nyaman). Zalora dicoba lagi dan tetap ditolak 403, jadi
  pola marketplace yang dipakai adalah pola umum yang sudah ada.
  Mobbin butuh login, dilewati. Tidak ada konten, foto, harga,
  atau teks referensi yang disalin.
- **Sistem tombol baru:** datar satu warna isi tanpa gradien dan
  tanpa bayangan; radius tajam 4px (design.md §3, bukan radius
  lembut 9-16px); hover hanya menggelapkan isi; tekan turun 1px;
  fokus outline ink 3px; nonaktif abu datar; tangga ukuran kecil
  36px, default 48px, besar 56px; primer ember datar, ghost border
  ink 2px. Hover kartu tidak lagi naik dengan bayangan generik,
  garis tepi menggelap. Input dan select radius 4px yang sama,
  ada state hover dan nonaktif. Tab admin dan pill aktif header
  ikut sistem yang sama (pine dan ember datar).
- **Gunung 3D (`HeroDepth`):** lima bentuk generik diganti tiga
  punggung gunung SVG berlapis (belakang, tengah, depan) dengan
  matahari ember dan kabut yang bergerak pelan. Parallax scroll
  lewat view-timeline hero (offset beda per lapisan, sesuai
  modern-web-guidance `parallax-scroll-effects`), drift lambat
  di dalam SVG, kemiringan mengikuti pointer. Tombol "Jeda
  animasi" di pojok hero memenuhi WCAG 2.2.2. Di layar kecil
  hanya punggung depan dan matahari. Tanpa Three.js.
- **Gerakan scroll (modern-web-guidance `scroll-entry-exit-effects`
  dan `motion`):** headline hero naik dan memudar halus saat
  hero keluar layar; section masuk dengan rise + opacity lewat
  animation-timeline view(); anak grid kategori, alat, langkah,
  dan ulasan menyusul dengan range yang sama. Hanya transform
  dan opacity, dengan @supports dan fallback konten tetap
  terlihat, dan semua mati di `prefers-reduced-motion`.
- **Detail seimbang:** keterangan sewa pindah ke kolom kiri di
  bawah foto (bukan lagi section tiga kolom selebar halaman),
  blok harga dipadatkan sedikit. Satu alat hanya punya satu foto
  di data, jadi tidak ada galeri thumbnail. Di layar kecil urutan
  jadi foto, info, keterangan.
