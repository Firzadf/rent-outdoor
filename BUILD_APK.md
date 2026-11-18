# BUILD_APK.md — Cara render APK OutdoorRent di laptop

Panduan ini untuk laptop teman user. Mentahan aplikasi sudah jadi di repo
ini (`rental_outdoor/`), tinggal di-build jadi APK. Jangan pakai Flutter
terbaru tanpa nomor versi, baca bagian versi dulu.

Repo: https://github.com/Firzadf/rent-outdoor
Supabase project: rent-outdoor, https://mdpmdjmorihsjsdhvsbn.supabase.co
Dashboard Supabase: https://supabase.com/dashboard/project/mdpmdjmorihsjsdhvsbn

## 1. Versi yang dipakai (dipin, jangan diubah sembarangan)

| Komponen | Versi | Keterangan |
| --- | --- | --- |
| Flutter | **3.32.8** (channel stable) | Dipin eksplisit, lihat alasan di bawah |
| Dart | 3.8.1 (bawaan Flutter 3.32.8) | Sama persis dengan syarat `pubspec.yaml`: Dart `^3.8.1` |
| Gradle | 8.12 | Sudah diatur di `android/gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin (AGP) | 8.7.3 | Sudah diatur di `android/settings.gradle.kts` |
| Java | 17 (Temurin) | Wajib Java 17, bukan Java 8 atau 21 |
| Android SDK | API 35 dan 36, build-tools 35.0.0 / 36.1.0 | Lewat Android Studio, lihat langkah 2 |
| compileSdk / minSdk | 35 / 21 | Dari template, jangan diubah |

### Kenapa Flutter 3.32.8, bukan latest

Flutter terbaru di mesin Muse saat panduan ini ditulis adalah 3.50.0, dan
versi itu **terbukti gagal build APK proyek ini**: GitHub Actions run
44255137153 selesai failure 18 Nov 2026 14:03 WIB, bukan di `flutter
analyze`, tapi di Gradle, error `Plugin org.gradle.kotlin.kotlin-dsl
version 5.1.2 was not found` di file `flutter_tools/gradle/build.gradle.kts`
milik Flutter 3.50.0 sendiri. Jadi jangan pakai `stable` latest atau
3.50.0 untuk proyek ini.

Flutter 3.32.8 dipilih karena toolchain-nya cocok persis dengan template:
Gradle 8.12, AGP 8.7.3, dan Dart 3.8.1 yang sama dengan syarat minimum
`pubspec.yaml`. Itu rilis stabil 25 Juli 2025, patch terakhir dari lini
3.32. Workflow `.github/workflows/build-apk.yml` juga sudah dipin ke
3.32.8, bukan `stable` polos.

Catatan jujur: pin ini dipilih dari kecocokan versi di atas, **bukan dari
hasil build APK yang sukses di mesin Muse**, karena build APK memang
sengaja tidak dijalankan di sana (perintah user 18 Nov 2026 14:03 WIB).
Kalau 3.32.8 ternyata kena error yang sama, laporkan log errornya, lalu
coba cadangan **Flutter 3.35.7 (Dart 3.9.2)**, yang template-nya memakai
Gradle 8.12 dan AGP 8.9.1. Kalau dua-duanya gagal di plugin yang sama,
penyebabnya hampir pasti jaringan ke `plugins.gradle.org` di mesin itu,
bukan kode aplikasi.

## 2. Install di laptop (Windows)

1. Install Git, lalu clone repo ini:
   `git clone https://github.com/Firzadf/rent-outdoor.git`
2. Unduh Flutter SDK **3.32.8** dari arsip rilis Flutter
   (https://docs.flutter.dev/release/archive, cari 3.32.8 Windows),
   extract ke misalnya `C:\flutter`, lalu tambahkan `C:\flutter\bin` ke PATH.
   Jangan `flutter upgrade`, itu akan menaikkan ke latest dan merusak pin.
3. Cek versi, harus keluar 3.32.8 dan Dart 3.8.1:
   `flutter --version`
4. Install Android Studio, lalu di SDK Manager install Android SDK
   Platform API 35 dan 36, dan Android SDK Build-Tools 35.0.0 dan 36.1.0.
   Atau install lewat `sdkmanager` bila sudah paham.
5. Install JDK 17 (Temurin) dan set `JAVA_HOME` ke folder JDK 17 itu.
6. Jalankan `flutter doctor`, pastikan Android toolchain centang hijau.
   Chrome dan Linux toolchain tidak dibutuhkan untuk APK.

## 3. Build APK debug

Dari folder repo:

```bat
cd rent-outdoor\rental_outdoor
flutter pub get
flutter analyze --no-fatal-infos
flutter build apk --debug --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

Hasilnya: `rental_outdoor\build\app\outputs\flutter-apk\app-debug.apk`.

### Anon key Supabase, dari mana

Anon key **jangan** dikarang dan jangan ditulis di file atau chat. Ambil
dari salah satu tempat ini:

- GitHub repo ini, Settings > Secrets and variables > Actions, secret
  `SUPABASE_ANON_KEY` (sudah terpasang 18 Nov 2026 13:55 WIB, dari
  publishable key Supabase, bukan service_role).
- Atau Supabase dashboard project rent-outdoor, Settings > API,
  kolom publishable/anon key.

Bila `--dart-define` tidak diisi, aplikasi tetap bisa dibuka, tapi semua
panggilan Supabase gagal dengan pesan kunci belum diisi. Jangan pakai
service_role key di aplikasi, itu kunci server dan tidak boleh masuk APK.

## 4. Install APK di HP Android

1. Kirim file `app-debug.apk` ke HP (kabel USB, Google Drive, atau WhatsApp).
2. Di HP, buka file APK itu, izinkan `Install dari sumber tidak dikenal`
   untuk aplikasi yang membukanya (Chrome/Files), lalu install.
3. Buka OutdoorRent. Aplikasi memakai internet, jadi HP harus online.

## 5. Akun: daftar baru, akun lama tidak bisa login

Akun uji template lama (`admin@outdoorrent.com`, `customer@test.com`)
**tidak bisa login** di APK ini. Password lama tersimpan sebagai hash
bcrypt di tabel `users`, dan Supabase Auth tidak mengenal hash itu.
Jadi di APK, daftar akun baru lewat halaman Register (email dan password),
lalu login dengan akun itu.

### Membuat akun admin

Setelah daftar akun baru di APK, ubah role-nya di Supabase SQL Editor:

```sql
update public.users set role = 'admin'
where email = 'email-admin@contoh.com';
```

Login ulang, akun itu masuk ke dashboard admin.

### Konfirmasi email

Supaya register langsung bisa login tanpa klik link email, di dashboard
Supabase buka Authentication > Sign in / Providers > Email, lalu
**matikan** konfirmasi email (Confirm email). Bila tetap aktif, user
harus klik link konfirmasi di email dulu sebelum bisa login.

## 6. Migrasi database yang masih harus dijalankan

Migrasi utama `supabase/migrations/20261118000000_outdoorrent_postgres.sql`
sudah live sejak 18 Nov 2026 (9 tabel, data seed terverifikasi). Dua
migrasi susulan **belum dijalankan ke live**, jalankan berurutan di
Supabase SQL Editor project rent-outdoor:

1. `20261118000001_users_insert_policy.sql`: policy INSERT `users`
   supaya register dari APK tidak gagal RLS 403.
2. `20261118000002_harden_rls_stock.sql`: RLS ketat pemilik/admin,
   validasi tanggal dan stok di database, fungsi `available_stock()`,
   dan policy storage baru. Wajib dijalankan sebelum APK dipakai ramai,
   karena tanpa ini semua user login masih bisa membaca/mengubah
   booking orang lain.

Verifikasi sesudah jalan:

```sql
select tablename, policyname, cmd from pg_policies
 where schemaname = 'public' order by tablename, cmd;
select public.available_stock(1, current_date, current_date + 3);
```

## 7. Kalau build gagal

- `Plugin com.android.application 8.7.3 was not found`: Gradle tidak
  bisa mengunduh plugin, cek internet dan proxy. Bukan salah kode
  aplikasi. Coba lagi, atau ganti jaringan.
- `Plugin org.gradle.kotlin.kotlin-dsl ... was not found`: itu error
  Flutter 3.50.0, pastikan `flutter --version` keluar 3.32.8, bukan
  3.50.0. Jangan `flutter upgrade`.
- `Gradle daemon ... could not be connected` atau kehabisan RAM: tutup
  aplikasi berat, lalu `.\gradlew --stop` dari folder `android`,
  dan build ulang. Jangan naikkan `-Xmx` di atas RAM laptop.
- `flutter analyze` keluar info `deprecated_member_use` untuk
  `package:flutter/material.dart`: itu info dari template di Flutter
  3.50, bukan error. Di 3.32.8 info itu tidak ada. Build tetap pakai
  `flutter analyze --no-fatal-infos` supaya info tidak menggagalkan CI.
- APK terinstall tapi login gagal: cek anon key terisi (langkah 3),
  migrasi 00001 sudah dijalankan (langkah 6), dan konfirmasi email
  sudah dimatikan (langkah 5). Foto alat baru tampil setelah file
  diunggah ke bucket `equipment-images` dengan nama yang sama seperti
  path di seed.
