import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../domain/catalog_filter.dart';
import 'catalog_filter_provider.dart';
import 'categories_provider.dart';
import 'equipment_card.dart';
import 'equipment_list_provider.dart';

/// Tab Katalog: pencarian (debounce 500 ms), filter kategori & harga,
/// urutan, grid 2 kolom dengan infinite scroll + pull-to-refresh.
class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  static const _searchDebounce = Duration(milliseconds: 500);

  late final TextEditingController _searchController;
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Sinkronkan kolom pencarian dengan filter yang masih aktif.
    _searchController = TextEditingController(
      text: ref.read(catalogFilterProvider).search,
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Infinite scroll: hampir menyentuh bawah -> muat halaman berikutnya.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      ref.read(equipmentListProvider.notifier).loadMore();
    }
  }

  // ---------------------------------------------------------------------
  // Pencarian: debounce 500 ms (hapus kata kunci langsung diterapkan)
  // ---------------------------------------------------------------------

  void _onSearchChanged(String value) {
    setState(() {}); // sinkronkan tombol hapus
    _debounce?.cancel();

    if (value.trim().isEmpty) {
      _applySearch('');
      return;
    }
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      _applySearch(value);
    });
  }

  void _applySearch(String value) {
    ref.read(catalogFilterProvider.notifier).setSearch(value);
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _applySearch('');
    setState(() {});
  }

  // ---------------------------------------------------------------------
  // Refresh / retry
  // ---------------------------------------------------------------------

  Future<void> _refresh() async {
    ref.invalidate(equipmentListProvider);
    try {
      await ref.read(equipmentListProvider.future);
    } catch (_) {
      // Error sudah tersimpan di state provider dan ditampilkan ErrorView.
    }
  }

  void _retry() => ref.invalidate(equipmentListProvider);

  void _resetAll() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(catalogFilterProvider.notifier).reset();
    setState(() {});
  }

  // ---------------------------------------------------------------------
  // Filter harga (bottom sheet)
  // ---------------------------------------------------------------------

  Future<void> _openPriceFilter() async {
    final current = ref.read(catalogFilterProvider);
    final result = await showModalBottomSheet<(int?, int?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PriceFilterSheet(
        initialMin: current.minPrice,
        initialMax: current.maxPrice,
      ),
    );
    if (result == null || !mounted) return;

    final (min, max) = result;
    ref
        .read(catalogFilterProvider.notifier)
        .setPriceRange(minPrice: min, maxPrice: max);
    setState(() {});
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(catalogFilterProvider);
    final list = ref.watch(equipmentListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Katalog')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchField(),
            _buildCategoryChips(),
            _buildControls(filter),
            const SizedBox(height: 4),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: list.when(
                  // Saat refresh: daftar lama tetap tampil (spinner pull-to-refresh).
                  skipLoadingOnRefresh: true,
                  // Saat filter berubah (reload): tampilkan skeleton.
                  skipLoadingOnReload: false,
                  loading: () => _gridSkeleton(),
                  error: (error, _) => _fullMessage(
                    ErrorView(
                      message: friendlyErrorMessage(error),
                      onRetry: _retry,
                    ),
                  ),
                  data: (data) {
                    if (data.items.isEmpty) {
                      return _fullMessage(
                        EmptyView(
                          message: filter.hasActiveFilter
                              ? 'Alat tidak ditemukan untuk filter ini. Coba ubah pencarian atau filter.'
                              : 'Belum ada alat yang tersedia.',
                          action: filter.hasActiveFilter
                              ? OutlinedButton(
                                  onPressed: _resetAll,
                                  child: const Text('Reset Filter'),
                                )
                              : null,
                        ),
                      );
                    }
                    return _buildGrid(data);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari alat outdoor...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Hapus pencarian',
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// Chip kategori (horizontal): "Semua" + `GET /categories`.
  Widget _buildCategoryChips() {
    final filter = ref.watch(catalogFilterProvider);
    final categories = ref.watch(categoriesProvider);
    final notifier = ref.read(catalogFilterProvider.notifier);

    return SizedBox(
      height: 52,
      child: categories.when(
        loading: () => const _ChipsSkeleton(),
        error: (error, _) => Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kategori gagal dimuat.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton(
                onPressed: () => ref.invalidate(categoriesProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) return const SizedBox.shrink();
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Semua'),
                  selected: filter.categoryId == null,
                  onSelected: (_) => notifier.setCategory(null),
                ),
              ),
              for (final category in items)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category.name),
                    selected: filter.categoryId == category.id,
                    onSelected: (_) => notifier.setCategory(
                      filter.categoryId == category.id ? null : category.id,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Baris kontrol: filter harga (bottom sheet) + urutan + reset.
  Widget _buildControls(CatalogFilter filter) {
    final notifier = ref.read(catalogFilterProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _openPriceFilter,
            icon: const Icon(Icons.tune, size: 18),
            label: Text(filter.hasPriceFilter ? 'Harga (aktif)' : 'Harga'),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sort, size: 18),
              const SizedBox(width: 4),
              Text(
                'Urutkan:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 4),
              DropdownButton<String>(
                value: filter.sort,
                underline: const SizedBox.shrink(),
                isExpanded: false,
                items: [
                  for (final value in EquipmentSort.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(EquipmentSort.label(value)),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  notifier.setSort(value);
                },
              ),
            ],
          ),
          if (filter.hasActiveFilter)
            TextButton(
              onPressed: _resetAll,
              child: const Text('Reset'),
            ),
        ],
      ),
    );
  }

  /// Grid 2 kolom + footer (muat lebih / error muat lebih).
  Widget _buildGrid(EquipmentListState data) {
    final showFooter = data.loadingMore || data.loadMoreError != null;

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final equipment = data.items[index];
                return EquipmentGridCard(
                  equipment: equipment,
                  onTap: () => context.push('/equipment/${equipment.id}'),
                );
              },
              childCount: data.items.length,
            ),
          ),
        ),
        if (showFooter)
          SliverToBoxAdapter(
            child: data.loadMoreError == null
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            data.loadMoreError!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(equipmentListProvider.notifier)
                                .loadMore(),
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  /// Skeleton grid saat memuat halaman pertama / ganti filter.
  Widget _gridSkeleton() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, __) => const ShimmerBox(height: 240),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }

  /// Pesan tengah (empty/error) yang tetap bisa ditarik untuk refresh.
  Widget _fullMessage(Widget child) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: child,
        ),
      ],
    );
  }
}

/// Skeleton chip kategori saat `GET /categories` berjalan.
class _ChipsSkeleton extends StatelessWidget {
  const _ChipsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: const [
        ShimmerBox(width: 72, height: 34, radius: 17),
        SizedBox(width: 8),
        ShimmerBox(width: 96, height: 34, radius: 17),
        SizedBox(width: 8),
        ShimmerBox(width: 84, height: 34, radius: 17),
      ],
    );
  }
}

/// Bottom sheet filter harga minimum/maximum (Rupiah).
class _PriceFilterSheet extends StatefulWidget {
  const _PriceFilterSheet({this.initialMin, this.initialMax});

  final int? initialMin;
  final int? initialMax;

  @override
  State<_PriceFilterSheet> createState() => _PriceFilterSheetState();
}

class _PriceFilterSheetState extends State<_PriceFilterSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  String? _rangeError;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(
      text: widget.initialMin?.toString() ?? '',
    );
    _maxController = TextEditingController(
      text: widget.initialMax?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  String? _validateNumber(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null; // kosong = tanpa batas
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0) return 'Masukkan angka yang valid';
    return null;
  }

  void _apply() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final min = int.tryParse(_minController.text.trim());
    final max = int.tryParse(_maxController.text.trim());
    if (min != null && max != null && min > max) {
      setState(() {
        _rangeError = 'Harga minimum tidak boleh lebih besar dari maksimum.';
      });
      return;
    }
    Navigator.pop(context, (min, max));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filter Harga',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Rentang harga sewa per hari. Kosongkan bila tanpa batas.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _minController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga minimum',
                prefixText: 'Rp ',
                helperText: 'Contoh: 50000',
              ),
              validator: _validateNumber,
              onChanged: (_) => setState(() => _rangeError = null),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _maxController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga maksimum',
                prefixText: 'Rp ',
                helperText: 'Contoh: 200000',
              ),
              validator: _validateNumber,
              onChanged: (_) => setState(() => _rangeError = null),
            ),
            if (_rangeError != null) ...[
              const SizedBox(height: 8),
              Text(
                _rangeError!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, (null, null)),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Text('Terapkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
