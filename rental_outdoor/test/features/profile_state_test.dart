import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/core/supabase/supabase_service.dart';
import 'package:rental_outdoor/features/auth/domain/user.dart';
import 'package:rental_outdoor/features/auth/presentation/auth_controller.dart';
import 'package:rental_outdoor/features/profile/data/profile_repository.dart';
import 'package:rental_outdoor/features/profile/domain/user_profile.dart';
import 'package:rental_outdoor/features/profile/presentation/profile_controller.dart';

void main() {
  test('state profil berubah mengikuti user yang login', () async {
    final auth = _FakeAuthController();
    final repository = _FakeProfileRepository();

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => auth),
        profileRepositoryProvider.overrideWith((ref) => repository),
      ],
    );
    addTearDown(container.dispose);

    // Profil tetap hidup selama test (autoDispose).
    final subscription = container.listen(profileProvider, (_, __) {});
    addTearDown(subscription.close);

    // 1. Belum login -> tidak ada profil.
    expect(await container.read(profileProvider.future), isNull);

    // 2. Login user 1 -> GET /user/profile untuk user 1.
    repository.currentUserId = 1;
    await auth.signInAs(_user(id: 1, name: 'Akun Satu'));

    final first = await container.read(profileProvider.future);
    expect(first, isNotNull);
    expect(first!.id, 1);
    expect(first.name, 'Akun Satu');

    // 3. Logout -> state profil akun lama dibuang, bukan tertinggal.
    await auth.signOut();
    expect(await container.read(profileProvider.future), isNull);

    // 4. Login akun lain -> state harus profil akun baru.
    repository.currentUserId = 2;
    await auth.signInAs(_user(id: 2, name: 'Akun Dua'));

    final second = await container.read(profileProvider.future);
    expect(second, isNotNull);
    expect(second!.id, 2);
    expect(second.name, 'Akun Dua');

    // Profil selalu diambil ulang per user (bukan respons login).
    expect(repository.fetchedForUserIds, <int?>[1, 2]);
  });

  test('profil tetap null saat sesi berakhir', () async {
    final auth = _FakeAuthController();
    final repository = _FakeProfileRepository();

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => auth),
        profileRepositoryProvider.overrideWith((ref) => repository),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(profileProvider, (_, __) {});
    addTearDown(subscription.close);

    // 1. Sesi awal: belum login -> tidak ada profil.
    expect(await container.read(authControllerProvider.future), isNull);
    expect(await container.read(profileProvider.future), isNull);

    repository.currentUserId = 1;
    await auth.signInAs(_user(id: 1, name: 'Akun Satu'));
    expect(await container.read(profileProvider.future), isNotNull);

    await auth.signOut();
    expect(await container.read(profileProvider.future), isNull);

    // Tidak ada GET /user/profile yang jalan tanpa sesi.
    expect(repository.fetchedForUserIds, <int?>[1]);
  });
}

User _user({required int id, required String name}) => User(
      id: id,
      email: 'user$id@test.com',
      name: name,
      role: 'customer',
    );

/// AuthController tiruan: tanpa jaringan, state diatur langsung oleh test.
class _FakeAuthController extends AuthController {
  @override
  Future<User?> build() async => null;

  Future<void> signInAs(User user) async {
    state = AsyncData(user);
  }

  Future<void> signOut() async {
    state = const AsyncData<User?>(null);
  }
}

/// Repository profil tiruan: mengembalikan profil sesuai user aktif.
class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository() : super(SupabaseService());

  int? currentUserId;
  final List<int?> fetchedForUserIds = <int?>[];

  @override
  Future<UserProfile> getProfile() {
    final id = currentUserId;
    fetchedForUserIds.add(id);
    return Future<UserProfile>.value(
      UserProfile(
        id: id ?? 0,
        email: 'user$id@test.com',
        name: id == 1 ? 'Akun Satu' : 'Akun Dua',
        phone: '0812000000$id',
        role: 'customer',
        isActive: true,
      ),
    );
  }
}
