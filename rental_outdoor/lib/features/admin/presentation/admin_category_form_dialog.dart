import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_button.dart';
import '../../catalog/domain/category.dart';
import '../data/admin_repository.dart';

/// Dialog tambah/ubah kategori.
class AdminCategoryFormDialog extends ConsumerStatefulWidget {
  const AdminCategoryFormDialog({super.key, this.category});

  final Category? category;

  @override
  ConsumerState<AdminCategoryFormDialog> createState() =>
      _AdminCategoryFormDialogState();
}

class _AdminCategoryFormDialogState
    extends ConsumerState<AdminCategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _iconController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _descriptionController.text = widget.category!.description ?? '';
      _iconController.text = widget.category!.icon ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      if (widget.category == null) {
        await ref.read(adminRepositoryProvider).createCategory(
              name: _nameController.text,
              description: _descriptionController.text,
              icon: _iconController.text,
            );
      } else {
        await ref.read(adminRepositoryProvider).updateCategory(
              widget.category!.id,
              name: _nameController.text,
              description: _descriptionController.text,
              icon: _iconController.text,
            );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Nama kategori wajib diisi';
    if (name.length < 3) return 'Nama minimal 3 karakter';
    if (name.length > 100) return 'Nama maksimal 100 karakter';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;

    return AlertDialog(
      title: Text(isEdit ? 'Ubah Kategori' : 'Tambah Kategori'),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Kategori',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.next,
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Deskripsi (opsional)',
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _iconController,
                decoration: InputDecoration(
                  labelText: 'Ikon (opsional)',
                  prefixIcon: const Icon(Icons.emoji_emotions_outlined),
                  helperText: 'Nama ikon dekoratif, mis. "tent"',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
        AppButton(
          label: isEdit ? 'Simpan Perubahan' : 'Tambah',
          loading: _saving,
          onPressed: _save,
          expanded: false,
        ),
      ],
    );
  }
}
