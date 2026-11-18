import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:rental_outdoor/core/network/api_exception.dart';
import 'package:rental_outdoor/core/network/app_retry.dart';
import 'package:rental_outdoor/features/admin/data/admin_repository.dart';
import 'package:rental_outdoor/features/admin/domain/admin_booking.dart';
import 'package:rental_outdoor/features/admin/domain/admin_dashboard.dart';
import 'package:rental_outdoor/features/admin/domain/admin_report.dart';
import 'package:rental_outdoor/features/admin/domain/admin_user.dart';
import 'package:rental_outdoor/features/admin/presentation/admin_providers.dart';
import 'package:rental_outdoor/features/auth/presentation/auth_controller.dart';
import 'package:rental_outdoor/features/booking/domain/booking.dart';
import 'package:rental_outdoor/features/catalog/domain/category.dart';
import 'package:rental_outdoor/features/catalog/domain/equipment.dart';
import 'package:rental_outdoor/features/catalog/domain/equipment_image.dart';
import 'package:rental_outdoor/features/catalog/domain/pagination.dart';

/// State admin WAJIB terpisah antar akun dan tidak boleh ada panggilan
/// API saat sesi belum/login null (semua provider autoDispose + memakai
/// `currentUserIdProvider`; invalidasi sesi di pengamat sesi router).
void main() {
  AdminBooking bookingOf(int id, String code, {String? status}) => AdminBooking(
        id: id,
        bookingCode: code,
        status: status ?? BookingStatus.pendingPayment,
        userName: 'Pelanggan $id',
        itemCount: 2,
        totalDays: 2,
        grandTotal: 900000,
      );

  ProviderContainer buildContainer(
    _FakeAdminRepository repo, {
    int? userId = 1,
  }) {
    final container = ProviderContainer(
      // Kebijakan retry sama persis dengan aplikasi (ProviderScope di
      // main.dart): ApiException tidak di-retry sehingga state error
      // tercapai seketika dan ErrorView muncul dalam hitungan detik.
      retry: appRetry,
      overrides: [
        currentUserIdProvider.overrideWithValue(userId),
        adminRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('isolasi daftar pesanan antar akun', () {
    test('admin A hanya melihat daftarnya, admin B hanya miliknya', () async {
      final fakeA = _FakeAdminRepository(
        bookingsFor: (_) async => [bookingOf(1, 'OR-A-1')],
      );
      final fakeB = _FakeAdminRepository(
        bookingsFor: (_) async => [bookingOf(2, 'OR-B-1')],
      );

      final containerA = buildContainer(fakeA, userId: 1);
      final subA = containerA.listen(adminBookingsListProvider, (_, __) {});
      addTearDown(subA.close);
      final stateA = await containerA.read(adminBookingsListProvider.future);

      final containerB = buildContainer(fakeB, userId: 2);
      final subB = containerB.listen(adminBookingsListProvider, (_, __) {});
      addTearDown(subB.close);
      final stateB = await containerB.read(adminBookingsListProvider.future);

      expect(stateA.items.single.bookingCode, 'OR-A-1');
      expect(stateB.items.single.bookingCode, 'OR-B-1');
      expect(stateB.items.single.bookingCode, isNot('OR-A-1'));
      expect(fakeB.calls, 1);
    });

    test('userId null -> daftar kosong TANPA panggilan API', () async {
      final fake = _FakeAdminRepository(
        bookingsFor: (_) async => throw StateError('tidak boleh dipanggil'),
      );

      final container = buildContainer(fake, userId: null);
      final sub = container.listen(adminBookingsListProvider, (_, __) {});
      addTearDown(sub.close);

      final state = await container.read(adminBookingsListProvider.future);
      expect(state.items, isEmpty);
      expect(state.hasMore, isFalse);
      expect(fake.calls, 0);
    });

    test('userId null -> dashboard gagal ramah TANPA panggilan API', () async {
      final fake = _FakeAdminRepository();

      final container = buildContainer(fake, userId: null);
      final sub = container.listen(adminDashboardProvider, (_, __) {});
      addTearDown(sub.close);

      await expectLater(
        container.read(adminDashboardProvider.future),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', contains('login')),
        ),
      );
      expect(fake.dashboardCalls, 0);
    });
  });

  group('filter status + pencarian', () {
    test('chip status diteruskan ke repository (default tanpa status)',
        () async {
      final fake = _FakeAdminRepository(
        bookingsFor: (_) async => [bookingOf(1, 'OR-1')],
      );
      final container = buildContainer(fake);
      final sub = container.listen(adminBookingsListProvider, (_, __) {});
      addTearDown(sub.close);

      await container.read(adminBookingsListProvider.future);
      expect(fake.lastStatus, isNull, reason: 'chip "Semua" tanpa status');
      expect(fake.lastSearch, '', reason: 'pencarian awal kosong');
      expect(fake.lastPage, 1);

      container
          .read(adminBookingsFilterProvider.notifier)
          .setStatus(BookingStatus.pendingVerification);
      await container.read(adminBookingsListProvider.future);
      expect(fake.lastStatus, BookingStatus.pendingVerification);
      expect(fake.lastPage, 1);
    });

    test('kata kunci pencarian diteruskan dan memicu muat ulang halaman 1',
        () async {
      final fake = _FakeAdminRepository(
        bookingsFor: (_) async => [bookingOf(1, 'OR-1')],
      );
      final container = buildContainer(fake);
      final sub = container.listen(adminBookingsListProvider, (_, __) {});
      addTearDown(sub.close);

      await container.read(adminBookingsListProvider.future);
      expect(fake.lastSearch, '');

      container.read(adminBookingsSearchProvider.notifier).setSearch('Budi');
      await container.read(adminBookingsListProvider.future);

      expect(fake.lastSearch, 'Budi');
      expect(fake.lastPage, 1);
    });

    test('loadMore menggabungkan halaman berikutnya + berhenti di akhir',
        () async {
      final fake = _FakeAdminRepository(
        bookingsFor: (page) async =>
            page == 1 ? [bookingOf(1, 'OR-1')] : [bookingOf(2, 'OR-2')],
        totalPages: 2,
      );
      final container = buildContainer(fake);
      final sub = container.listen(adminBookingsListProvider, (_, __) {});
      addTearDown(sub.close);

      final first = await container.read(adminBookingsListProvider.future);
      expect(first.hasMore, isTrue);
      expect(first.items.map((b) => b.bookingCode), ['OR-1']);

      await container.read(adminBookingsListProvider.notifier).loadMore();
      final second = container.read(adminBookingsListProvider).value!;

      expect(second.items.map((b) => b.bookingCode), ['OR-1', 'OR-2']);
      expect(second.hasMore, isFalse);
      expect(second.loadingMore, isFalse);

      final callsBefore = fake.calls;
      await container.read(adminBookingsListProvider.notifier).loadMore();
      expect(fake.calls, callsBefore, reason: 'sudah di halaman terakhir');
    });
  });

  group('dashboard', () {
    test('sukses -> angka dari repository (parser aman di model)', () async {
      final fake = _FakeAdminRepository();
      final container = buildContainer(fake);
      final sub = container.listen(adminDashboardProvider, (_, __) {});
      addTearDown(sub.close);

      final dashboard = await container.read(adminDashboardProvider.future);

      expect(fake.dashboardCalls, 1);
      expect(dashboard.totalOrders, 4);
      expect(dashboard.pendingVerificationCount, 1);
      expect(dashboard.topEquipments.single.totalRentals, 2);
    });
  });
}

/// Repository admin palsu: tanpa jaringan, hasil diatur lewat callback.
class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository({
    this.bookingsFor,
    this.totalPages = 1,
  });

  final Future<List<AdminBooking>> Function(int page)? bookingsFor;
  final int totalPages;

  int calls = 0;
  int dashboardCalls = 0;
  String? lastStatus;
  String? lastSearch;
  int? lastPage;

  @override
  Future<AdminBookingsPage> getBookings({
    String? status,
    String? search,
    int page = 1,
    int limit = 10,
  }) async {
    calls++;
    lastStatus = status;
    lastSearch = search;
    lastPage = page;

    final items = await bookingsFor?.call(page) ?? <AdminBooking>[];

    return AdminBookingsPage(
      items: items,
      pagination: Pagination(
        total: items.length * totalPages,
        page: page,
        limit: limit,
        totalPages: totalPages,
      ),
    );
  }

  @override
  Future<AdminDashboard> getDashboard() async {
    dashboardCalls++;
    return AdminDashboard.fromJson(const {
      'total_orders': 4,
      'total_revenue': 1350000,
      'pending_verification_count': 1,
      'active_rentals_count': 2,
      'top_equipments': [
        {'id': 1, 'name': 'Tenda Kapasitas 4 Orang', 'total_rentals': '2'},
      ],
    });
  }

  @override
  Future<AdminBooking> getBooking(int id) => throw UnimplementedError();

  @override
  Future<void> verifyBooking(
    int id, {
    required String action,
    String? rejectionReason,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> startBooking(int id) => throw UnimplementedError();

  @override
  Future<BookingCompleteResult> completeBooking({
    required int id,
    required String returnCondition,
    String? returnNotes,
    double? damageFee,
    required DateTime actualReturnDate,
  }) =>
      throw UnimplementedError();

  @override
  Future<Category> createCategory({
    required String name,
    String? description,
    String? icon,
  }) =>
      throw UnimplementedError();

  @override
  Future<Category> updateCategory(
    int id, {
    required String name,
    String? description,
    String? icon,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteCategory(int id) => throw UnimplementedError();

  @override
  Future<Equipment> createEquipment({
    required int categoryId,
    required String name,
    required double pricePerDay,
    required int stock,
    double? deposit,
    String? description,
    bool? isActive,
  }) =>
      throw UnimplementedError();

  @override
  Future<Equipment> updateEquipment(
    int id, {
    required int categoryId,
    required String name,
    required double pricePerDay,
    required int stock,
    double? deposit,
    String? description,
    bool? isActive,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteEquipment(int id) => throw UnimplementedError();

  @override
  Future<List<EquipmentImage>> uploadEquipmentImages(
    int equipmentId,
    List<XFile> fileDataList,
  ) =>
      throw UnimplementedError();

  @override
  Future<void> deleteEquipmentImage(int imageId) =>
      throw UnimplementedError();

  @override
  Future<AdminUsersPage> getUsers({
    String? role,
    String? search,
    int page = 1,
    int limit = 10,
  }) =>
      throw UnimplementedError();

  @override
  Future<AdminUser> toggleUserActive(int userId) => throw UnimplementedError();

  @override
  Future<RevenueReport> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
    String period = 'daily',
  }) =>
      throw UnimplementedError();

  @override
  Future<EquipmentReport> getEquipmentReport({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      throw UnimplementedError();
}
