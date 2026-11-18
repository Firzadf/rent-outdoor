import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

/// Profil lengkap user yang sedang login.
///
/// - **autoDispose**: state dibuang saat tidak ada yang menonton (mis. setelah
///   halaman Profil ditutup), sehingga data akun sebelumnya tidak pernah
///   tertinggal ke akun berikutnya.
/// - **mengamati sesi** lewat `ref.watch(currentUserIdProvider)`: saat user
///   berganti (login / register / logout) provider ini dibangun ulang dan
///   `GET /user/profile` dijalankan ulang untuk user baru.
///
/// Respons `register`/`login` TIDAK pernah dipakai sebagai sumber data
/// profil lengkap — satu-satunya sumber adalah `GET /user/profile`.
final profileProvider =
    AsyncNotifierProvider.autoDispose<ProfileController, UserProfile?>(
  ProfileController.new,
);

class ProfileController extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() {
    // Kunci pengikatan ke sesi: provider ini bergantung pada ID user login.
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      // Tidak ada sesi -> tidak ada profil (state lama ikut dibuang).
      return Future<UserProfile?>.value(null);
    }
    return ref.read(profileRepositoryProvider).getProfile();
  }

  /// `PUT /user/profile` untuk nama / no. HP / alamat.
  Future<void> updateProfile({
    required String name,
    required String phone,
    String? address,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updated = await ref.read(profileRepositoryProvider).updateProfile(
          name: name,
          phone: phone,
          address: address,
        );
    state = AsyncData(updated);
  }

  /// `POST /user/profile/image` — refresh profil setelah sukses.
  Future<void> uploadImage(XFile file) async {
    final current = state.value;
    if (current == null) return;

    await ref.read(profileRepositoryProvider).updateImage(file);

    // Refresh profil lengkap dari server untuk dapat updated_at terbaru.
    final refreshed = await ref.read(profileRepositoryProvider).getProfile();
    state = AsyncData(refreshed);
  }

  /// `PUT /user/change-password`.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) =>
      ref.read(profileRepositoryProvider).changePassword(
            oldPassword: oldPassword,
            newPassword: newPassword,
          );
}
