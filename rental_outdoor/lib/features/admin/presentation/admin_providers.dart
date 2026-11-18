import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/category.dart';
import '../../catalog/domain/equipment.dart';
import '../../catalog/domain/pagination.dart';
import '../../catalog/presentation/categories_provider.dart';
import '../../catalog/presentation/equipment_list_provider.dart';
import '../data/admin_repository.dart';
import '../domain/admin_booking.dart';
import '../domain/admin_dashboard.dart';

/// Filter status daftar pesanan admin (`null` = Semua).
final adminBookingsFilterProvider =
    NotifierProvider.autoDispose<AdminBookingsFilterController, String?>(
  AdminBookingsFilterController.new,
);

class AdminBookingsFilterController extends Notifier<String?> {
  @override
  String? build() => null;

  void setStatus(String? status) => state = status;
}

/// Kata kunci pencarian (`booking_code` / nama user).
///
/// Debounce 500 ms dilakukan di UI sebelum memanggil [setSearch];
/// perubahan nilai memicu pemuatan ulang halaman 1.
final adminBookingsSearchProvider =
    NotifierProvider.autoDispose<AdminBookingsSearchController, String>(
  AdminBookingsSearchController.new,
);

class AdminBookingsSearchController extends Notifier<String> {
  @override
  String build() => '';

  void setSearch(String value) => state = value;
}

/// State daftar pesanan admin (halaman 1 + akumulasi infinite scroll).
class AdminBookingsListState {
  const AdminBookingsListState({
    required this.items,
    required this.pagination,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<AdminBooking> items;
  final Pagination pagination;
  final bool loadingMore;
  final String? loadMoreError;

  bool get hasMore => pagination.hasNextPage;

  AdminBookingsListState copyWith({
    List<AdminBooking>? items,
    Pagination? pagination,
    bool? loadingMore,
    String? loadMoreError,
  }) =>
      AdminBookingsListState(
        items: items ?? this.items,
        pagination: pagination ?? this.pagination,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: loadMoreError,
      );
}

/// Daftar pesanan admin (`GET /admin/bookings`).
///
/// - **autoDispose** + `ref.watch(currentUserIdProvider)`: daftar selalu
///   milik akun yang login dan dibuang saat tidak ditonton.
/// - Filter status + kata kunci ikut di-watch -> ganti chip / selesai
///   debounce pencarian -> muat ulang halaman 1.
/// - Invalidasi sesi dilakukan di pengamat sesi `routerProvider`.
final adminBookingsListProvider =
    AsyncNotifierProvider.autoDispose<AdminBookingsListController,
        AdminBookingsListState>(
  AdminBookingsListController.new,
);

class AdminBookingsListController
    extends AsyncNotifier<AdminBookingsListState> {
  /// Nomor generasi request — hasil [loadMore] yang basi dibuang.
  int _generation = 0;

  @override
  Future<AdminBookingsListState> build() async {
    final userId = ref.watch(currentUserIdProvider);
    final status = ref.watch(adminBookingsFilterProvider);
    final search = ref.watch(adminBookingsSearchProvider);
    _generation++;

    if (userId == null) {
      return AdminBookingsListState(
        items: const [],
        pagination: Pagination.empty(),
      );
    }

    final page = await ref.read(adminRepositoryProvider).getBookings(
          status: status,
          search: search,
          page: 1,
        );
    return AdminBookingsListState(
      items: page.items,
      pagination: page.pagination,
    );
  }

  /// Muat halaman berikutnya (dipanggil listener scroll).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;

    final generation = _generation;
    state = AsyncData(current.copyWith(loadingMore: true));

    try {
      final next = await ref.read(adminRepositoryProvider).getBookings(
            status: ref.read(adminBookingsFilterProvider),
            search: ref.read(adminBookingsSearchProvider),
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
    } catch (_) {
      if (!ref.mounted || generation != _generation) return;
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(
          loadingMore: false,
          loadMoreError: 'Gagal memuat pesanan berikutnya. Coba lagi.',
        ),
      );
    }
  }
}

/// Ringkasan dashboard admin (`GET /admin/dashboard`).
///
/// autoDispose + `ref.watch(currentUserIdProvider)`; didaftarkan di
/// pengamat sesi `routerProvider`.
final adminDashboardProvider =
    AsyncNotifierProvider.autoDispose<AdminDashboardController, AdminDashboard>(
  AdminDashboardController.new,
);

class AdminDashboardController extends AsyncNotifier<AdminDashboard> {
  @override
  Future<AdminDashboard> build() {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return Future<AdminDashboard>.error(
        ApiException(
          statusCode: 401,
          message: 'Sesi Anda telah berakhir. Silakan login kembali.',
        ),
      );
    }
    return ref.read(adminRepositoryProvider).getDashboard();
  }
}

/// Detail satu pesanan admin (`GET /admin/bookings/{id}`).
///
/// Family per `bookingId`, autoDispose + `ref.watch(currentUserIdProvider)`;
/// didaftarkan di pengamat sesi `routerProvider`.
final adminBookingDetailProvider = AsyncNotifierProvider.autoDispose
    .family<AdminBookingDetailController, AdminBooking, int>(
  AdminBookingDetailController.new,
);

class AdminBookingDetailController extends AsyncNotifier<AdminBooking> {
  AdminBookingDetailController(this.bookingId);

  final int bookingId;

  @override
  Future<AdminBooking> build() {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return Future<AdminBooking>.error(
        ApiException(
          statusCode: 401,
          message: 'Sesi Anda telah berakhir. Silakan login kembali.',
        ),
      );
    }
    return ref.read(adminRepositoryProvider).getBooking(bookingId);
  }
}

/// Muat ulang semua data admin setelah aksi tulis (verifikasi / mulai /
/// selesai) supaya daftar, detail, dan dashboard ikut ter-update.
///
/// Dipanggil dari halaman dengan `WidgetRef` (bukan dari dalam Notifier).
void refreshAdminData(WidgetRef ref, {int? bookingId}) {
  ref.invalidate(adminBookingsListProvider);
  ref.invalidate(adminDashboardProvider);
  if (bookingId != null) ref.invalidate(adminBookingDetailProvider(bookingId));
}

// -------------------------------------------------------------------
// KATALOG ADMIN (Tahap 8B)
// -------------------------------------------------------------------

/// Daftar alat admin (`GET /equipments` dengan role admin, tanpa filter sort).
///
/// autoDispose + `ref.watch(currentUserIdProvider)`.
final adminEquipmentsListProvider = AsyncNotifierProvider.autoDispose<
    AdminEquipmentsListController,
    List<Equipment>>(AdminEquipmentsListController.new);

class AdminEquipmentsListController
    extends AsyncNotifier<List<Equipment>> {
  @override
  Future<List<Equipment>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];

    final page = await ref
        .read(catalogRepositoryProvider)
        .getEquipments(page: 1, limit: 100);
    return page.items;
  }
}

/// Daftar kategori admin (sama seperti publik tapi ada di area admin).
///
/// autoDispose + `ref.watch(currentUserIdProvider)`.
final adminCategoriesListProvider = AsyncNotifierProvider.autoDispose<
    AdminCategoriesListController,
    List<Category>>(AdminCategoriesListController.new);

class AdminCategoriesListController extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return ref.read(catalogRepositoryProvider).getCategories();
  }
}

/// Detail alat untuk admin (edit).
///
/// Family per `equipmentId`, autoDispose + `ref.watch(currentUserIdProvider)`.
final adminEquipmentDetailProvider = AsyncNotifierProvider.autoDispose
    .family<AdminEquipmentDetailController, Equipment, int>(
  AdminEquipmentDetailController.new,
);

class AdminEquipmentDetailController extends AsyncNotifier<Equipment> {
  AdminEquipmentDetailController(this.equipmentId);

  final int equipmentId;

  @override
  Future<Equipment> build() {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return Future<Equipment>.error(
        ApiException(
          statusCode: 401,
          message: 'Sesi Anda telah berakhir. Silakan login kembali.',
        ),
      );
    }
    return ref.read(catalogRepositoryProvider).getDetail(equipmentId);
  }
}

/// Muat ulang data katalog admin setelah tambah/ubah/hapus alat atau kategori.
void refreshAdminCatalog(WidgetRef ref, {int? equipmentId}) {
  ref.invalidate(adminEquipmentsListProvider);
  ref.invalidate(adminCategoriesListProvider);
  ref.invalidate(categoriesProvider); // publik
  if (equipmentId != null) {
    ref.invalidate(adminEquipmentDetailProvider(equipmentId));
  }
  // Invalidate katalog customer agar perubahan admin langsung terlihat.
  ref.invalidate(equipmentListProvider);
}
