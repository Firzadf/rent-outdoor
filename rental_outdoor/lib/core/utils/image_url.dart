import '../config/constants.dart';

/// Gabungkan URL/path gambar ke URL yang bisa dibuka aplikasi.
///
/// Sumber gambar sekarang Supabase Storage, bukan folder `uploads/`
/// di server PHP lama. Path seed dari database masih memakai bentuk
/// lama (`uploads/equipments/x.jpg`), jadi dipetakan ke bucket:
///
/// - `uploads/equipments/<file>` -> bucket `equipment-images`
/// - `uploads/profiles/<file>` -> bucket `equipment-images`, folder `profiles/`
/// - `uploads/payments/<file>` -> bucket `payment-proofs`
///
/// Catatan: file gambar seed belum ada di bucket (folder `uploads/`
/// di template kosong), jadi URL-nya terbentuk benar tapi gambar
/// baru tampil setelah file diunggah ke bucket dengan nama yang sama.
/// Bukti bayar ada di bucket privat `payment-proofs`, jadi URL publik
/// di bawah ini hanya bisa dibuka bila bucket diubah jadi publik
/// atau diganti signed URL; itu dicatat sebagai batasan, bukan
/// disembunyikan.
///
/// - Berawalan `http://` / `https://` -> dikembalikan apa adanya.
String resolveImageUrl(String? path) {
  final raw = path?.trim();
  if (raw == null || raw.isEmpty) return '';
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

  final base = AppConstants.storageBaseUrl;
  if (raw.startsWith('uploads/equipments/')) {
    final file = raw.substring('uploads/equipments/'.length);
    return '$base/equipment-images/$file';
  }
  if (raw.startsWith('uploads/profiles/')) {
    final file = raw.substring('uploads/profiles/'.length);
    return '$base/equipment-images/profiles/$file';
  }
  if (raw.startsWith('uploads/payments/')) {
    final file = raw.substring('uploads/payments/'.length);
    return '$base/payment-proofs/$file';
  }
  if (raw.startsWith('uploads/')) {
    final file = raw.substring('uploads/'.length);
    return '$base/equipment-images/$file';
  }
  if (raw.startsWith('equipments/')) {
    return '$base/equipment-images/${raw.substring('equipments/'.length)}';
  }
  if (raw.startsWith('payments/')) {
    return '$base/payment-proofs/${raw.substring('payments/'.length)}';
  }
  if (raw.startsWith('profiles/')) {
    return '$base/equipment-images/$raw';
  }
  return raw;
}
