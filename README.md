# rent-outdoor / OutdoorRent

Website sewa alat outdoor, versi website dari template Flutter + PHP yang dikirim user.

- Repo: https://github.com/Firzadf/rent-outdoor
- Supabase: https://mdpmdjmorihsjsdhvsbn.supabase.co
- Dashboard Supabase: https://supabase.com/dashboard/project/mdpmdjmorihsjsdhvsbn
- Region: Singapore, ap-southeast-1, plan Free Nano
- Preview statis (simulasi, belum terhubung database): artifact `outdoorrent-preview` di Muse

## Isi template asli

Template di `templat_sewa_outdoor.zip` berisi dua bagian:

- `rental_outdoor`, aplikasi Flutter, 121 file Dart, fitur auth, katalog, keranjang, booking, pembayaran, profil, dan admin.
- `outdoorrent`, backend PHP tanpa framework, 31 file PHP, 9 controller, 7 model, JWT, rate limit login, dan cron auto-cancel.
- Database `outdoorrent.sql`, 9 tabel, 22 KB.

Data seed yang dipakai di preview dan migrasi: 4 user, 5 kategori, 12 alat, 12 gambar alat, 5 booking, 5 item booking, 5 pembayaran, 1 review, 6 login attempt.

Catatan data: alat aktif ada 11 dari 12, karena Headlamp LED 500 Lumens nonaktif. Nama Tenda 6 Orang Family muncul dua kali, id 11 dan 12, dipertahankan apa adanya dari template.

## Migrasi Supabase

File: `supabase/migrations/20261118000000_outdoorrent_postgres.sql`

Konversi MySQL ke Postgres, lengkap dengan seed, index, foreign key, trigger `updated_at`, RLS, dan bucket storage `equipment-images` (publik) dan `payment-proofs` (privat).

Cara menjalankan:

1. Buka Supabase Dashboard, lalu SQL Editor, New query.
2. Tempel seluruh isi file migrasi, lalu Run.
3. Jalankan query cek di bagian bawah file migrasi. Hasil yang benar: users 4, categories 5, equipments 12, equipment_images 12, bookings 5, booking_items 5, payments 5, reviews 1, login_attempts 6.

File ini sudah dicek sintaksnya dengan parser Postgres `pglast`, 113 statement, lolos. Belum dijalankan ke database live, karena password database dan service role key tidak disimpan di chat.

## Keamanan

- Jangan commit `.env.local` atau file berisi key Supabase.
- `users.password` di seed adalah hash bcrypt dari template, bukan password Supabase Auth. Ganti password admin setelah migrasi.
- Akun uji template: `admin@outdoorrent.com` dan `customer@test.com`. Lihat README template untuk password awal, lalu ganti.
- Jangan tampilkan key Supabase di chat. Key untuk Vercel disimpan sebagai environment variable di dashboard Vercel, atau sebagai GitHub Secret seperti di project BitBots.

## Rencana

1. Migrasi SQL ke Supabase, file sudah siap di folder ini.
2. Bangun website Next.js dengan Supabase Auth, Storage, dan RLS, lalu deploy ke Vercel.
3. Ganti foto placeholder preview dengan foto asli alat, setelah user menyediakan foto atau mengunggahnya ke bucket `equipment-images`.
