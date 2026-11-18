import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/error_view.dart';
import '../data/catalog_repository.dart';
import '../domain/equipment.dart';
import '../domain/pagination.dart';
import 'catalog_filter_provider.dart';

/// State daftar katalog (halaman 1 + akumulasi infinite scroll).
class EquipmentListState {
  const EquipmentListState({
    required this.items,
    required this.pagination,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<Equipment> items;
  final Pagination pagination;

  /// Masih ada permintaan halaman berikutnya.
  final bool loadingMore;

  /// Pesan ramah bila muat halaman berikutnya gagal (footer coba lagi).
  final String? loadMoreError;

  bool get hasMore => pagination.hasNextPage;

  EquipmentListState copyWith({
    List<Equipment>? items,
    Pagination? pagination,
    bool? loadingMore,
    String? loadMoreError,
  }) =>
      EquipmentListState(
        items: items ?? this.items,
        pagination: pagination ?? this.pagination,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: loadMoreError,
      );
}

/// Daftar alat `GET /equipments` + filter + infinite scroll.
///
/// - `build` me-watch [catalogFilterProvider]: setiap perubahan filter
///   (pencarian debounce, kategori, harga, urutan) memuat ulang halaman 1.
/// - [loadMore] mengambil `pagination.page + 1` dan menyambung daftarnya.
/// - Bukan autoDispose: state daftar tetap hidup saat berpindah tab
///   (IndexedStack) supaya tidak memuat ulang tiap kali.
final equipmentListProvider =
    AsyncNotifierProvider<EquipmentListController, EquipmentListState>(
  EquipmentListController.new,
);

class EquipmentListController extends AsyncNotifier<EquipmentListState> {
  /// Nomor generasi request — hasil [loadMore] yang basi (filter berubah
  /// atau provider dibangun ulang di tengah jalan) dibuang.
  int _generation = 0;

  @override
  Future<EquipmentListState> build() async {
    // Filter berubah -> muat ulang dari halaman 1.
    ref.watch(catalogFilterProvider);
    _generation++;

    final page = await ref.read(catalogRepositoryProvider).getEquipments(
          filter: ref.read(catalogFilterProvider),
          page: 1,
        );
    return EquipmentListState(items: page.items, pagination: page.pagination);
  }

  /// Muat halaman berikutnya (dipanggil dari listener scroll).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;

    final generation = _generation;
    state = AsyncData(current.copyWith(loadingMore: true));

    try {
      final next = await ref.read(catalogRepositoryProvider).getEquipments(
            filter: ref.read(catalogFilterProvider),
            page: current.pagination.nextPage,
          );
      if (!ref.mounted || generation != _generation) return;

      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(
          items: [...latest.items, ...next.items],
          pagination: next.pagination,
          loadingMore: false,
          loadMoreError: null,
        ),
      );
    } on ApiException catch (e) {
      if (!ref.mounted || generation != _generation) return;
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(latest.copyWith(loadingMore: false, loadMoreError: e.message));
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(
          loadingMore: false,
          loadMoreError: friendlyErrorMessage(e),
        ),
      );
    }
  }
}
