# API Documentation — OutdoorRent (Tahap 2–5)

Dokumen ini ditulis berdasarkan kode sumber yang ada di `api/` (bukan spekulasi).

## Base URL

`http://localhost/outdoorrent/api`

## Bentuk Respons (Envelope)

Semua endpoint mengembalikan JSON dengan format seragam:

```json
{
  "success": true | false,
  "message": "Deskripsi singkat",
  "data": { ... }          // hanya muncul jika tidak null
}
```

- `data` tidak dikirim sama sekali bila tidak ada payload (mis. `DELETE` sukses).
- Kode HTTP yang dipakai: `200` OK, `201` Created, `400` Bad Request, `401` Unauthorized,
  `403` Forbidden, `404` Not Found, `409` Conflict, `422` Validation Error, `500` Server Error.
- Error validasi (422) berbentuk:
  ```json
  {
    "success": false,
    "message": "pickup_date is required",
    "data": { "pickup_date": ["pickup_date is required"] }
  }
  ```

## Autentikasi & Role

Header: `Authorization: Bearer <token_jwt>` (JWT HS256, berlaku 24 jam).

| Role | Keterangan |
|---|---|
| Publik | Tanpa token |
| Auth | Token apa pun (customer/admin), akun harus `is_active = 1` |
| Customer | `role = customer` |
| Admin | `role = admin` |

Login dan middleware menolak akun `is_active = 0` dengan `403`.

## Tipe Angka: Number vs String

Kolom bertipe `DECIMAL` di MySQL dan hasil agregasi `SUM()` MySQL **dikembalikan sebagai string**.

**String (harus di-cast di client bila perlu):**

- Harga/dana: `price_per_day`, `deposit`, `subtotal`, `deposit_total`, `late_fee`,
  `damage_fee`, `deposit_refund`, `grand_total`, `amount`
- Lainnya: `rating_avg`, `item_count` (admin bookings), `total_rentals` (top_equipments),
  `pending_orders` + `revenue` (laporan revenue), `total_quantity` + `revenue` (laporan alat)
- `id` pada respons `POST /admin/equipments/{id}/images` (hasil `lastInsertId()`)

Contoh: `"price_per_day": "75000.00"`, `"item_count": "2"`.

**Number (int/float):**

- Semua `id` hasil SELECT ulang (`user_id`, `booking_id`, `equipment_id`, …) → int
- `quantity`, `stock`, `total_days`, `total_reviews`, `total_bookings`, `is_active`,
  `is_primary`, `sort_order`, `rating`, `late_days`
- `pagination.total`, `pagination.page`, `pagination.limit` → int
- `pagination.total_pages` → number (hasil `ceil()`)
- `total_orders`, `pending_verification_count`, `active_rentals_count`, `total_revenue`
  (sudah di-cast di server) → number
- `orders`, `bookings_count` (`COUNT(*)`) → number
- Pada respons `complete`: `late_fee`, `damage_fee`, `deposit_refund` → number (float PHP),
  **berbeda** dengan field `late_fee` dll. di dalam objek `booking` yang tetap string (kolom DB)

**Boolean:** `is_available`, `success`.

Catatan: dua format bisa muncul dalam satu respons yang sama. Contoh pada
`PUT /admin/bookings/{id}/complete`: `data.late_fee` = `150000` (number) sedangkan
`data.booking.late_fee` = `"150000.00"` (string).

## Upload Gambar

| Endpoint | Field | Maks | Folder |
|---|---|---|---|
| `POST /admin/equipments/{id}/images` | `images[]` (boleh banyak) | 2 MB/file | `uploads/equipments/` |
| `POST /user/profile/image` | `image` (1 file) | 2 MB | `uploads/profiles/` |
| `POST /payments` | `payment_proof` (1 file) | 5 MB (`MAX_FILE_SIZE`) | `uploads/payments/` |

Aturan sama untuk ketiganya: hanya `jpg/png/webp`, MIME divalidasi via `finfo`
(bukan ekstensi), nama file random, path relatif yang disimpan di database
(`uploads/...`), URL lengkap dibangun oleh `Helper::getImageUrl()` saat respons.
Folder `uploads/` punya `.htaccess` yang mematikan eksekusi PHP.

## Status Booking & Alur Transisi

Nilai ENUM: `pending_payment`, `pending_verification`, `confirmed`, `in_use`,
`completed`, `cancelled`, `rejected`.

```
pending_payment
  ├─ customer POST /payments ──────────────► pending_verification
  ├─ lewat auto_cancel_at ─────────────────► cancelled   (reason: "Auto-cancel: pembayaran melewati batas waktu")
  └─ customer PUT /bookings/{id}/cancel ───► cancelled

pending_verification
  ├─ admin verify action=approve ──────────► confirmed
  ├─ admin verify action=reject (belum lewat auto_cancel_at)
  │                                         ► pending_verification  (tetap; payment terakhir = rejected,
  │                                            customer boleh upload ulang via POST /payments)
  ├─ admin verify action=reject (sudah lewat auto_cancel_at) ► cancelled
  └─ customer PUT /bookings/{id}/cancel ───► cancelled

confirmed
  └─ admin PUT /admin/bookings/{id}/start ─► in_use    (total_bookings tiap alat bertambah)

in_use
  └─ admin PUT /admin/bookings/{id}/complete ► completed

completed   — terminal, ulasan boleh dibuat
cancelled   — terminal
rejected    — ada di ENUM schema, TIDAK dipakai oleh alur kode saat ini
```

`auto_cancel_at` = waktu pembuatan + 24 jam (`AUTO_CANCEL_HOURS`). Pengecekan
auto-cancel dijalankan di: cron `cron/auto_cancel.php`, lazy saat `GET /bookings`,
dan lazy saat `GET /admin/bookings`.

## Aturan Hitung (dihitung selalu di server, tidak pernah dipercaya dari client)

**Saat POST /bookings** (harga & deposit diambil dari database, dikunci `SELECT ... FOR UPDATE`):

- `total_days` = `return_date - pickup_date` dalam hari, tanpa +1, minimal 1
- `subtotal` per item = `price_per_day × quantity × total_days`
- `subtotal` total = Σ subtotal item
- `deposit_total` = Σ (`deposit × quantity`)
- `grand_total` = `subtotal + deposit_total`
- `booking_code` unik format `OR-YYYYMMDD-XXXX`, `status = pending_payment`
- Duplikat `equipment_id` dalam satu booking ditolak
- Tanggal lampau / `return_date <= pickup_date` ditolak

**Stok per tanggal** (`GET /equipments/{id}/availability` dan saat booking):

- `available_stock` = `stock - SUM(quantity)` booking berstatus
  `pending_payment, pending_verification, confirmed, in_use` yang overlap:
  `b.pickup_date <= :return_date AND b.return_date >= :pickup_date`

**Saat PUT /admin/bookings/{id}/complete:**

- `late_days` = `max(0, actual_return_date - return_date)` dalam hari —
  dihitung server dari `actual_return_date` (default hari ini), `late_days` dari
  client tidak pernah diterima
- `late_fee` = Σ (`quantity × price_per_day × 0.5 × late_days`) dari `booking_items`
- `damage_fee` = input client, wajib dan tidak negatif hanya saat
  `return_condition = damaged`; selain itu dipaksa `0`
- `deposit_refund`:
  - `good` → `max(0, deposit_total - late_fee)`
  - `damaged` → `max(0, deposit_total - damage_fee - late_fee)`
  - `lost` → `0`

---

# 1. Health Check (Publik)

### GET `/`

```json
{
  "success": true,
  "message": "OutdoorRent API is running",
  "data": {
    "name": "OutdoorRent API",
    "version": "1.0.0",
    "timestamp": "2026-10-08 18:00:00",
    "timezone": "Asia/Jakarta"
  }
}
```

---

# 2. Autentikasi (Publik kecuali disebut lain)

### POST `/auth/register` — Publik

Field: `email` (wajib, format email), `password` (wajib, min 6), `name` (wajib, min 3),
`phone` (wajib, format telepon), `address` (opsional).

`201`:
```json
{
  "success": true,
  "message": "Registration successful",
  "data": {
    "token": "eyJhbGci...",
    "user": { "id": 4, "email": "a@b.com", "name": "Nama", "role": "customer" }
  }
}
```
`409` bila email sudah terdaftar.

### POST `/auth/login` — Publik

Field: `email`, `password`.

```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "token": "eyJhbGci...",
    "user": { "id": 2, "email": "customer@test.com", "name": "John Doe", "role": "customer", "is_active": 1 }
  }
}
```
`401` kredensial salah, `403` akun nonaktif.

### GET `/auth/me` — Auth

```json
{
  "success": true,
  "message": "User profile retrieved",
  "data": { "id": 2, "email": "customer@test.com", "name": "John Doe", "role": "customer", "is_active": 1 }
}
```

---

# 3. Kategori

### GET `/categories` — Publik

`data` = array kategori:
```json
[
  { "id": 1, "name": "Tenda", "description": "...", "icon": "tent",
    "created_at": "...", "updated_at": "..." }
]
```

### GET `/categories/{id}` — Publik

`data` = satu objek kategori (field sama seperti di atas).

### POST `/admin/categories` — Admin

Field: `name` (wajib, 3–100), `description` (opsional), `icon` (opsional). `201`, `data` = objek kategori.

### PUT `/admin/categories/{id}` — Admin

Field sama seperti POST. `data` = objek kategori setelah update.

### DELETE `/admin/categories/{id}` — Admin

Tanpa `data`. `409` bila masih dipakai alat: `"Cannot delete category with existing equipments"`.

---

# 4. Alat (Equipment)

### GET `/equipments` — Publik

Query: `search`, `category_id`, `min_price`, `max_price`,
`sort` (`termurah` | `terpopuler` | `terbaru`, default `terbaru`), `page`, `limit` (maks 100).

```json
{
  "success": true,
  "message": "Equipments retrieved successfully",
  "data": {
    "equipments": [
      {
        "id": 1, "category_id": 1,
        "name": "Tenda Kapasitas 4 Orang", "description": "...",
        "price_per_day": "75000.00", "stock": 10, "deposit": "300000.00",
        "rating_avg": "0.00", "total_reviews": 0, "total_bookings": 0,
        "is_active": 1, "created_at": "...", "updated_at": "...",
        "category_name": "Tenda",
        "primary_image_url": "http://localhost/outdoorrent/uploads/equipments/tent-4person.jpg"
      }
    ],
    "pagination": { "total": 12, "page": 1, "limit": 10, "total_pages": 2 }
  }
}
```
`primary_image_url` bisa `null` bila alat belum punya gambar.

### GET `/equipments/popular` — Publik

Query: `limit` (1–20, default 6). `data` = array alat (field sama seperti di atas,
termasuk `category_name` dan `primary_image_url`), tanpa pagination.

### GET `/equipments/{id}` — Publik

```json
{
  "success": true,
  "message": "Equipment retrieved successfully",
  "data": {
    "id": 1, "category_id": 1, "name": "...", "price_per_day": "75000.00",
    "stock": 10, "deposit": "300000.00", "rating_avg": "0.00",
    "total_reviews": 0, "total_bookings": 0, "is_active": 1,
    "category_name": "Tenda",
    "images": [
      { "id": 1, "equipment_id": 1,
        "image_url": "http://localhost/outdoorrent/uploads/equipments/tent-4person.jpg",
        "is_primary": 1, "sort_order": 0, "created_at": "..." }
    ],
    "reviews": [
      { "id": 1, "booking_id": 1, "user_id": 2, "equipment_id": 1,
        "rating": 5, "comment": "...", "created_at": "...", "updated_at": "...",
        "user_name": "John Doe", "profile_image": "uploads/profiles/x.jpg" }
    ]
  }
}
```
- `images[].image_url` selalu URL lengkap.
- `reviews` = maksimal 5 ulasan terbaru; `profile_image` di sini **masih path relatif**
  (belum dikonversi oleh kode saat ini), bisa `null`.

### POST `/admin/equipments` — Admin

Field: `category_id` (wajib, int > 0), `name` (wajib, 3–255),
`price_per_day` (wajib, numerik > 0), `stock` (wajib, int, tidak boleh negatif),
`deposit` (opsional, tidak boleh negatif), `description`, `is_active` (opsional). `201`, `data` = objek alat.

### PUT `/admin/equipments/{id}` — Admin

Field sama seperti POST. `data` = objek alat setelah update.

### DELETE `/admin/equipments/{id}` — Admin

Soft delete (`is_active = 0`). Tanpa `data`.

### POST `/admin/equipments/{id}/images` — Admin (form-data)

Field `images[]` (file, boleh lebih dari satu), maks 2 MB/file, jpg/png/webp.

`201`:
```json
{
  "success": true,
  "message": "Images uploaded successfully",
  "data": [
    { "id": "12", "image_url": "http://localhost/outdoorrent/uploads/equipments/equip_x.jpg", "is_primary": 1 }
  ]
}
```
(`id` berupa string — hasil `lastInsertId()`.)

### DELETE `/admin/equipments/images/{id}` — Admin

`{id}` = id gambar **bukan** alat. Tanpa `data`. File ikut dihapus dari disk.

---

# 5. Profil Pengguna (Auth)

### GET `/user/profile` — Auth

```json
{
  "success": true,
  "message": "Profile retrieved successfully",
  "data": {
    "id": 2, "email": "customer@test.com", "name": "John Doe",
    "phone": "0812...", "address": "...", "profile_image": "uploads/profiles/x.jpg",
    "role": "customer", "is_active": 1, "created_at": "...", "updated_at": "...",
    "profile_image_url": "http://localhost/outdoorrent/uploads/profiles/x.jpg"
  }
}
```
`profile_image_url` hanya muncul bila `profile_image` terisi.

### PUT `/user/profile` — Auth

Field: `name` (wajib, 3–255), `phone` (opsional, format telepon), `address` (opsional).
`data` = objek profil (sama seperti GET).

### POST `/user/profile/image` — Auth (form-data)

Field `image` (file, maks 2 MB, jpg/png/webp). Profil image lama dihapus dari disk.

```json
{
  "success": true,
  "message": "Profile image updated successfully",
  "data": {
    "profile_image": "uploads/profiles/profile_x.jpg",
    "profile_image_url": "http://localhost/outdoorrent/uploads/profiles/profile_x.jpg"
  }
}
```

### PUT `/user/change-password` — Auth

Field: `old_password` (wajib), `new_password` (wajib, min 6). Tanpa `data`.
`401` bila `old_password` salah.

---

# 6. Ketersediaan (Publik)

### GET `/equipments/{id}/availability?pickup_date=YYYY-MM-DD&return_date=YYYY-MM-DD`

```json
{
  "success": true,
  "message": "Availability checked successfully",
  "data": { "equipment_id": 1, "stock": 10, "booked": 2, "available_stock": 8, "is_available": true }
}
```
Semua field bertipe number. `422` format tanggal salah, `400` `return_date <= pickup_date`,
`404` alat tidak ada/nonaktif.

---

# 7. Booking (Customer)

### POST `/bookings` — Customer

Body JSON:
```json
{
  "pickup_date": "2026-11-01",
  "return_date": "2026-11-03",
  "notes": "Ambil pagi hari",
  "items": [ { "equipment_id": 1, "quantity": 2 } ]
}
```
`201`:
```json
{
  "success": true,
  "message": "Booking created successfully",
  "data": {
    "id": 5, "user_id": 2, "booking_code": "OR-20261008-4576",
    "pickup_date": "2026-11-01", "return_date": "2026-11-03",
    "actual_return_date": null, "total_days": 2,
    "subtotal": "300000.00", "deposit_total": "600000.00",
    "late_fee": "0.00", "damage_fee": "0.00", "deposit_refund": "0.00",
    "grand_total": "900000.00", "status": "pending_payment",
    "notes": "Ambil pagi hari", "cancellation_reason": null,
    "return_condition": null, "return_notes": null,
    "auto_cancel_at": "2026-10-09 13:24:32",
    "created_at": "...", "updated_at": "...",
    "items": [
      { "id": 1, "booking_id": 5, "equipment_id": 1, "quantity": 2,
        "price_per_day": "75000.00", "subtotal": "300000.00",
        "equipment_name": "Tenda Kapasitas 4 Orang" }
    ]
  }
}
```
`400` untuk stok kurang (`"Not enough stock for '...'. Only 8 available on those dates."`),
alat nonaktif, tanggal lampau, `return_date` tidak lebih besar, `equipment_id` duplikat.

### GET `/bookings?status=&page=&limit=` — Customer

Lazy auto-cancel dijalankan sebelum query.
```json
{
  "success": true,
  "message": "Bookings retrieved successfully",
  "data": {
    "bookings": [ { "id": 5, "booking_code": "OR-...", "status": "pending_payment", "...": "kolom bookings" } ],
    "pagination": { "total": 3, "page": 1, "limit": 10, "total_pages": 1 }
  }
}
```
`data.bookings` = kolom mentah tabel `bookings` saja (tanpa items/payments).

### GET `/bookings/{id}` — Customer (hanya milik sendiri; selain itu 404)

```json
{
  "success": true,
  "message": "Booking detail retrieved successfully",
  "data": {
    "id": 5, "booking_code": "OR-...", "status": "pending_verification", "...": "kolom bookings",
    "items": [
      { "equipment_id": 1, "equipment_name": "...", "quantity": 2,
        "primary_image_url": "http://localhost/outdoorrent/uploads/equipments/tent.jpg" }
    ],
    "payments": [
      { "id": 1, "booking_id": 5, "amount": "900000.00",
        "payment_proof": "http://localhost/outdoorrent/uploads/payments/pay_x.png",
        "bank_name": "BCA", "account_name": "...", "account_number": "...",
        "status": "pending", "payment_date": "...", "verified_at": null,
        "verified_by": null, "rejection_reason": null, "created_at": "..." }
    ]
  }
}
```
`items[].primary_image_url` dan `payments[].payment_proof` = URL lengkap.

### PUT `/bookings/{id}/cancel` — Customer

Body: `{ "reason": "..." }` (opsional, default `"Cancelled by customer"`).
Hanya `pending_payment` / `pending_verification`. Tanpa `data`.

---

# 8. Pembayaran (Customer)

### GET `/payments/info` — Publik

```json
{
  "success": true,
  "message": "Payment bank accounts retrieved successfully",
  "data": [
    { "bank_name": "BCA", "account_number": "1234567890", "account_name": "PT OutdoorRent Indonesia" },
    { "bank_name": "Mandiri", "account_number": "0987654321", "account_name": "PT OutdoorRent Indonesia" },
    { "bank_name": "BRI", "account_number": "5555666677778888", "account_name": "PT OutdoorRent Indonesia" }
  ]
}
```

### POST `/payments` — Customer (form-data)

Field: `booking_id` (wajib), `bank_name` (wajib, min 3), `account_name` (wajib, min 3),
`account_number` (wajib, min 5), `payment_proof` (file, maks 5 MB, jpg/png/webp).

`201`:
```json
{
  "success": true,
  "message": "Payment submitted successfully",
  "data": {
    "id": 3, "booking_id": 3, "amount": "3600000.00",
    "payment_proof": "http://localhost/outdoorrent/uploads/payments/pay_x.png",
    "bank_name": "BCA", "account_name": "John Doe", "account_number": "0987654321",
    "status": "pending", "payment_date": "...", "verified_at": null,
    "verified_by": null, "rejection_reason": null, "created_at": "..."
  }
}
```
- `amount` diambil dari `grand_total` booking (server).
- Setelah sukses: payment `pending`, booking → `pending_verification`.
- Ditolak bila: booking bukan milik sendiri (404), status bukan `pending_payment`
  dan bukan `pending_verification` dengan payment terakhir `rejected` (400),
  sudah lewat `auto_cancel_at` (400), file tidak valid (400).

---

# 9. Ulasan

### POST `/reviews` — Customer

Body: `booking_id` (wajib), `equipment_id` (wajib), `rating` (wajib, 1–5), `comment` (opsional).

`201`:
```json
{
  "success": true,
  "message": "Review created successfully",
  "data": { "id": 1, "booking_id": 5, "user_id": 2, "equipment_id": 1,
            "rating": 5, "comment": "...", "created_at": "...", "updated_at": "..." }
}
```
Syarat: booking milik sendiri berstatus `completed`; `equipment_id` bagian dari booking.
`409` bila ulasan untuk (booking, alat) sudah ada. Setelah insert, `rating_avg` dan
`total_reviews` alat dihitung ulang dalam transaction.

### GET `/equipments/{id}/reviews?page=&limit=` — Publik

```json
{
  "success": true,
  "message": "Reviews retrieved successfully",
  "data": {
    "reviews": [
      { "id": 1, "booking_id": 5, "user_id": 2, "equipment_id": 1,
        "rating": 5, "comment": "...", "created_at": "...", "updated_at": "...",
        "reviewer_name": "John Doe" }
    ],
    "pagination": { "total": 1, "page": 1, "limit": 10, "total_pages": 1 }
  }
}
```
Hanya `reviewer_name` (bukan email).

---

# 10. Admin — Kelola Pesanan

Semua memerlukan `role = admin`.

### GET `/admin/bookings?status=&search=&page=&limit=`

`search` mencocokkan `booking_code` atau nama user. Lazy auto-cancel dijalankan dulu.
```json
{
  "success": true,
  "message": "Bookings retrieved successfully",
  "data": {
    "bookings": [
      { "id": 1, "booking_code": "OR-...", "user_id": 2, "status": "pending_verification",
        "grand_total": "900000.00", "created_at": "...",
        "user_name": "John Doe", "user_email": "customer@test.com",
        "item_count": "2" }
    ],
    "pagination": { "total": 4, "page": 1, "limit": 10, "total_pages": 1 }
  }
}
```
`item_count` = string (SUM quantity).

### GET `/admin/bookings/{id}`

Booking lengkap + data user:
```json
{
  "success": true,
  "message": "Booking detail retrieved successfully",
  "data": {
    "id": 1, "booking_code": "OR-...", "status": "pending_verification",
    "user_name": "John Doe", "user_email": "customer@test.com",
    "user_phone": "0812...", "user_address": "...",
    "items": [ { "equipment_id": 1, "equipment_name": "...", "quantity": 2,
                 "primary_image_url": "http://localhost/outdoorrent/uploads/equipments/x.jpg" } ],
    "payments": [ { "id": 1, "payment_proof": "http://localhost/outdoorrent/uploads/payments/y.png",
                    "status": "pending", "...": "kolom payments" } ]
  }
}
```

### PUT `/admin/bookings/{id}/verify`

Body: `{ "action": "approve" }` atau `{ "action": "reject", "rejection_reason": "..." }`.
Syarat: booking `pending_verification` + payment terakhir `pending`.
`rejection_reason` wajib saat `reject`.

```json
{
  "success": true,
  "message": "Payment verification processed successfully",
  "data": {
    "booking_id": 1, "booking_status": "confirmed",
    "payment_id": 1, "payment_status": "approved",
    "payment": { "id": 1, "status": "approved", "verified_at": "...", "verified_by": 1,
                 "rejection_reason": null, "...": "kolom payments" },
    "booking": { "id": 1, "status": "confirmed", "...": "kolom bookings" }
  }
}
```
Saat `reject` dan booking sudah lewat `auto_cancel_at`: `booking_status` = `cancelled`.

### PUT `/admin/bookings/{id}/start`

Tanpa body. Syarat: `confirmed` → `in_use`. `data` = objek booking setelah update.
`total_bookings` setiap alat ikut bertambah sebesar quantity.

### PUT `/admin/bookings/{id}/complete`

Body:
```json
{
  "return_condition": "damaged",
  "return_notes": "Tenda sobek di sisi kanan",
  "damage_fee": 150000,
  "actual_return_date": "2026-11-05"
}
```
- `return_condition` wajib: `good` | `damaged` | `lost`
- `damage_fee` wajib dan tidak negatif hanya saat `damaged` (selain itu dipaksa 0)
- `actual_return_date` opsional (format `YYYY-MM-DD`, default hari ini)
- `return_notes` opsional (maks 1000)
- Syarat status: `in_use` → `completed`

```json
{
  "success": true,
  "message": "Booking completed successfully",
  "data": {
    "booking": { "id": 1, "status": "completed", "return_condition": "damaged",
                 "actual_return_date": "2026-11-05",
                 "late_fee": "150000.00", "damage_fee": "150000.00",
                 "deposit_refund": "300000.00", "...": "kolom bookings" },
    "late_days": 2,
    "late_fee": 150000,
    "damage_fee": 150000,
    "deposit_refund": 300000
  }
}
```

---

# 11. Admin — Dashboard & Laporan

### GET `/admin/dashboard`

```json
{
  "success": true,
  "message": "Dashboard retrieved successfully",
  "data": {
    "total_orders": 4,
    "total_revenue": 1350000,
    "pending_verification_count": 1,
    "active_rentals_count": 1,
    "top_equipments": [
      { "id": 1, "name": "Tenda Kapasitas 4 Orang", "total_rentals": "2" }
    ]
  }
}
```
- `total_orders` = jumlah semua booking.
- `total_revenue` = SUM(`subtotal + late_fee + damage_fee`) booking `completed`.
- `active_rentals_count` = booking `confirmed` atau `in_use`.
- `top_equipments` = 5 alat dengan `SUM(quantity)` terbanyak, booking
  `cancelled`/`rejected` dikecualikan. `total_rentals` berupa string.

### GET `/admin/reports/revenue?start_date=&end_date=&period=daily|monthly`

`period` default `daily`. Berdasarkan tanggal pembuatan booking.
```json
{
  "success": true,
  "message": "Revenue report retrieved successfully",
  "data": {
    "start_date": "2026-10-01", "end_date": "2026-10-31", "period": "daily",
    "rows": [
      { "period": "2026-10-08", "orders": 3, "pending_orders": "1", "revenue": "1350000.00" }
    ]
  }
}
```
`orders` number; `pending_orders`, `revenue` string. `422` tanggal tidak valid/`period` salah.

### GET `/admin/reports/equipments?start_date=&end_date=`

```json
{
  "success": true,
  "message": "Equipment report retrieved successfully",
  "data": {
    "start_date": "2026-10-01", "end_date": "2026-10-31",
    "rows": [
      { "id": 1, "name": "Tenda Kapasitas 4 Orang", "category_name": "Tenda",
        "bookings_count": 2, "total_quantity": "3", "revenue": "450000.00" }
    ]
  }
}
```
`revenue` = SUM(`bi.subtotal`) booking `completed`. `total_quantity`/`revenue` string,
`bookings_count` number.

---

# 12. Admin — Kelola Pengguna

### GET `/admin/users?role=&search=&page=&limit=`

`role` = `customer` | `admin`. `search` mencocokkan nama/email.
```json
{
  "success": true,
  "message": "Users retrieved successfully",
  "data": {
    "users": [
      { "id": 2, "email": "customer@test.com", "name": "John Doe",
        "phone": "0812...", "address": "...", "profile_image": null,
        "role": "customer", "is_active": 1, "created_at": "...", "updated_at": "..." }
    ],
    "pagination": { "total": 3, "page": 1, "limit": 10, "total_pages": 1 }
  }
}
```

### PUT `/admin/users/{id}/toggle-active`

Tanpa body. Toggle `is_active` 0 ↔ 1. `data` = objek user setelah update.
`403` bila admin menonaktifkan akun sendiri (`"You cannot deactivate your own account"`).
Akun nonaktif ditolak saat login (403) dan oleh semua endpoint auth (403).
