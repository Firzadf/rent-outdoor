import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/utils/image_url.dart';
import '../domain/auth_session.dart';
import '../domain/user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseServiceProvider)),
);

/// Autentikasi lewat Supabase Auth (email + password).
///
/// Perbedaan penting dari backend PHP lama:
/// - Password TIDAK disimpan di tabel `users` lagi; yang memegang
///   password adalah Supabase Auth. Kolom `users.password` diisi
///   penanda `supabase-auth-managed` karena kolom itu NOT NULL di
///   migrasi, dan tidak pernah dipakai untuk login.
/// - Akun uji lama (`admin@outdoorrent.com`, `customer@test.com`)
///   memakai hash bcrypt di tabel `users` dan TIDAK punya akun
///   Supabase Auth, jadi tidak bisa login di APK ini. Daftar akun
///   baru di aplikasi. Untuk akun admin, ubah `role` baris `users`
///   itu jadi `admin` lewat SQL Editor.
/// - Bila konfirmasi email masih aktif di dashboard Supabase,
///   register berhasil tapi sesi belum ada sampai email dikonfirmasi;
///   aplikasi memberitahu itu dengan jelas, bukan diam-diam gagal.
class AuthRepository {
  AuthRepository(this._sb);

  final SupabaseService _sb;

  Future<AuthSession> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? address,
  }) async {
    final auth = _sb.client.auth;
    final response = await _sb.guard(
      () => auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'name': name.trim(),
          'phone': phone.trim(),
        },
      ),
    );
    final session = response.session;
    final authUser = response.user;
    if (session == null || authUser == null) {
      throw ApiException(
        statusCode: 403,
        message:
            'Akun berhasil dibuat. Cek email Anda untuk konfirmasi akun, '
            'lalu login.',
      );
    }
    // Buat baris profil di public.users. Bila gagal karena policy
    // RLS insert belum dijalankan, beri pesan yang menunjuk ke
    // penyebabnya, bukan pesan generik.
    try {
      final row = await _sb.guard(
        () => _sb.client
            .from('users')
            .insert({
              'email': email.trim(),
              'password': 'supabase-auth-managed',
              'name': name.trim(),
              'phone': phone.trim(),
              'address': (address ?? '').trim().isEmpty
                  ? null
                  : address!.trim(),
              'role': 'customer',
              'is_active': true,
              'auth_user_id': authUser.id,
            })
            .select()
            .single(),
      );
      return AuthSession(
        token: session.accessToken,
        user: _userFromRow(row),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        throw ApiException(
          statusCode: 403,
          message:
              'Akun Auth berhasil dibuat, tapi baris profil gagal dibuat '
              'di database (policy RLS insert untuk tabel users belum '
              'dijalankan). Jalankan migrasi follow-up '
              '20261118000001_users_insert_policy.sql di SQL Editor, '
              'lalu login.',
        );
      }
      rethrow;
    }
  }

  /// Login Supabase Auth, lalu ambil profil dari `public.users`.
  /// 401 = kredensial salah, atau profil belum ada.
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _sb.guard(
      () => _sb.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      ),
    );
    final session = response.session;
    if (session == null) {
      throw ApiException(
        statusCode: 401,
        message: 'Email atau password salah.',
      );
    }
    final user = await _meFromAuth();
    return AuthSession(token: session.accessToken, user: user);
  }

  /// Profil user yang sedang login. 401 bila belum login atau
  /// baris profil tidak ada.
  Future<User> me() async {
    if (_sb.client.auth.currentUser == null) {
      throw ApiException(
        statusCode: 401,
        message: 'Sesi berakhir. Silakan login kembali.',
      );
    }
    return _meFromAuth();
  }

  Future<User> _meFromAuth() async {
    final row = await _sb.requireUserRow();
    return _userFromRow(row);
  }

  /// Logout: hapus sesi Supabase Auth.
  Future<void> logout() async {
    await _sb.guard(() => _sb.client.auth.signOut());
  }

  User _userFromRow(Map<String, dynamic> row) {
    final map = Map<String, dynamic>.from(row);
    map['profile_image_url'] = resolveImageUrl(
      map['profile_image'] as String?,
    );
    return User.fromJson(map);
  }
}
