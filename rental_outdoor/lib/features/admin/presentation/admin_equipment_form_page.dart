import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../catalog/domain/equipment.dart';
import '../data/admin_repository.dart';
import 'admin_providers.dart';

/// Halaman tambah/ubah alat dengan manajemen gambar.
///
/// Flow tambah:
/// 1. Isi form (required: nama, kategori, harga, stok)
/// 2. Klik Simpan -> POST /admin/equipments, dapat ID
/// 3. Halaman otomatis menampilkan section upload gambar
/// 4. Upload gambar (opsional) dengan image_picker, POST /admin/equipments/{id}/images
/// 5. Tampilkan galeri, tombol hapus gambar, back ke katalog
///
/// Flow ubah:
/// 1. Load detail alat (GET /equipments/{id})
/// 2. Isi form dari data
/// 3. Ubah form, klik Simpan -> PUT /admin/equipments/{id}
/// 4. Tampilkan galeri existing, upload gambar baru, hapus gambar
/// 5. Back ke katalog
class AdminEquipmentFormPage extends ConsumerStatefulWidget {
  const AdminEquipmentFormPage({super.key, this.equipment});

  final Equipment? equipment;

  @override
  ConsumerState<AdminEquipmentFormPage> createState() =>
      _AdminEquipmentFormPageState();
}

class _AdminEquipmentFormPageState
    extends ConsumerState<AdminEquipmentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _depositController = TextEditingController();

  int? _selectedCategoryId;
  bool _isActive = true;
  bool _saving = false;
  bool _uploading = false;
  int? _deletingImageId;
  Equipment? _savedEquipment;

  final _imagePicker = ImagePicker();
  final List<XFile> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    if (widget.equipment != null) {
      _nameController.text = widget.equipment!.name;
      _descriptionController.text = widget.equipment!.description ?? '';
      _priceController.text = widget.equipment!.pricePerDay.toStringAsFixed(0);
      _stockController.text = widget.equipment!.stock.toString();
      _depositController.text = widget.equipment!.deposit.toStringAsFixed(0);
      _selectedCategoryId = widget.equipment!.categoryId;
      _isActive = widget.equipment!.isActive;
      _savedEquipment = widget.equipment;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final price = double.parse(_priceController.text);
      final stock = int.parse(_stockController.text);
      final deposit = _depositController.text.isEmpty
          ? 0.0
          : double.parse(_depositController.text);
      final categoryId = _selectedCategoryId;

      if (categoryId == null) {
        _showError('Pilih kategori terlebih dahulu');
        return;
      }

      if (_savedEquipment == null) {
        // Tambah baru
        final created = await ref.read(adminRepositoryProvider).createEquipment(
              categoryId: categoryId,
              name: name,
              pricePerDay: price,
              stock: stock,
              deposit: deposit > 0 ? deposit : null,
              description: description.isNotEmpty ? description : null,
              isActive: _isActive,
            );
        setState(() => _savedEquipment = created);
        refreshAdminCatalog(ref, equipmentId: created.id);
        _showMessage('Alat berhasil dibuat. Silakan upload gambar (opsional).');
      } else {
        // Ubah
        final updated = await ref.read(adminRepositoryProvider).updateEquipment(
              _savedEquipment!.id,
              categoryId: categoryId,
              name: name,
              pricePerDay: price,
              stock: stock,
              deposit: deposit > 0 ? deposit : null,
              description: description.isNotEmpty ? description : null,
              isActive: _isActive,
            );
        setState(() => _savedEquipment = updated);
        refreshAdminCatalog(ref, equipmentId: updated.id);
        _showMessage('Alat berhasil diperbarui');
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImages() async {
    if (_uploading || _savedEquipment == null) return;

    final files = await _imagePicker.pickMultiImage(
      imageQuality: 85,
    );
    if (files.isEmpty) return;

    setState(() {
      _selectedFiles.addAll(files);
    });
  }

  Future<void> _uploadSelectedImages() async {
    if (_uploading || _savedEquipment == null || _selectedFiles.isEmpty) return;

    setState(() => _uploading = true);
    try {
      await ref.read(adminRepositoryProvider).uploadEquipmentImages(
            _savedEquipment!.id,
            _selectedFiles,
          );
      setState(() => _selectedFiles.clear());
      if (!mounted) return;
      _showMessage('Gambar berhasil diunggah');
      ref.invalidate(adminEquipmentDetailProvider(_savedEquipment!.id));
      refreshAdminCatalog(ref, equipmentId: _savedEquipment!.id);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteImage(int imageId) async {
    if (_deletingImageId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Gambar?'),
        content: const Text('Gambar akan dihapus dari server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingImageId = imageId);
    try {
      await ref.read(adminRepositoryProvider).deleteEquipmentImage(imageId);
      if (!mounted) return;
      _showMessage('Gambar berhasil dihapus');
      if (_savedEquipment != null) {
        ref.invalidate(adminEquipmentDetailProvider(_savedEquipment!.id));
        refreshAdminCatalog(ref, equipmentId: _savedEquipment!.id);
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _deletingImageId = null);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Nama alat wajib diisi';
    if (name.length < 3) return 'Nama minimal 3 karakter';
    if (name.length > 255) return 'Nama maksimal 255 karakter';
    return null;
  }

  String? _validatePrice(String? value) {
    final price = value?.trim() ?? '';
    if (price.isEmpty) return 'Harga wajib diisi';
    final parsed = double.tryParse(price);
    if (parsed == null) return 'Harga harus angka';
    if (parsed < 0) return 'Harga tidak boleh negatif';
    return null;
  }

  String? _validateStock(String? value) {
    final stock = value?.trim() ?? '';
    if (stock.isEmpty) return 'Stok wajib diisi';
    final parsed = int.tryParse(stock);
    if (parsed == null) return 'Stok harus angka bulat';
    if (parsed < 0) return 'Stok tidak boleh negatif';
    return null;
  }

  String? _validateDeposit(String? value) {
    final deposit = value?.trim() ?? '';
    if (deposit.isEmpty) return null; // opsional
    final parsed = double.tryParse(deposit);
    if (parsed == null) return 'Deposit harus angka';
    if (parsed < 0) return 'Deposit tidak boleh negatif';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.equipment != null;
    final hasEquipment = _savedEquipment != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Ubah Alat' : 'Tambah Alat'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildForm(),
                  const SizedBox(height: 24),
                  AppButton(
                    label: isEdit ? 'Simpan Perubahan' : 'Buat Alat',
                    loading: _saving,
                    onPressed: _save,
                  ),
                  if (hasEquipment) ...[
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildGallerySection(),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final categories = ref.watch(adminCategoriesListProvider);

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nama Alat',
              prefixIcon: const Icon(Icons.label_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textInputAction: TextInputAction.next,
            validator: _validateName,
          ),
          const SizedBox(height: 16),
          categories.when(
            loading: () => const SizedBox(
              height: 56,
              child: LoadingView(),
            ),
            error: (error, _) => Text(
              friendlyErrorMessage(error),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            data: (items) => DropdownMenu<int?>(
              expandedInsets: EdgeInsets.zero,
              initialSelection: _selectedCategoryId,
              onSelected: (value) =>
                  setState(() => _selectedCategoryId = value),
              dropdownMenuEntries: [
                const DropdownMenuEntry<int?>(
                  value: null,
                  label: '-- Pilih Kategori --',
                ),
                ...items.map((cat) => DropdownMenuEntry<int?>(
                      value: cat.id,
                      label: cat.name,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _priceController,
            decoration: InputDecoration(
              labelText: 'Harga Sewa Per Hari',
              prefixIcon: const Icon(Icons.attach_money_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            validator: _validatePrice,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _stockController,
            decoration: InputDecoration(
              labelText: 'Stok',
              prefixIcon: const Icon(Icons.inventory_2_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            validator: _validateStock,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _depositController,
            decoration: InputDecoration(
              labelText: 'Deposit (opsional)',
              prefixIcon: const Icon(Icons.card_giftcard_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: 'Jika kosong = 0',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            validator: _validateDeposit,
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
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status Alat',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isActive ? 'Aktif - alat bisa disewa' : 'Nonaktif',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallerySection() {
    return ref.watch(adminEquipmentDetailProvider(_savedEquipment!.id)).when(
          loading: () => const SizedBox(
            height: 120,
            child: LoadingView(),
          ),
          error: (error, _) => ErrorView(
            message: friendlyErrorMessage(error),
            onRetry: () => ref.invalidate(
              adminEquipmentDetailProvider(_savedEquipment!.id),
            ),
          ),
          data: (equipment) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Galeri Gambar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                if (equipment.images.isNotEmpty) ...[
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: equipment.images.length,
                    itemBuilder: (_, i) {
                      final image = equipment.images[i];
                      final deleting = _deletingImageId == image.id;
                      final deleteEnabled = _deletingImageId == null;

                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AppNetworkImage(
                              image.imageUrl,
                              fit: BoxFit.cover,
                              cacheVersion: equipment.updatedAt,
                            ),
                          ),
                          // Tombol hapus SELALU terlihat di pojok foto.
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Material(
                              color: Colors.red.shade700,
                              shape: const CircleBorder(),
                              child: deleting
                                  ? const SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: 'Hapus gambar',
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      padding: EdgeInsets.zero,
                                      iconSize: 18,
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                      ),
                                      onPressed: deleteEnabled
                                          ? () => _deleteImage(image.id)
                                          : null,
                                    ),
                            ),
                          ),
                          if (image.isPrimary)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade700,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Utama',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Belum ada gambar',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_selectedFiles.isNotEmpty) ...[
                  Text(
                    'File yang dipilih (${_selectedFiles.length}):',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_selectedFiles.length, (i) {
                      final file = _selectedFiles[i];
                      return Chip(
                        label: Text(file.name, maxLines: 1),
                        onDeleted: () {
                          setState(() => _selectedFiles.removeAt(i));
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickImages,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Pilih Gambar'),
                      ),
                    ),
                    if (_selectedFiles.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: 'Upload',
                          loading: _uploading,
                          onPressed: _uploadSelectedImages,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        );
  }
}
