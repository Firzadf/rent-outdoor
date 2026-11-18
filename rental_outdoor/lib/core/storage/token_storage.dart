import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan token JWT (aman) + cache in-memory supaya interceptor
/// tidak perlu menunggu I/O setiap request.
///
/// Urutan yang dijamin:
/// - [write]: cache MEMORI dulu (`_cache`), baru storage.
/// - [delete]: cache memori dibuang dulu, baru storage.
/// - [read]: interceptor selalu memanggil ini di SETIAP request, jadi token
///   yang terkirim selalu nilai terbaru — bukan salinan yang disimpan di
///   header default dio.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'auth_token';

  final FlutterSecureStorage _storage;
  String? _cache;
  bool _readOnce = false;

  /// Baca token tersimpan (`null` bila belum pernah login / sudah logout).
  Future<String?> read() async {
    if (_readOnce) return _cache;
    try {
      _cache = await _storage.read(key: _key);
    } catch (_) {
      _cache = null;
    }
    _readOnce = true;
    return _cache;
  }

  /// Simpan token baru (dipanggil saat login/register sukses).
  Future<void> write(String token) async {
    // Cache memori dulu supaya request berikutnya langsung memakai token baru
    // bahkan sebelum I/O storage selesai.
    _cache = token;
    _readOnce = true;
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {
      // Gagal menulis ke storage aman tidak boleh menjatuhkan sesi.
    }
  }

  /// Hapus token (logout / sesi kedaluwarsa 401).
  Future<void> delete() async {
    _cache = null;
    _readOnce = true;
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Aman diabaikan.
    }
  }
}
