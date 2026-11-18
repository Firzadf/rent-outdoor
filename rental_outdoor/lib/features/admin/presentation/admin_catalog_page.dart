import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../catalog/domain/category.dart';
import '../../catalog/domain/equipment.dart';
import '../data/admin_repository.dart';
import 'admin_category_form_dialog.dart';
import 'admin_equipment_form_page.dart';
import 'admin_providers.dart';

/// Tab Katalog Admin — kelola alat dan kategori.
class AdminCatalogPage extends ConsumerStatefulWidget {
  const AdminCatalogPage({super.key});

  @override
  ConsumerState<AdminCatalogPage> createState() => _AdminCatalogPageState();
}

class _AdminCatalogPageState extends ConsumerState<AdminCatalogPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _searchQuery = '';
  int? _selectedCategoryId;
  bool _deletingCategory = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Alat'),
            Tab(text: 'Kategori'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEquipmentsTab(),
          _buildCategoriesTab(),
        ],
      ),
    );
  }

  Widget _buildEquipmentsTab() {
    final equipments = ref.watch(adminEquipmentsListProvider);
    final categories = ref.watch(adminCategoriesListProvider);

    return equipments.when(
      loading: () => const LoadingView.list(),
      error: (error, _) => ErrorView(
        message: friendlyErrorMessage(error),
        onRetry: () => ref.invalidate(adminEquipmentsListProvider),
      ),
      data: (items) {
        var filtered = _searchQuery.isEmpty
            ? items
            : items
                .where((e) =>
                    e.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                .toList();

        if (_selectedCategoryId != null) {
          filtered = filtered
              .where((e) => e.categoryId == _selectedCategoryId)
              .toList();
        }

        if (filtered.isEmpty) {
          final emptyWidget = _searchQuery.isEmpty && _selectedCategoryId == null
              ? EmptyView(
                  message: 'Belum ada alat.',
                  action: FilledButton.icon(
                    onPressed: _addEquipment,
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Alat'),
                  ),
                )
              : const EmptyView(
                  message: 'Tidak ada alat yang cocok.',
                  icon: Icons.search_off,
                );
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(adminEquipmentsListProvider),
            child: ListView(children: [emptyWidget]),
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(adminEquipmentsListProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                              decoration: InputDecoration(
                                hintText: 'Cari alat...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _addEquipment,
                            icon: const Icon(Icons.add),
                            label: const Text('Tambah'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      categories.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (cats) => SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: const Text('Semua'),
                                selected: _selectedCategoryId == null,
                                onSelected: (_) =>
                                    setState(() => _selectedCategoryId = null),
                              ),
                              const SizedBox(width: 8),
                              ...cats.map((cat) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(cat.name),
                                      selected:
                                          _selectedCategoryId == cat.id,
                                      onSelected: (_) => setState(() =>
                                          _selectedCategoryId = cat.id),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _equipmentCard(filtered[index]),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _equipmentCard(Equipment equipment) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editEquipment(equipment),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppNetworkImage(
                    equipment.galleryCover,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    cacheVersion: equipment.updatedAt,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipment.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      equipment.categoryName ?? 'Tanpa kategori',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          formatRupiah(equipment.pricePerDay),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '/hari',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Stok: ${equipment.stock}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: equipment.isActive
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  equipment.isActive ? 'Aktif' : 'Nonaktif',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: equipment.isActive
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    final categories = ref.watch(adminCategoriesListProvider);

    return categories.when(
      loading: () => const LoadingView.list(),
      error: (error, _) => ErrorView(
        message: friendlyErrorMessage(error),
        onRetry: () => ref.invalidate(adminCategoriesListProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(adminCategoriesListProvider),
            child: ListView(
              children: [
                EmptyView(
                  message: 'Belum ada kategori.',
                  action: FilledButton.icon(
                    onPressed: _addCategory,
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Kategori'),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(adminCategoriesListProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _addCategory,
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Kategori'),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _categoryCard(items[index]),
                    ),
                    childCount: items.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _categoryCard(Category category) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.category_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle:
            category.description != null ? Text(category.description!) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Ubah',
              onPressed: () => _editCategory(category),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus',
              onPressed: () => _deleteCategory(category),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addEquipment() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminEquipmentFormPage(),
      ),
    );
    if (result == true) {
      refreshAdminCatalog(ref);
    }
  }

  Future<void> _editEquipment(Equipment equipment) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminEquipmentFormPage(equipment: equipment),
      ),
    );
    if (result == true) {
      refreshAdminCatalog(ref, equipmentId: equipment.id);
    }
  }

  Future<void> _addCategory() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const AdminCategoryFormDialog(),
    );
    if (result == true) {
      refreshAdminCatalog(ref);
    }
  }

  Future<void> _editCategory(Category category) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AdminCategoryFormDialog(category: category),
    );
    if (result == true) {
      refreshAdminCatalog(ref);
    }
  }

  Future<void> _deleteCategory(Category category) async {
    if (_deletingCategory) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: Text(
          'Kategori "${category.name}" akan dihapus. '
          'Jika kategori masih dipakai oleh alat, penghapusan akan ditolak server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingCategory = true);
    try {
      await ref.read(adminRepositoryProvider).deleteCategory(category.id);
      if (!mounted) return;
      _showMessage('Kategori berhasil dihapus');
      refreshAdminCatalog(ref);
    } on ApiException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _deletingCategory = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
