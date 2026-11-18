-- Follow-up migrasi untuk APK live OutdoorRent.
-- Jalankan di Supabase SQL Editor project rent-outdoor
-- (https://supabase.com/dashboard/project/mdpmdjmorihsjsdhvsbn),
-- SETELAH migrasi utama 20261118000000_outdoorrent_postgres.sql.
--
-- Masalah yang diperbaiki: migrasi utama tidak memberi policy INSERT
-- untuk tabel public.users, jadi pendaftaran akun baru dari APK gagal
-- (RLS 403) saat membuat baris profil. Policy ini mengizinkan user
-- yang sudah login membuat baris profilnya sendiri
-- (auth_user_id = auth.uid()).
--
-- Verifikasi sesudah jalan:
--   select * from pg_policies where tablename = 'users';
-- Harus ada baris users_insert_own untuk perintah INSERT.
create policy "users_insert_own"
  on public.users
  for insert
  with check (auth.uid() = auth_user_id);

-- Cara membuat akun admin (setelah daftar akun baru di APK):
--   update public.users set role = 'admin'
--    where email = 'email-admin@contoh.com';
--
-- Catatan: konfirmasi email di dashboard Supabase (Authentication >
-- Sign in / Providers > Email) sebaiknya DIMATIKAN untuk demo tugas
-- kuliah, supaya register langsung mendapat sesi. Bila tetap aktif,
-- user harus klik link konfirmasi di email dulu sebelum bisa login.
-- Akun uji lama template PHP (admin@outdoorrent.com,
-- customer@test.com) TIDAK bisa login: hash bcrypt-nya tidak dikenal
-- Supabase Auth. Daftar akun baru di APK.
