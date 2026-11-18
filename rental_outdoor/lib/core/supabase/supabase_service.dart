import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/constants.dart';
import '../network/api_exception.dart';
import '../utils/formatters.dart';

/// Lapisan data Supabase (Auth + PostgREST + Storage).
///
/// Menggantikan [ApiClient] lama yang memanggil backend PHP.
/// Semua repository memakai layanan ini, bukan Dio ke PHP.
///
/// Project: rent-outdoor, https://mdpmdjmorihsjsdhvsbn.supabase.co
/// (Singapore, Free). Tabel sudah dimigrasi dan live sejak 18 Nov 2026.
///
/// Kunci anon TIDAK ada di kode ini. Diisi lewat
/// `--dart-define=SUPABASE_ANON_KEY=...` saat build. Bila kosong,
/// [requireConfigured] melempar [ApiException] yang jelas, supaya APK
/// tidak seolah-olah live padahal belum bisa memanggil Supabase.
/// Jangan pernah memakai service_role key di aplikasi client.
class SupabaseService {
  SupabaseClient get client => Supabase.instance.client;

  bool get isConfigured => AppConstants.supabaseAnonKey.isNotEmpty;

  void requireConfigured() {
    if (!isConfigured) {
      throw ApiException(
        statusCode: 0,
        message:
            'Kunci Supabase belum diisi. Build ulang dengan '
            '--dart-define=SUPABASE_ANON_KEY=<anon-key project rent-outdoor>.',
      );
    }
  }

  User? get authUser => client.auth.currentUser;

  /// Baris `public.users` milik user yang sedang login, dicari lewat
  /// `auth_user_id` dulu, lalu lewat email sebagai fallback.
  /// `null` bila belum login atau baris profil belum ada.
  Future<Map<String, dynamic>?> currentUserRow() async {
    requireConfigured();
    final user = authUser;
    if (user == null) return null;
    return guard(() async {
      final byAuthId = await client
          .from('users')
          .select()
          .eq('auth_user_id', user.id)
          .maybeSingle();
      if (byAuthId != null) return byAuthId;
      if (user.email == null) return null;
      return client
          .from('users')
          .select()
          .eq('email', user.email!)
          .maybeSingle();
    });
  }

  /// Baris profil wajib ada; bila tidak ada, sesi dianggap belum lengkap.
  /// Ini terjadi bila pendaftaran gagal membuat baris `users` (misalnya
  /// policy RLS insert belum dijalankan) atau akun lama dari template
  /// PHP yang tidak punya akun Supabase Auth.
  Future<Map<String, dynamic>> requireUserRow() async {
    final row = await currentUserRow();
    if (row == null) {
      throw ApiException(
        statusCode: 401,
        message:
            'Profil pengguna tidak ditemukan di database. '
            'Daftar akun baru di aplikasi, atau hubungi admin.',
      );
    }
    return row;
  }

  Future<int> requireAppUserId() async {
    final row = await requireUserRow();
    final id = row['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    throw ApiException(
      statusCode: 401,
      message: 'Profil pengguna tidak valid. Silakan login kembali.',
    );
  }

  /// Stok tersedia dari fungsi database `public.available_stock`
  /// (migrasi 20261118000002). Melempar [ApiException] bila fungsi
  /// belum ada di project (migrasi baru belum dijalankan); pemanggil
  /// memakai fallback hitungan client dalam kasus itu.
  Future<int> availableStock({
    required int equipmentId,
    required DateTime pickupDate,
    required DateTime returnDate,
  }) async {
    requireConfigured();
    final result = await guard(
      () => client.rpc('available_stock', params: {
        'p_equipment_id': equipmentId,
        'p_pickup': formatIsoDate(pickupDate),
        'p_return': formatIsoDate(returnDate),
      }),
    );
    if (result is num) return result.toInt();
    throw ApiException(
      statusCode: 0,
      message: 'Fungsi available_stock mengembalikan nilai tak terduga.',
    );
  }

  /// URL publik file di bucket storage.
  /// [path] boleh berupa path storage (`equipments/x.jpg`) atau path
  /// lama template (`uploads/equipments/x.jpg`); awalan `uploads/`
  /// dibuang karena di bucket tidak ada folder `uploads/`.
  String storagePublicUrl(String bucket, String path) {
    var clean = path.trim();
    if (clean.startsWith('uploads/')) {
      clean = clean.substring('uploads/'.length);
    }
    if (clean.startsWith('/')) clean = clean.substring(1);
    return client.storage.from(bucket).getPublicUrl(clean);
  }

  /// Upload byte ke bucket. Mengembalikan path storage yang tersimpan.
  Future<String> uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    requireConfigured();
    return guard(() async {
      await client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return path;
    });
  }

  /// Hapus file dari bucket. Kegagalan diabaikan supaya penghapusan
  /// baris database tidak ikut gagal.
  Future<void> removeFromStorage(String bucket, String path) async {
    try {
      var clean = path.trim();
      if (clean.startsWith('uploads/')) {
        clean = clean.substring('uploads/'.length);
      }
      await client.storage.from(bucket).remove([clean]);
    } catch (_) {
      // Abaikan, lihat komentar di atas.
    }
  }

  /// Jalankan query Supabase dan petakan errornya ke [ApiException].
  Future<T> guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw _fromPostgrest(e);
    } on AuthException catch (e) {
      throw ApiException(
        statusCode: _authStatus(e),
        message: _friendlyAuthMessage(e.message),
      );
    } on StorageException catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Gagal mengunggah file: ${e.message}',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Terjadi kesalahan tak terduga. Coba lagi.',
      );
    }
  }

  ApiException _fromPostgrest(PostgrestException e) {
    // 23505 = duplikat (misalnya ulasan sudah ada untuk booking+alat).
    if (e.code == '23505') {
      return ApiException(
        statusCode: 409,
        message: 'Data sudah ada. Periksa kembali isian Anda.',
      );
    }
    // 42501 = ditolak RLS, PGRST301 = baris tidak ditemukan untuk .single().
    if (e.code == '42501') {
      return ApiException(
        statusCode: 403,
        message: 'Akses ditolak oleh database. Silakan login kembali.',
      );
    }
    if (e.code == 'PGRST116') {
      return ApiException(statusCode: 404, message: 'Data tidak ditemukan.');
    }
    final detail = e.message.trim();
    return ApiException(
      statusCode: 0,
      message: detail.isNotEmpty
          ? 'Gagal memuat data dari server: $detail'
          : 'Gagal memuat data dari server. Coba lagi.',
    );
  }

  int _authStatus(AuthException e) {
    final code = e.statusCode;
    if (code != null) {
      final parsed = int.tryParse(code);
      if (parsed != null) return parsed;
    }
    return 401;
  }

  String _friendlyAuthMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Email atau password salah.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek inbox email Anda, lalu login.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already registered')) {
      return 'Email sudah terdaftar. Silakan login.';
    }
    if (lower.contains('password should be at least')) {
      return 'Password minimal 6 karakter.';
    }
    if (lower.contains('rate limit')) {
      return 'Terlalu banyak percobaan. Coba lagi beberapa saat lagi.';
    }
    return message;
  }
}
