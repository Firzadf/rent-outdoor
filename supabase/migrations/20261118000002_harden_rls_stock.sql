-- ============================================================================
-- Migrasi 20261118000002: perketat RLS + validasi stok/tanggal di database.
-- Project: rent-outdoor (mdpmdjmorihsjsdhvsbn).
--
-- JALANKAN di Supabase SQL Editor SETELAH migrasi 00000 dan 00001.
-- BELUM dijalankan ke live dari mesin ini; file ini hanya disiapkan di repo.
-- Sekali jalan, tanpa error bila dijalankan berurutan (semua objek memakai
-- `if not exists` / `drop ... if exists`).
--
-- Yang diperbaiki dari migrasi 00000 (RLS-nya terlalu longgar):
--   * Semua user login boleh INSERT/UPDATE/DELETE semua booking, payment,
--     kategori, dan alat. Sekarang hanya pemilik atau admin.
--   * Tidak ada validasi stok dan tanggal di database; aplikasi hanya
--     mengecek di client. Sekarang trigger menolak booking yang tanggalnya
--     tidak valid atau jumlahnya melebihi stok tersedia.
--   * Bukti bayar di bucket payment-proofs bisa dibaca semua user login.
--     Sekarang upload tetap untuk login, baca untuk pemilik/admin (lihat
--     catatan batasan di bagian storage).
--
-- Tentang stok: kolom equipments.stock adalah stok TOTAL dan TIDAK
-- dikurangi saat booking dibuat. Ketersediaan dihitung dari status
-- booking (pending_payment, pending_verification, confirmed, in_use
-- memblokir unit pada rentang tanggalnya). Jadi pembatalan atau
-- penyelesaian booking OTOMATIS mengembalikan stok, tanpa trigger
-- pengurang yang rawan dobel hitung. Fungsi available_stock() dan
-- trigger validate_booking_item() adalah penegaknya di database.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Helper: siapa saya, apakah saya admin, apakah booking ini milik saya.
-- SECURITY DEFINER supaya bisa membaca public.users meski RLS aktif;
-- hanya membaca role/id sendiri, tidak menulis apa pun.
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users
    where auth_user_id = auth.uid()
      and role = 'admin'
      and is_active = true
  );
$$;

create or replace function public.own_app_user_id()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select id from public.users
  where auth_user_id = auth.uid()
  limit 1;
$$;

create or replace function public.owns_booking(p_booking_id integer)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.bookings b
    where b.id = p_booking_id
      and (b.user_id = public.own_app_user_id() or public.is_admin())
  );
$$;

-- ---------------------------------------------------------------------------
-- Stok tersedia: stok total dikurangi unit yang ter-booking pada rentang
-- tanggal itu. Status yang memblokir: pending_payment,
-- pending_verification, confirmed, in_use. Status cancelled, rejected,
-- dan completed TIDAK memblokir, jadi batal/selesai mengembalikan stok.
-- Dipakai aplikasi lewat RPC dan dipakai trigger di bawah.
-- ---------------------------------------------------------------------------
create or replace function public.available_stock(
  p_equipment_id integer,
  p_pickup date,
  p_return date
)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select greatest(
    0,
    coalesce((select stock from public.equipments where id = p_equipment_id), 0)
    - coalesce((
        select sum(bi.quantity)
        from public.booking_items bi
        join public.bookings b on b.id = bi.booking_id
        where bi.equipment_id = p_equipment_id
          and b.status in ('pending_payment', 'pending_verification', 'confirmed', 'in_use')
          and b.pickup_date <= p_return
          and b.return_date >= p_pickup
      ), 0)
  );
$$;

-- ---------------------------------------------------------------------------
-- Validasi tanggal booking: return harus sesudah pickup, pickup tidak
-- boleh di masa lalu. Pada UPDATE hanya dicek bila tanggalnya berubah,
-- supaya admin tetap bisa menyelesaikan booking lama tanpa ditolak.
-- ---------------------------------------------------------------------------
create or replace function public.validate_booking_dates()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and old.pickup_date is not distinct from new.pickup_date
     and old.return_date is not distinct from new.return_date then
    return new;
  end if;
  if new.return_date <= new.pickup_date then
    raise exception 'Tanggal kembali harus sesudah tanggal ambil.';
  end if;
  if new.pickup_date < current_date then
    raise exception 'Tanggal ambil tidak boleh di masa lalu.';
  end if;
  return new;
end;
$$;

drop trigger if exists bookings_validate_dates on public.bookings;
create trigger bookings_validate_dates
  before insert or update on public.bookings
  for each row execute function public.validate_booking_dates();

-- ---------------------------------------------------------------------------
-- Validasi item booking: jumlah > 0 dan tidak melebihi stok tersedia
-- pada rentang tanggal booking induknya. Dicek di database supaya dua
-- user yang checkout bersamaan tidak bisa overbooking.
-- ---------------------------------------------------------------------------
create or replace function public.validate_booking_item()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_pickup date;
  v_return date;
  v_available integer;
  v_booked integer;
begin
  select pickup_date, return_date into v_pickup, v_return
    from public.bookings where id = new.booking_id;
  if v_pickup is null then
    raise exception 'Booking induk tidak ditemukan.';
  end if;
  if new.quantity <= 0 then
    raise exception 'Jumlah alat harus lebih dari 0.';
  end if;
  -- Stok tersedia tanpa menghitung baris ini sendiri (untuk UPDATE).
  select coalesce(sum(bi.quantity), 0) into v_booked
    from public.booking_items bi
    join public.bookings b on b.id = bi.booking_id
    where bi.equipment_id = new.equipment_id
      and bi.id is distinct from new.id
      and b.status in ('pending_payment', 'pending_verification', 'confirmed', 'in_use')
      and b.pickup_date <= v_return
      and b.return_date >= v_pickup;
  select stock into v_available
    from public.equipments where id = new.equipment_id;
  if v_available is null then
    raise exception 'Alat tidak ditemukan.';
  end if;
  if new.quantity > greatest(0, v_available - v_booked) then
    raise exception 'Stok % tidak cukup untuk jumlah yang diminta.', new.equipment_id;
  end if;
  return new;
end;
$$;

drop trigger if exists booking_items_validate_stock on public.booking_items;
create trigger booking_items_validate_stock
  before insert or update on public.booking_items
  for each row execute function public.validate_booking_item();

-- ---------------------------------------------------------------------------
-- Validasi review: hanya untuk booking completed milik sendiri dan alat
-- yang memang bagian dari booking itu. Unique (booking, equipment)
-- sudah ada dari migrasi 00000, jadi satu ulasan per alat per booking.
-- ---------------------------------------------------------------------------
create or replace function public.validate_review()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.bookings b
    where b.id = new.booking_id
      and b.user_id = new.user_id
      and b.status = 'completed'
  ) then
    raise exception 'Ulasan hanya untuk booking completed milik sendiri.';
  end if;
  if not exists (
    select 1 from public.booking_items bi
    where bi.booking_id = new.booking_id
      and bi.equipment_id = new.equipment_id
  ) then
    raise exception 'Alat ini bukan bagian dari booking tersebut.';
  end if;
  return new;
end;
$$;

drop trigger if exists reviews_validate_owner on public.reviews;
create trigger reviews_validate_owner
  before insert on public.reviews
  for each row execute function public.validate_review();

-- ---------------------------------------------------------------------------
-- Batalkan booking yang lewat batas bayar (dipanggil manual atau lewat
-- pg_cron; aplikasi juga tetap melakukan lazy cancel seperti sebelumnya).
-- ---------------------------------------------------------------------------
create or replace function public.cancel_expired_bookings()
returns integer
language sql
security definer
set search_path = public
as $$
  with expired as (
    update public.bookings
    set status = 'cancelled',
        cancellation_reason = coalesce(cancellation_reason, 'Batas waktu pembayaran habis.'),
        updated_at = now()
    where status = 'pending_payment'
      and auto_cancel_at is not null
      and auto_cancel_at < now()
    returning id
  )
  select count(*)::integer from expired;
$$;

-- ---------------------------------------------------------------------------
-- Constraint tambahan (idempotent lewat DO block).
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'booking_items_quantity_positive'
  ) then
    alter table public.booking_items
      add constraint booking_items_quantity_positive check (quantity > 0);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'bookings_return_after_pickup'
  ) then
    alter table public.bookings
      add constraint bookings_return_after_pickup check (return_date > pickup_date);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'payments_amount_positive'
  ) then
    alter table public.payments
      add constraint payments_amount_positive check (amount > 0);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Index tambahan untuk query yang dipakai aplikasi.
-- ---------------------------------------------------------------------------
create index if not exists idx_equipments_catalog
  on public.equipments (category_id, is_active, price_per_day);
create index if not exists idx_bookings_user_status
  on public.bookings (user_id, status, created_at desc);
create index if not exists idx_bookings_status_pickup
  on public.bookings (status, pickup_date);
create index if not exists idx_booking_items_booking_equipment
  on public.booking_items (booking_id, equipment_id);
create index if not exists idx_payments_booking_status
  on public.payments (booking_id, status);
create index if not exists idx_reviews_equipment_rating
  on public.reviews (equipment_id, rating);
create unique index if not exists users_auth_user_id_unique
  on public.users (auth_user_id);

-- ---------------------------------------------------------------------------
-- RLS: ganti policy longgar migrasi 00000 dengan policy pemilik/admin.
-- Policy INSERT users dari migrasi 00001 (users_insert_own) DIPERTAHANKAN,
-- tidak di-drop di sini.
-- login_attempts sengaja TANPA policy: hanya service_role yang bisa
-- baca/tulis (dipakai server, bukan aplikasi client).
-- ---------------------------------------------------------------------------

-- Katalog: baca publik, tulis hanya admin.
drop policy if exists "categories_read_all" on public.categories;
create policy "categories_read_all" on public.categories
  for select using (true);
drop policy if exists "categories_write_auth" on public.categories;
create policy "categories_write_admin" on public.categories
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "equipments_read_all" on public.equipments;
create policy "equipments_read_public" on public.equipments
  for select using (is_active = true or public.is_admin());
drop policy if exists "equipments_write_auth" on public.equipments;
create policy "equipments_write_admin" on public.equipments
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "equipment_images_read_all" on public.equipment_images;
create policy "equipment_images_read_all" on public.equipment_images
  for select using (true);
drop policy if exists "equipment_images_write_auth" on public.equipment_images;
create policy "equipment_images_write_admin" on public.equipment_images
  for all using (public.is_admin()) with check (public.is_admin());

-- Users: dirinya sendiri atau admin. Insert tetap dari 00001.
drop policy if exists "users_read_auth" on public.users;
create policy "users_read_own" on public.users
  for select using (
    auth_user_id = auth.uid() or public.is_admin()
  );
drop policy if exists "users_update_auth" on public.users;
create policy "users_update_own" on public.users
  for update using (
    auth_user_id = auth.uid() or public.is_admin()
  ) with check (
    auth_user_id = auth.uid() or public.is_admin()
  );

-- Bookings: pemilik atau admin. Delete hanya admin.
drop policy if exists "bookings_all_auth" on public.bookings;
create policy "bookings_read_own" on public.bookings
  for select using (
    user_id = public.own_app_user_id() or public.is_admin()
  );
create policy "bookings_insert_own" on public.bookings
  for insert with check (user_id = public.own_app_user_id());
create policy "bookings_update_own" on public.bookings
  for update using (
    user_id = public.own_app_user_id() or public.is_admin()
  ) with check (
    user_id = public.own_app_user_id() or public.is_admin()
  );
create policy "bookings_delete_admin" on public.bookings
  for delete using (public.is_admin());

-- Booking items: ikut kepemilikan booking induknya. Ubah/hapus hanya admin.
drop policy if exists "booking_items_all_auth" on public.booking_items;
create policy "booking_items_read_own" on public.booking_items
  for select using (public.owns_booking(booking_id));
create policy "booking_items_insert_own" on public.booking_items
  for insert with check (public.owns_booking(booking_id));
create policy "booking_items_update_admin" on public.booking_items
  for update using (public.is_admin()) with check (public.is_admin());
create policy "booking_items_delete_admin" on public.booking_items
  for delete using (public.is_admin());

-- Payments: ikut kepemilikan booking induknya. Ubah hanya admin
-- (verifikasi approve/reject), hapus hanya admin.
drop policy if exists "payments_all_auth" on public.payments;
create policy "payments_read_own" on public.payments
  for select using (public.owns_booking(booking_id));
create policy "payments_insert_own" on public.payments
  for insert with check (public.owns_booking(booking_id));
create policy "payments_update_admin" on public.payments
  for update using (public.is_admin()) with check (public.is_admin());
create policy "payments_delete_admin" on public.payments
  for delete using (public.is_admin());

-- Reviews: baca publik, tulis hanya pemilik (plus trigger di atas).
drop policy if exists "reviews_read_all" on public.reviews;
create policy "reviews_read_all" on public.reviews
  for select using (true);
drop policy if exists "reviews_write_auth" on public.reviews;
create policy "reviews_insert_own" on public.reviews
  for insert with check (user_id = public.own_app_user_id());
create policy "reviews_update_own" on public.reviews
  for update using (
    user_id = public.own_app_user_id() or public.is_admin()
  ) with check (
    user_id = public.own_app_user_id() or public.is_admin()
  );
create policy "reviews_delete_own" on public.reviews
  for delete using (
    user_id = public.own_app_user_id() or public.is_admin()
  );

-- ---------------------------------------------------------------------------
-- Storage: foto alat publik, bukti bayar terbatas.
-- equipment-images: baca publik (tetap), upload untuk login, ubah/hapus
-- hanya admin (sebelumnya semua user login boleh ubah/hapus).
-- payment-proofs: upload untuk login, baca untuk login (pemilik/admin).
-- BATASAN YANG MASIH TERBUKA: path bukti bayar saat ini
-- `payments/pay_<timestamp>.<ext>` tidak mengandung id pemilik, jadi
-- policy storage tidak bisa membedakan pemilik dari user login lain.
-- Sampai path diubah ke `payments/<app_user_id>/...` dan aplikasi memakai
-- signed URL, user login lain yang menebak nama file masih bisa
-- membukanya. Jangan anggap bukti bayar sepenuhnya privat sebelum itu.
-- ---------------------------------------------------------------------------
drop policy if exists "equipment_images_storage_update_auth" on storage.objects;
create policy "equipment_images_storage_update_admin" on storage.objects
  for update using (
    bucket_id = 'equipment-images' and public.is_admin()
  ) with check (
    bucket_id = 'equipment-images' and public.is_admin()
  );
drop policy if exists "equipment_images_storage_delete_auth" on storage.objects;
create policy "equipment_images_storage_delete_admin" on storage.objects
  for delete using (
    bucket_id = 'equipment-images' and public.is_admin()
  );

drop policy if exists "payment_proofs_storage_all_auth" on storage.objects;
create policy "payment_proofs_storage_insert_auth" on storage.objects
  for insert with check (
    bucket_id = 'payment-proofs' and auth.role() = 'authenticated'
  );
create policy "payment_proofs_storage_read_auth" on storage.objects
  for select using (
    bucket_id = 'payment-proofs'
    and (auth.role() = 'authenticated' or public.is_admin())
  );
create policy "payment_proofs_storage_delete_admin" on storage.objects
  for delete using (
    bucket_id = 'payment-proofs' and public.is_admin()
  );

-- ---------------------------------------------------------------------------
-- Verifikasi sesudah jalan di SQL Editor:
--   select tablename, policyname, cmd from pg_policies
--    where schemaname = 'public' order by tablename, cmd;
--   select public.available_stock(1, current_date, current_date + 3);
--   select public.cancel_expired_bookings();
-- Harus ada policy *_own / *_admin di atas, dan available_stock
-- mengembalikan angka (bukan error).
-- ============================================================================
