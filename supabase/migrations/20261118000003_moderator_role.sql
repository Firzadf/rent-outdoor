-- ============================================================================
-- Migrasi 20261118000003: peran moderator.
-- Project: rent-outdoor (mdpmdjmorihsjsdhvsbn).
--
-- JALANKAN di Supabase SQL Editor SETELAH migrasi 00000, 00001, dan 00002.
-- Sekali jalan, tanpa error bila dijalankan berurutan (semua objek memakai
-- `if not exists` / `drop ... if exists`).
--
-- Peran moderator: boleh melihat dashboard admin, mengubah status booking,
-- dan memverifikasi atau menolak pembayaran. TIDAK boleh mengubah peran
-- pengguna (hanya admin) dan TIDAK boleh mengubah harga atau stok katalog
-- (policy tulis equipments/categories tetap admin saja).
--
-- Catatan: policy RLS di sini tidak bisa membatasi kolom. Pembatasan
-- "moderator hanya ubah status booking" ditegakkan di UI (halaman admin
-- hanya menampilkan kontrol status untuk moderator), sedangkan database
-- mengizinkan moderator update baris booking. Itu kompromi yang dicatat
-- di sini dengan jujur; bila perlu pembatasan kolom yang keras, tambahkan
-- trigger yang menolak update kolom selain status oleh moderator.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Constraint role: tambah 'moderator'.
--    Constraint check di tabel users dibuat tanpa nama di migrasi 00000,
--    jadi Postgres menamainya users_role_check.
-- ---------------------------------------------------------------------------
alter table public.users drop constraint if exists users_role_check;
alter table public.users
  add constraint users_role_check check (role in ('customer', 'admin', 'moderator'));

-- ---------------------------------------------------------------------------
-- 2. Helper peran.
-- ---------------------------------------------------------------------------
create or replace function public.is_moderator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users
    where auth_user_id = auth.uid()
      and role = 'moderator'
      and is_active = true
  );
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users
    where auth_user_id = auth.uid()
      and role in ('admin', 'moderator')
      and is_active = true
  );
$$;

-- ---------------------------------------------------------------------------
-- 3. Bookings: staf (admin + moderator) boleh baca dan ubah status.
--    Insert tetap hanya pemilik, delete tetap hanya admin.
-- ---------------------------------------------------------------------------
drop policy if exists "bookings_read_own" on public.bookings;
create policy "bookings_read_staff" on public.bookings
  for select using (
    user_id = public.own_app_user_id() or public.is_staff()
  );
drop policy if exists "bookings_update_own" on public.bookings;
create policy "bookings_update_staff" on public.bookings
  for update using (
    user_id = public.own_app_user_id() or public.is_staff()
  ) with check (
    user_id = public.own_app_user_id() or public.is_staff()
  );

-- ---------------------------------------------------------------------------
-- 4. Booking items: staf boleh baca (supaya admin panel melihat isi).
--    Ubah/hapus tetap hanya admin.
-- ---------------------------------------------------------------------------
drop policy if exists "booking_items_read_own" on public.booking_items;
create policy "booking_items_read_staff" on public.booking_items
  for select using (public.owns_booking(booking_id) or public.is_staff());

-- ---------------------------------------------------------------------------
-- 5. Payments: staf boleh baca dan verifikasi (approve/reject).
--    Insert tetap hanya pemilik booking, delete tetap hanya admin.
-- ---------------------------------------------------------------------------
drop policy if exists "payments_read_own" on public.payments;
create policy "payments_read_staff" on public.payments
  for select using (public.owns_booking(booking_id) or public.is_staff());
drop policy if exists "payments_update_admin" on public.payments;
create policy "payments_update_staff" on public.payments
  for update using (public.is_staff()) with check (public.is_staff());

-- ---------------------------------------------------------------------------
-- 6. Users: staf boleh baca daftar pengguna (nama penyewa di admin panel).
--    Update peran tetap hanya pemilik baris sendiri atau admin, jadi
--    moderator TIDAK bisa mengubah peran siapa pun.
--    Policy users_update_own dari 00002 sudah benar dan tidak diubah.
-- ---------------------------------------------------------------------------
drop policy if exists "users_read_own" on public.users;
create policy "users_read_staff" on public.users
  for select using (
    auth_user_id = auth.uid() or public.is_staff()
  );

-- Equipments dan categories: tulis tetap admin saja (00002), jadi
-- moderator tidak bisa mengubah harga atau stok. Tidak diubah di sini.

-- ---------------------------------------------------------------------------
-- Verifikasi sesudah jalan:
--   select conname, pg_get_constraintdef(oid) from pg_constraint
--    where conrelid = 'public.users'::regclass and contype = 'c';
--   select tablename, policyname, cmd from pg_policies
--    where schemaname = 'public' order by tablename, cmd;
--   -- Harus ada users_role_check dengan ('customer', 'admin', 'moderator'),
--   -- dan policy bookings_read_staff, bookings_update_staff,
--   -- booking_items_read_staff, payments_read_staff, payments_update_staff,
--   -- users_read_staff.
-- ---------------------------------------------------------------------------
