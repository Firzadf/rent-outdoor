import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/image_upload.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/user_profile.dart';
import 'change_password_dialog.dart';
import 'profile_controller.dart';

/// Halaman profil (tab ke-5 pada StatefulShellRoute).
///
/// Data SELALU dari `GET /user/profile` (lewat [profileProvider]) dan form
/// diisi ulang setiap kali data user berubah — bukan hanya sekali saat
/// widget dibuat. Route memberi `ValueKey('profile-$userId')` sehingga
/// State tidak pernah mempertahankan data akun sebelumnya.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _editing = false;
  bool _saving = false;
  bool _uploading = false;

  /// ID user yang form-nya sedang terisi — berganti user = isi ulang form.
  int? _filledUserId;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Isi controller dari data terbaru.
  ///
  /// - user berganti -> reset mode ubah + isi ulang semua field.
  /// - data diperbarui dan bukan mode ubah -> ikut isi ulang.
  void _syncForm(UserProfile profile) {
    if (_filledUserId != profile.id) {
      _filledUserId = profile.id;
      _editing = false;
    }
    if (!_editing) {
      _emailController.text = profile.email;
      _nameController.text = profile.name;
      _phoneController.text = profile.phone;
      _addressController.text = profile.address ?? '';
    }
  }

  /// Kosongkan form (sesi berakhir / user keluar).
  void _clearForm() {
    _filledUserId = null;
    _editing = false;
    _emailController.clear();
    _nameController.clear();
    _phoneController.clear();
    _addressController.clear();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await ref.read(profileProvider.notifier).updateProfile(
            name: _nameController.text,
            phone: _phoneController.text,
            address: _addressController.text,
          );
      if (!mounted) return;
      setState(() => _editing = false);
      _showMessage('Profil berhasil diperbarui');
    } on ApiException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    if (_uploading) return;

    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    final size = await file.length();
    if (size > AppConstants.maxUploadBytes) {
      _showMessage('Ukuran gambar maksimal 2 MB');
      return;
    }

    setState(() => _uploading = true);
    try {
      await ref.read(profileProvider.notifier).uploadImage(file);
      _showMessage('Foto profil berhasil diperbarui');
    } on ApiException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
    if (changed == true) _showMessage('Password berhasil diubah');
  }

  /// Konfirmasi logout (aksi keluar ada di tab Profil).
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Anda yakin ingin mengakhiri sesi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Nama wajib diisi';
    if (name.length < 3) return 'Nama minimal 3 karakter';
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Nomor HP wajib diisi';
    if (!RegExp(r'^[0-9+\-\s()]+$').hasMatch(phone)) {
      return 'Nomor HP tidak valid';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        actions: [
          // Aksi keluar selalu tampil (termasuk saat profil masih loading).
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: profile.when(
          // Selalu tampilkan loading selama GET /user/profile berjalan,
          // termasuk saat provider dibangun ulang karena user berganti.
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: false,
          loading: () => const LoadingView(message: 'Memuat profil...'),
          error: (error, _) => ErrorView(
            message: friendlyErrorMessage(error),
            onRetry: () => ref.invalidate(profileProvider),
          ),
          data: (data) {
            if (data == null) {
              // Tidak ada sesi -> kosongkan form, tampilkan loading singkat.
              _clearForm();
              return const LoadingView(message: 'Menunggu sesi...');
            }
            _syncForm(data);
            return _buildForm(data);
          },
        ),
      ),
    );
  }

  Widget _buildForm(UserProfile profile) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAvatar(profile),
                const SizedBox(height: 8),
                Text(
                  profile.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  profile.role == 'admin' ? 'Admin' : 'Customer',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                _buildModeBanner(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  readOnly: true,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: _fieldDecoration(
                    label: 'Email',
                    prefixIcon: Icons.mail_outline,
                    helperText: 'Email tidak dapat diubah.',
                    alwaysLocked: true,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  readOnly: !_editing,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration(
                    label: 'Nama lengkap',
                    prefixIcon: Icons.person_outline,
                  ),
                  validator: _validateName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  readOnly: !_editing,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration(
                    label: 'No. HP',
                    prefixIcon: Icons.phone_outlined,
                  ),
                  validator: _validatePhone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  readOnly: !_editing,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  maxLines: 3,
                  decoration: _fieldDecoration(
                    label: 'Alamat',
                    prefixIcon: Icons.home_outlined,
                    helperText: _editing ? null : 'Tekan "Ubah Data Profil" untuk mengubah alamat.',
                  ),
                ),
                const SizedBox(height: 24),
                if (_editing) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _editing = false),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: 'Simpan',
                          loading: _saving,
                          onPressed: _save,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  AppButton(
                    label: 'Ubah Data Profil',
                    icon: Icons.edit_outlined,
                    onPressed: () => setState(() => _editing = true),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _changePassword,
                    icon: const Icon(Icons.lock_reset_outlined),
                    label: const Text('Ganti Password'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _confirmLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Keluar'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Penanda mode: lihat (terkunci) vs ubah (bisa diedit).
  Widget _buildModeBanner() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _editing ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _editing ? Icons.edit_outlined : Icons.visibility_outlined,
            size: 18,
            color: _editing ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _editing
                  ? 'Mode ubah — data bisa diedit, tekan Simpan untuk menyimpan.'
                  : 'Mode lihat — tekan "Ubah Data Profil" untuk mengubah data.',
              style: TextStyle(
                fontSize: 13,
                color: _editing
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dekorasi field: mode lihat = terkunci (gembok, border tenang, warna teks
  /// tetap normal); mode ubah = aktif dengan border fokus utama.
  InputDecoration _fieldDecoration({
    required String label,
    IconData? prefixIcon,
    String? helperText,
    bool alwaysLocked = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final locked = alwaysLocked || !_editing;

    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      helperText: helperText,
      helperMaxLines: 2,
      filled: true,
      fillColor: locked ? scheme.surfaceContainerHighest : scheme.surface,
      suffixIcon: locked
          ? Icon(Icons.lock_outline, size: 18, color: scheme.onSurfaceVariant)
          : null,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: locked ? scheme.outlineVariant : scheme.primary,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: locked ? scheme.outlineVariant : scheme.primary,
          width: locked ? 1 : 2,
        ),
      ),
    );
  }

  Widget _buildAvatar(UserProfile profile) {
    final theme = Theme.of(context);
    final rawUrl = resolveImageUrl(
      profile.profileImageUrl ?? profile.profileImage,
    );
    // Versi cache dari updated_at: foto baru langsung tampil setelah
    // upload tanpa menunggu cache gambar lama kedaluwarsa.
    final url = rawUrl.isEmpty
        ? rawUrl
        : bustCache(rawUrl, version: profile.updatedAt);

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: url.isEmpty
                ? Icon(
                    Icons.person_outline,
                    size: 48,
                    color: theme.colorScheme.onPrimaryContainer,
                  )
                : ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Icon(
                        Icons.person_outline,
                        size: 48,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
          ),
          if (_uploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: theme.colorScheme.secondary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _pickImage,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 18,
                      color: theme.colorScheme.onSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
