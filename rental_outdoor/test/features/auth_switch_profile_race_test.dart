import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/core/network/api_client.dart';
import 'package:rental_outdoor/core/network/api_exception.dart';
import 'package:rental_outdoor/core/network/api_providers.dart';
import 'package:rental_outdoor/core/supabase/supabase_service.dart';
import 'package:rental_outdoor/core/storage/token_storage.dart';
import 'package:rental_outdoor/features/auth/data/auth_repository.dart';
import 'package:rental_outdoor/features/auth/domain/auth_session.dart';
import 'package:rental_outdoor/features/auth/domain/user.dart';
import 'package:rental_outdoor/features/auth/presentation/auth_controller.dart';
import 'package:rental_outdoor/features/profile/data/profile_repository.dart';
import 'package:rental_outdoor/features/profile/domain/user_profile.dart';
import 'package:rental_outdoor/features/profile/presentation/profile_controller.dart';

/// Skenario paling dekat dengan bug nyata:
/// - `AuthController` ASLI (login/logout asli, bukan fake state)
/// - pengamat sesi ASLI seperti di aplikasi (router: refresh + invalidate
///   provider per-user ketika sesi berubah)
/// - response `GET /user/profile` akun A masih melayang (jaringan lambat)
/// - sesi berganti ke akun B
///
/// Dulu `ref.invalidate(profileProvider)` ada di dalam `AuthController` dan
/// melempar `CircularDependencyError` (profileProvider me-watch sesi ->
/// ia dependen auth), sehingga invalidasi TIDAK PERNAH terjalan dan
/// `login()`/`logout()` mati di tengah jalan. Test ini gagal bila itu kembali.
void main() {
  test('login B setelah logout A: tidak ada error + profil = B', () async {
    final env = _Env();
    addTearDown(env.container.dispose);
    await env.ready;

    // 1. login akun A
    await env.auth.login(email: 'a@test.com', password: 'password');
    expect(await env.storage.read(), 'tokenA');

    // 2. buka profil -> GET /user/profile (token A) mulai, lambat (100ms)
    final sub = env.container.listen(profileProvider, (_, __) {});
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(env.profileRepo.requested, <String>['tokenA']);

    // 3. logout lalu login B, sementara request A masih melayang.
    //    Tidak boleh melempar (dulu: CircularDependencyError).
    await env.auth.logout();
    expect(await env.storage.read(), isNull);
    await env.auth.login(email: 'b@test.com', password: 'password');
    expect(await env.storage.read(), 'tokenB');

    // 4. beri waktu semua response selesai (B: 20ms, A: 100ms)
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final profile = await env.container.read(profileProvider.future);
    expect(
      profile?.email,
      'b@test.com',
      reason: 'response lambat milik akun A tidak boleh menimpa profil B '
          '(permintaan: ${env.profileRepo.requested})',
    );
    expect(profile?.name, 'Akun B');
    expect(env.profileRepo.requested.last, 'tokenB');
  });

  test('profil selalu diambil ulang dengan token terbaru setelah ganti sesi',
      () async {
    final env = _Env();
    addTearDown(env.container.dispose);
    await env.ready;

    await env.auth.login(email: 'a@test.com', password: 'password');
    final subA = env.container.listen(profileProvider, (_, __) {});
    expect((await env.container.read(profileProvider.future))?.email,
        'a@test.com');
    subA.close();

    await env.auth.logout();
    await env.auth.login(email: 'b@test.com', password: 'password');

    final subB = env.container.listen(profileProvider, (_, __) {});
    addTearDown(subB.close);
    final profile = await env.container.read(profileProvider.future);

    expect(profile?.email, 'b@test.com');
    expect(profile?.name, 'Akun B');
    expect(env.profileRepo.requested, <String>['tokenA', 'tokenB']);
  });
}

// ---------------------------------------------------------------------------
// Lingkungan test: token storage memori + repository tiruan + pengamat sesi
// yang meniru wiring aplikasi (lihat core/router/app_router.dart).
// ---------------------------------------------------------------------------
class _Env {
  _Env() {
    container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        apiClientProvider.overrideWithValue(ApiClient(tokenStorage: storage)),
        authRepositoryProvider.overrideWithValue(authRepo),
        profileRepositoryProvider.overrideWithValue(profileRepo),
      ],
    );
    container.listen(authControllerProvider, (_, __) {
      // Pengamat sesi (peran routerProvider): refresh redirect + buang
      // data per-user. `container.invalidate` tidak memicu pemeriksaan
      // CircularDependencyError (itu khusus `Ref.invalidate` di dalam
      // provider).
      container.invalidate(profileProvider);
    });
  }

  /// Selesai memulihkan sesi awal (harus ditunggu sebelum drive login).
  Future<User?> get ready => container.read(authControllerProvider.future);

  late final ProviderContainer container;
  final _MemTokenStorage storage = _MemTokenStorage();
  late final _FakeAuthRepo authRepo = _FakeAuthRepo(storage);
  late final _FakeProfileRepo profileRepo = _FakeProfileRepo(storage);

  AuthController get auth =>
      container.read(authControllerProvider.notifier);
}

// ---------------------------------------------------------------------------
class _MemTokenStorage extends TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async {
    _token = token;
  }

  @override
  Future<void> delete() async {
    _token = null;
  }
}

/// Repository auth tiruan: menulis token seperti aslinya (lewat storage).
class _FakeAuthRepo extends AuthRepository {
  _FakeAuthRepo(this.storage) : super(SupabaseService());

  final TokenStorage storage;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final token = email == 'a@test.com' ? 'tokenA' : 'tokenB';
    await storage.write(token);
    return AuthSession(token: token, user: _userForEmail(email));
  }

  @override
  Future<User> me() async {
    final token = await storage.read();
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'Sesi berakhir.');
    }
    return _userForEmail(token == 'tokenA' ? 'a@test.com' : 'b@test.com');
  }

  @override
  Future<void> logout() => storage.delete();
}

/// Repository profil tiruan: MENJAWAB SESUAI TOKEN yang dibaca dari storage
/// (meniru interceptor) dengan jeda — akun A lambat, akun B cepat.
class _FakeProfileRepo extends ProfileRepository {
  _FakeProfileRepo(this.storage) : super(SupabaseService());

  final TokenStorage storage;

  /// Token yang dibawa setiap permintaan, berurutan.
  final List<String> requested = <String>[];

  @override
  Future<UserProfile> getProfile() async {
    final token = await storage.read();
    requested.add(token ?? '-');

    if (token == 'tokenA') {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return _profile(id: 1, email: 'a@test.com', name: 'Akun A');
    }
    if (token == 'tokenB') {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return _profile(id: 2, email: 'b@test.com', name: 'Akun B');
    }
    throw ApiException(statusCode: 401, message: 'Token tidak valid.');
  }
}

User _userForEmail(String email) => email == 'a@test.com'
    ? const User(id: 1, email: 'a@test.com', name: 'Akun A', role: 'customer')
    : const User(
        id: 2,
        email: 'b@test.com',
        name: 'Akun B',
        role: 'customer',
      );

UserProfile _profile({
  required int id,
  required String email,
  required String name,
}) =>
    UserProfile(
      id: id,
      email: email,
      name: name,
      phone: '0800000000',
      role: 'customer',
      isActive: true,
    );
