import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/catalog_filter.dart';

/// Filter katalog aktif (pencarian, kategori, harga, urutan).
///
/// Dipakai Beranda (set kategori saat chip diketuk), Katalog (semua
/// kontrol), dan [equipmentListProvider] (watch -> muat ulang halaman 1).
final catalogFilterProvider =
    NotifierProvider<CatalogFilterController, CatalogFilter>(
  CatalogFilterController.new,
);

class CatalogFilterController extends Notifier<CatalogFilter> {
  @override
  CatalogFilter build() => const CatalogFilter();

  /// Kata kunci pencarian (debounce 500 ms dilakukan di halaman Katalog).
  void setSearch(String value) => state = state.copyWith(search: value);

  void setCategory(int? categoryId) =>
      state = state.copyWith(categoryId: categoryId);

  /// Terapkan rentang harga dari bottom sheet. Kedua nilai wajib dikirim
  /// bersama; `null` = tanpa batas sisi itu.
  void setPriceRange({required int? minPrice, required int? maxPrice}) =>
      state = state.copyWith(minPrice: minPrice, maxPrice: maxPrice);

  /// Hapus kedua batas harga.
  void clearPriceRange() =>
      setPriceRange(minPrice: null, maxPrice: null);

  void setSort(String sort) {
    if (!EquipmentSort.values.contains(sort)) return;
    state = state.copyWith(sort: sort);
  }

  void reset() => state = const CatalogFilter();
}
