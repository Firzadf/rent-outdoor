import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/error_view.dart';
import '../data/catalog_repository.dart';
import '../domain/pagination.dart';
import '../domain/review.dart';

/// State daftar ulasan (halaman 1 + infinite scroll).
class ReviewsListState {
  const ReviewsListState({
    required this.items,
    required this.pagination,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<Review> items;
  final Pagination pagination;
  final bool loadingMore;
  final String? loadMoreError;

  bool get hasMore => pagination.hasNextPage;

  ReviewsListState copyWith({
    List<Review>? items,
    Pagination? pagination,
    bool? loadingMore,
    String? loadMoreError,
  }) =>
      ReviewsListState(
        items: items ?? this.items,
        pagination: pagination ?? this.pagination,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: loadMoreError,
      );
}

/// Semua ulasan alat `GET /equipments/{id}/reviews?page=&limit=`
/// dengan paginasi. Family per alat, autoDispose.
///
/// Data publik (bukan ulasan milik user) — tidak perlu invalidasi sesi.
final equipmentReviewsProvider = AsyncNotifierProvider.autoDispose
    .family<EquipmentReviewsController, ReviewsListState, int>(
  EquipmentReviewsController.new,
);

class EquipmentReviewsController extends AsyncNotifier<ReviewsListState> {
  EquipmentReviewsController(this.equipmentId);

  final int equipmentId;

  int _generation = 0;

  @override
  Future<ReviewsListState> build() async {
    _generation++;
    final page = await ref.read(catalogRepositoryProvider).getReviews(
          equipmentId: equipmentId,
          page: 1,
        );
    return ReviewsListState(items: page.items, pagination: page.pagination);
  }

  /// Muat halaman ulasan berikutnya.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;

    final generation = _generation;
    state = AsyncData(current.copyWith(loadingMore: true));

    try {
      final next = await ref.read(catalogRepositoryProvider).getReviews(
            equipmentId: equipmentId,
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
      state = AsyncData(
        latest.copyWith(loadingMore: false, loadMoreError: e.message),
      );
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
