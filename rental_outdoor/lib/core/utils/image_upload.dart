import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

/// Helper upload gambar — deteksi MIME dari byte awal (bukan ekstensi),
/// validasi ukuran, bangun filename dengan ekstensi sesuai MIME.
///
/// Tanpa dart:io File sehingga berfungsi di web.

/// Deteksi MIME dari byte awal file.
///
/// - JPEG: FF D8 FF
/// - PNG: 89 50 4E 47
/// - WEBP: "RIFF" (4 byte) + "WEBP" di offset 8
///
/// Mengembalikan null bila format tidak dikenali.
String? detectMimeFromBytes(Uint8List bytes) {
  if (bytes.length < 4) return null;

  // JPEG: FF D8 FF
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return 'image/jpeg';
  }

  // PNG: 89 50 4E 47
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }

  // WEBP: "RIFF" (52 49 46 46) + "WEBP" (57 45 42 50) di offset 8
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }

  return null;
}

/// Ekstensi dari MIME.
String extensionFromMime(String mime) {
  switch (mime) {
    case 'image/jpeg':
      return 'jpg';
    case 'image/png':
      return 'png';
    case 'image/webp':
      return 'webp';
    default:
      return 'jpg';
  }
}

/// Buat MultipartFile dari XFile untuk upload gambar profil/alat.
///
/// Validasi:
/// - MIME dari byte awal (bukan ekstensi)
/// - Ukuran maksimal 2 MB
/// - Hanya JPEG/PNG/WEBP
///
/// Filename dibangun ulang dengan ekstensi sesuai MIME hasil deteksi.
/// Melempar String bila validasi gagal.
Future<MultipartFile> createImageMultipartFile(
  XFile file, {
  int maxBytes = 2 * 1024 * 1024, // 2 MB default
}) async {
  final bytes = await file.readAsBytes();

  // Validasi ukuran
  if (bytes.isEmpty) {
    throw 'File kosong. Pilih gambar lain.';
  }
  if (bytes.length > maxBytes) {
    final maxMB = (maxBytes / (1024 * 1024)).toStringAsFixed(0);
    throw 'Ukuran gambar maksimal $maxMB MB.';
  }

  // Deteksi MIME dari byte awal
  final mime = detectMimeFromBytes(bytes);
  if (mime == null) {
    throw 'Format gambar tidak valid. Hanya JPEG, PNG, dan WEBP yang diterima.';
  }

  // Bangun filename dengan ekstensi sesuai MIME
  final ext = extensionFromMime(mime);
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final filename = 'upload_$timestamp.$ext';

  return MultipartFile.fromBytes(
    bytes,
    filename: filename,
    contentType: MediaType.parse(mime),
  );
}

/// Buat MultipartFile dari XFile untuk upload bukti bayar.
///
/// Sama seperti [createImageMultipartFile] tapi ukuran maksimal 5 MB.
Future<MultipartFile> createPaymentProofMultipartFile(XFile file) =>
    createImageMultipartFile(file, maxBytes: 5 * 1024 * 1024);

/// Cache-buster: tambah query parameter version ke URL gambar.
///
/// Contoh: `bustCache('http://localhost/uploads/x.jpg', 'v1')` → 
/// `http://localhost/uploads/x.jpg?v=v1`
///
/// Bila URL sudah punya query, gunakan `&`.
/// Bila version null, gunakan timestamp.
String bustCache(String url, {String? version}) {
  if (url.isEmpty) return url;

  final v = version?.isNotEmpty == true ? version : DateTime.now().millisecondsSinceEpoch.toString();
  final separator = url.contains('?') ? '&' : '?';
  return '$url${separator}v=$v';
}
