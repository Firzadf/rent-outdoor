import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

/// Status sesi aplikasi.
///
/// - `AsyncLoading` -> masih memulihkan sesi.
/// - `AsyncData(null)` -> belum login (atau sesi berakhir).
/// - `AsyncData(User)` -> sudah login.
/// - `AsyncError` -> gagal memulihkan sesi (mis. tidak ada koneksi)
///   + tombol coba lagi.
///
/// Sesi dipegang Supabase Auth, bukan token JWT yang disimpan
/// sendiri seperti di backend PHP lama. `User` di sini hanya data
/// SESI (id, nama, email, role) dari `public.users`. Data profil
/// lengkap selalu diambil dari profil lewat [profileProvider].
///
/// Catatan invalidasi provider per-user: dilakukan di PENGAMAT SESI
/// (`routerProvider`, lihat `core/router/app_router.dart`) — BUKAN di sini.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, User?>(AuthController.new);

/// ID user yang sedang login (`null` bila belum login / sesi berakhir).
///
/// PENTING: semua provider yang datanya per-user (profil, keranjang,
/// pesanan, ulasan, ...) wajib `ref.watch(currentUserIdProvider)`
/// sehingga otomatis dibangun ulang saat user berganti.
final currentUserIdProvider = Provider<int?>(
  (ref) => ref.watch(authControllerProvider).value?.id,
);

class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() => _restoreSession();

  /// Memulihkan sesi saat aplikasi dibuka: bila Supabase Auth
  /// masih punya sesi, ambil profil dari `public.users`.
  /// 401 -> anggap belum login.
  Future<User?> _restoreSession() async {
    try {
      return await ref.read(authRepositoryProvider).me();
    } on ApiException catch (e) {
      if (e.statusCode == 401) return null;
      rethrow; // error jaringan: biarkan splash menampilkan "coba lagi"
    }
  }

  Future<User> login({
    required String email,
    required String password,
  }) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    state = AsyncData(session.user);
    return session.user;
  }

  Future<User> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? address,
  }) async {
    final session = await ref.read(authRepositoryProvider).register(
          email: email,
          password: password,
          name: name,
          phone: phone,
          address: address,
        );
    state = AsyncData(session.user);
    return session.user;
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData<User?>(null);
  }
}
