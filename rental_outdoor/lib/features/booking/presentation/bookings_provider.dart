import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../catalog/domain/pagination.dart';
import '../data/booking_repository.dart';
import '../domain/booking.dart';

/// Filter status daftar pesanan (`null` = Semua).
///
/// Nilai = ENUM status server; `rejected` sengaja tidak dipakai alur
/// server sehingga hanya ada di badge cadangan.
final bookingsFilterProvider =
    NotifierProvider.autoDispose<BookingsFilterController, String?>(
  BookingsFilterController.new,
);

class BookingsFilterController extends Notifier<String?> {
  @override
  String? build() => null;

  void setStatus(String? status) => state = status;
}

/// State daftar pesanan (halaman 1 + akumulasi infinite scroll).
class BookingsListState {
  const BookingsListState({
    required this.items,
    required this.pagination,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<Booking> items;
  final Pagination pagination;
  final bool loadingMore;
  final String? loadMoreError;

  bool get hasMore => pagination.hasNextPage;

  BookingsListState copyWith({
    List<Booking>? items,
    Pagination? pagination,
    bool? loadingMore,
    String? loadMoreError,
  }) =>
      BookingsListState(
        items: items ?? this.items,
        pagination: pagination ?? this.pagination,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: loadMoreError,
      );
}

/// Daftar pesanan user yang sedang login (`GET /bookings`).
///
/// - **autoDispose** + `ref.watch(currentUserIdProvider)`: daftar selalu
///   milik user yang login dan dibuang saat tidak ditonton.
/// - `ref.watch(bookingsFilterProvider)`: ganti chip status -> muat ulang
///   halaman 1.
/// - Invalidasi sesi dilakukan di pengamat sesi `routerProvider`.
final bookingsListProvider =
    AsyncNotifierProvider.autoDispose<BookingsController, BookingsListState>(
  BookingsController.new,
);

class BookingsController extends AsyncNotifier<BookingsListState> {
  /// Nomor generasi request — hasil [loadMore] yang basi (filter berubah /
  /// user berganti) dibuang.
  int _generation = 0;

  @override
  Future<BookingsListState> build() async {
    final userId = ref.watch(currentUserIdProvider);
    final status = ref.watch(bookingsFilterProvider);
    _generation++;

    if (userId == null) {
      return BookingsListState(
        items: const [],
        pagination: Pagination.empty(),
      );
    }

    final page = await ref.read(bookingRepositoryProvider).getBookings(
          status: status,
          page: 1,
        );
    return BookingsListState(items: page.items, pagination: page.pagination);
  }

  /// Muat halaman berikutnya (dipanggil listener scroll).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;

    final generation = _generation;
    state = AsyncData(current.copyWith(loadingMore: true));

    try {
      final next = await ref.read(bookingRepositoryProvider).getBookings(
            status: ref.read(bookingsFilterProvider),
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
