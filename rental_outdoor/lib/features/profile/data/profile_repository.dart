import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/utils/image_upload.dart';
import '../../../core/utils/image_url.dart';
import '../domain/user_profile.dart';

/// Profil dari Supabase.
///
/// - `getProfile` baca `public.users` lewat sesi Supabase Auth.
/// - Foto profil diunggah ke bucket `equipment-images`, folder
///   `profiles/`, dan disimpan sebagai path `uploads/profiles/<file>`
///   supaya `resolveImageUrl` memetakannya ke URL storage.
/// - Ganti password lewat Supabase Auth (`updateUser`). Password
///   lama TIDAK diverifikasi oleh Supabase di endpoint ini, jadi
///   parameter `oldPassword` diterima demi kompatibilitas UI tapi
///   tidak dipakai. Bila konfirmasi email aktif, link reset dikirim
///   ke email.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseServiceProvider)),
);

class ProfileRepository {
  ProfileRepository(this._sb);

  final SupabaseService _sb;

  Future<UserProfile> getProfile() async {
    final row = await _sb.requireUserRow();
    return _toProfile(row);
  }

  Future<UserProfile> updateProfile({
    required String name,
    required String phone,
    String? address,
  }) async {
    final row = await _sb.requireUserRow();
    final updated = await _sb.guard(
      () => _sb.client
          .from('users')
          .update({
            'name': name.trim(),
            'phone': phone.trim(),
            'address': (address ?? '').trim().isEmpty ? null : address!.trim(),
          })
          .eq('id', row['id'])
          .select()
          .single(),
    );
    return _toProfile(updated);
  }

  /// Unggah foto profil baru (maks 2 MB, jpg/png/webp).
  /// Mengembalikan `{ profile_image, profile_image_url }`.
  Future<Map<String, dynamic>> updateImage(XFile file) async {
    final bytes = await file.readAsBytes();
    final validationError = _validateImage(bytes, file.name);
    if (validationError != null) {
      throw ApiException(statusCode: 400, message: validationError);
    }
    final mime = detectMimeFromBytes(bytes) ?? 'image/jpeg';
    final extension = extensionFromMime(mime);
    final row = await _sb.requireUserRow();
    final fileName =
        '${row['id']}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _sb.uploadBytes(
      bucket: 'equipment-images',
      path: 'profiles/$fileName',
      bytes: bytes,
      contentType: mime,
    );
    final updated = await _sb.guard(
      () => _sb.client
          .from('users')
          .update({'profile_image': 'uploads/profiles/$fileName'})
          .eq('id', row['id'])
          .select()
          .single(),
    );
    final profile = _toProfile(updated);
    return {
      'profile_image': profile.profileImage,
      'profile_image_url': profile.profileImageUrl,
    };
  }

  /// Ganti password Supabase Auth. Password lama tidak diverifikasi
  /// oleh Supabase di endpoint ini (lihat komentar di atas kelas).
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _sb.guard(
      () => _sb.client.auth.updateUser(
        UserAttributes(password: newPassword),
      ),
    );
  }

  String? _validateImage(List<int> bytes, String filename) {
    final dot = filename.lastIndexOf('.');
    final extension =
        dot < 0 ? '' : filename.substring(dot + 1).toLowerCase();
    if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      return 'Format gambar tidak didukung. Gunakan JPG, PNG, atau WEBP.';
    }
    if (bytes.isEmpty) {
      return 'File gambar kosong atau gagal dibaca. Pilih gambar lain.';
    }
    if (bytes.length > 2 * 1024 * 1024) {
      return 'Ukuran gambar melebihi batas 2 MB. Kompres gambar Anda terlebih dahulu.';
    }
    return null;
  }

  UserProfile _toProfile(Map<String, dynamic> row) {
    final map = Map<String, dynamic>.from(row);
    map['profile_image_url'] = resolveImageUrl(
      map['profile_image'] as String?,
    );
    return UserProfile.fromJson(map);
  }
}
