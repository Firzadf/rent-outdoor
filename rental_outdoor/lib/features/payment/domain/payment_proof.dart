import 'package:flutter/foundation.dart' show Uint8List;

/// Aturan file bukti pembayaran (`POST /payments`, API_DOCS.md bagian 8):
/// maksimal 5 MB (`MAX_FILE_SIZE`), hanya `jpg/png/webp`.
///
/// Di server validasi memakai MIME via `finfo`; di client memakai
/// ekstensi nama file + panjang byte.
const int maxPaymentProofBytes = 5 * 1024 * 1024;

/// Ekstensi yang diterima (huruf kecil, tanpa titik).
const Set<String> paymentProofExtensions = {'jpg', 'jpeg', 'png', 'webp'};

/// Ekstensi nama file dalam huruf kecil; `''` bila tidak ada titik.
String paymentProofExtension(String filename) {
  final name = filename.trim();
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

/// MIME yang benar untuk `MultipartFile.fromBytes(contentType: ...)`.
String paymentProofMediaType(String filename) =>
    switch (paymentProofExtension(filename)) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg', // jpg / jpeg
    };

/// Validasi bukti bayar SEBELUM dikirim.
///
/// - Tipe: `jpg` / `jpeg` / `png` / `webp` (dari ekstensi nama file).
/// - Ukuran: tidak kosong dan maksimal [maxPaymentProofBytes] —
///   dicek dari PANJANG BYTES hasil `XFile.readAsBytes()`, bukan
///   metadata.
///
/// Hasil `null` bila lolos, selain itu pesan ramah untuk pengguna.
String? validatePaymentProof({
  required Uint8List bytes,
  required String filename,
}) {
  final extension = paymentProofExtension(filename);
  if (!paymentProofExtensions.contains(extension)) {
    return 'Format gambar tidak didukung. Gunakan JPG, PNG, atau WEBP.';
  }
  if (bytes.isEmpty) {
    return 'File gambar kosong atau gagal dibaca. Pilih gambar lain.';
  }
  if (bytes.length > maxPaymentProofBytes) {
    final megabytes = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
    return 'Ukuran gambar $megabytes MB melebihi batas 5 MB. '
        'Kompres gambar Anda terlebih dahulu.';
  }
  return null;
}
