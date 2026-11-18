import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog_repository.dart';
import '../domain/category.dart';

/// Daftar kategori (`GET /categories`).
///
/// Data publik (bukan per-user) sehingga TIDAK didaftarkan di pengamat
/// sesi. Sengaja bukan autoDispose: kategori kecil dan jarang berubah,
/// cukup muat sekali per sesi (refresh manual lewat pull-to-refresh /
/// tombol coba lagi).
final categoriesProvider =
    AsyncNotifierProvider<CategoriesController, List<Category>>(
  CategoriesController.new,
);

class CategoriesController extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() =>
      ref.read(catalogRepositoryProvider).getCategories();
}
