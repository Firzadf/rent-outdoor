import 'package:flutter/foundation.dart' show immutable;

/// Nilai `sort` yang valid untuk `GET /equipments` (API_DOCS.md bagian 4).
class EquipmentSort {
  const EquipmentSort._();

  static const String terbaru = 'terbaru';
  static const String termurah = 'termurah';
  static const String terpopuler = 'terpopuler';

  /// Semua nilai yang diterima server (default [terbaru]).
  static const List<String> values = [terbaru, termurah, terpopuler];

  /// Label tampilan (Bahasa Indonesia).
  static String label(String value) => switch (value) {
        termurah => 'Termurah',
        terpopuler => 'Terpopuler',
        _ => 'Terbaru',
      };
}

/// Filter katalog yang dikirim sebagai query `GET /equipments`:
/// `search`, `category_id`, `min_price`, `max_price`, `sort`.
///
/// Nilai disimpan sebagai tipe aman (bukan string mentah input) supaya
/// query selalu sesuai kontrak API.
@immutable
class CatalogFilter {
  const CatalogFilter({
    this.search = '',
    this.categoryId,
    this.minPrice,
    this.maxPrice,
    this.sort = EquipmentSort.terbaru,
  });

  /// Kata kunci pencarian (sudah di-trim; kosong = tanpa pencarian).
  final String search;

  /// Filter kategori (`null` = semua kategori).
  final int? categoryId;

  /// Batas harga minimum/maximum dalam Rupiah (`null` = tanpa batas).
  final int? minPrice;
  final int? maxPrice;

  /// Salah satu dari [EquipmentSort.values].
  final String sort;

  bool get hasPriceFilter => minPrice != null || maxPrice != null;

  bool get hasActiveFilter =>
      search.isNotEmpty || categoryId != null || hasPriceFilter;

  static const Object _unset = Object();

  CatalogFilter copyWith({
    String? search,
    Object? categoryId = _unset,
    Object? minPrice = _unset,
    Object? maxPrice = _unset,
    String? sort,
  }) =>
      CatalogFilter(
        search: search ?? this.search,
        // `null` adalah nilai yang SAH (menghapus filter), jadi pakai
        // penanda `_unset` terpisah dari `null`.
        categoryId: identical(categoryId, _unset)
            ? this.categoryId
            : categoryId as int?,
        minPrice: identical(minPrice, _unset) ? this.minPrice : minPrice as int?,
        maxPrice: identical(maxPrice, _unset) ? this.maxPrice : maxPrice as int?,
        sort: sort ?? this.sort,
      );

  @override
  bool operator ==(Object other) =>
      other is CatalogFilter &&
      other.search == search &&
      other.categoryId == categoryId &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(search, categoryId, minPrice, maxPrice, sort);
}
