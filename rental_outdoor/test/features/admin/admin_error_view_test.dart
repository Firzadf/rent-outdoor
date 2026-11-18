import 'package:flutter/material.dart';
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
import 'package:rental_outdoor/features/admin/presentation/admin_dashboard_page.dart';
import 'package:rental_outdoor/features/auth/presentation/auth_controller.dart';
import 'package:rental_outdoor/features/catalog/domain/category.dart';
import 'package:rental_outdoor/features/catalog/domain/equipment.dart';
import 'package:rental_outdoor/features/catalog/domain/equipment_image.dart';

/// ErrorView + tombol "Coba Lagi" HARUS muncul dalam hitungan detik dengan
/// konfigurasi retry aplikasi (`ProviderScope(retry: appRetry)`):
/// - 404 dari server -> langsung (tanpa retry),
/// - server mati / tidak ada koneksi (statusCode 0) -> 1 retry setelah
///   1 detik, lalu ErrorView (bukan ±38 detik seperti retry bawaan Riverpod).
void main() {
  Future<void> pumpDashboard(
    WidgetTester tester, {
    required _ThrowingRepo repo,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: appRetry,
        overrides: [
          currentUserIdProvider.overrideWithValue(1),
          adminRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: AdminDashboardPage()),
      ),
    );
  }

  testWidgets('404: ErrorView + "Coba Lagi" muncul langsung tanpa retry',
      (tester) async {
    final repo = _ThrowingRepo(
      ApiException(statusCode: 404, message: 'Data tidak ditemukan.'),
    );
    await pumpDashboard(tester, repo: repo);

    // Beberapa frame saja — tanpa menunggu.
    await tester.pump();
    await tester.pump();

    expect(find.text('Data tidak ditemukan.'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
    expect(repo.calls, 1, reason: '404 tidak diulang otomatis');
  });

  testWidgets('server mati: 1 retry (1 detik) lalu ErrorView, total < 5 detik',
      (tester) async {
    final repo = _ThrowingRepo(
      ApiException.network('Server tidak dapat dihubungi.'),
    );
    await pumpDashboard(tester, repo: repo);

    // Masih loading (menunggu jeda retry 1 detik).
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Coba Lagi'), findsNothing);
    expect(find.text('Server tidak dapat dihubungi.'), findsNothing);
    expect(repo.calls, 1);

    // Lewat jeda retry -> percobaan ke-2 (gagal) -> ErrorView.
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();

    expect(repo.calls, 2, reason: 'tepat 1 kali retry');
    expect(find.text('Server tidak dapat dihubungi.'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
  });

  testWidgets('tombol "Coba Lagi" memuat ulang provider', (tester) async {
    final repo = _ThrowingRepo(
      ApiException(statusCode: 404, message: 'Data tidak ditemukan.'),
    );
    await pumpDashboard(tester, repo: repo);

    await tester.pump();
    await tester.pump();
    expect(repo.calls, 1);

    await tester.tap(find.text('Coba Lagi'));
    await tester.pump();
    await tester.pump();

    expect(repo.calls, 2, reason: 'retry manual lewat ErrorView');
    expect(find.text('Coba Lagi'), findsOneWidget, reason: 'masih error');
  });
}

/// Repository admin palsu yang selalu gagal (tanpa jaringan).
class _ThrowingRepo implements AdminRepository {
  _ThrowingRepo(this.error);

  final ApiException error;
  int calls = 0;

  @override
  Future<AdminDashboard> getDashboard() {
    calls++;
    return Future<AdminDashboard>.error(error);
  }

  @override
  Future<AdminBookingsPage> getBookings({
    String? status,
    String? search,
    int page = 1,
    int limit = 10,
  }) =>
      throw UnimplementedError();

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
