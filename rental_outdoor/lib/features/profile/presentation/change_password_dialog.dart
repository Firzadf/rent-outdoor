import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_button.dart';
import 'profile_controller.dart';

/// Dialog ganti password (`PUT /user/change-password`).
///
/// Menutup diri dengan hasil `true` bila berhasil.
class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscure = true;
  bool _saving = false;
  String? _oldServerError;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _oldServerError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(profileProvider.notifier)
          .changePassword(
            oldPassword: _oldController.text,
            newPassword: _newController.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _oldServerError = e.fieldError('old_password') ?? e.message,
      );
      setState(() => _saving = false);
    }
  }

  String? _validateOld(String? value) {
    if (value == null || value.isEmpty) return 'Password lama wajib diisi';
    return null;
  }

  String? _validateNew(String? value) {
    if (value == null || value.isEmpty) return 'Password baru wajib diisi';
    if (value.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Konfirmasi wajib diisi';
    if (value != _newController.text) return 'Password tidak sama';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ganti Password'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _oldController,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Password lama',
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText: _oldServerError,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: _validateOld,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newController,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Password baru',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
                validator: _validateNew,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  labelText: 'Ulangi password baru',
                  prefixIcon: Icon(Icons.lock_person_outlined),
                ),
                validator: _validateConfirm,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        SizedBox(
          width: 140,
          child: AppButton(
            label: 'Simpan',
            loading: _saving,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}
