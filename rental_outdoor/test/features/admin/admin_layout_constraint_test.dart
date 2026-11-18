import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/core/network/api_exception.dart';
import 'package:rental_outdoor/core/network/app_retry.dart';
import 'package:rental_outdoor/core/theme/app_theme.dart';
import 'package:rental_outdoor/features/admin/presentation/admin_catalog_page.dart';
import 'package:rental_outdoor/features/auth/presentation/auth_controller.dart';
import 'package:rental_outdoor/features/catalog/data/catalog_repository.dart';
import 'package:rental_outdoor/features/catalog/domain/availability.dart';
import 'package:rental_outdoor/features/catalog/domain/catalog_filter.dart';
import 'package:rental_outdoor/features/catalog/domain/category.dart';
import 'package:rental_outdoor/features/catalog/domain/equipment.dart';
import 'package:rental_outdoor/features/catalog/domain/pagination.dart';
import 'package:rental_outdoor/features/catalog/domain/review.dart';

/// Test layout constraint bug: "BoxConstraints forces an infinite width"
/// di Chrome. Test ini menggunakan tema aplikasi asli (AppTheme) dan
/// berbagai ukuran layar untuk mendeteksi overflow dan constraint error.
void main() {
  Equipment eq(
    int id,
    String name, {
    int stock = 5,
    bool isActive = true,
    int categoryId = 1,
    String? categoryName,
  }) =>
      Equipment(
        id: id,
        categoryId: categoryId,
        categoryName: categoryName,
        name: name,
        description: 'Deskripsi $name',
        pricePerDay: 75000,
        stock: stock,
        isActive: isActive,
        primaryImageUrl: 'http://localhost/img/alat$id.jpg',
        createdAt: '2026-10-28T08:00:00Z',
        updatedAt: '2026-10-28T08:00:00Z',
      );

  Category cat(int id, String name) => Category(
        id: id,
        name: name,
        description: 'Kategori $name',
        createdAt: '2026-10-01T00:00:00Z',
        updatedAt: '2026-10-01T00:00:00Z',
      );

  Future<void> pumpCatalogWithTheme(
    WidgetTester tester, {
    required _FakeCatalogRepo repo,
    Size? screenSize,
  }) async {
    if (screenSize != null) {
      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    await tester.pumpWidget(
      ProviderScope(
        retry: appRetry,
        overrides: [
          currentUserIdProvider.overrideWithValue(1),
          catalogRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AdminCatalogPage(),
        ),
      ),
    );
  }

  group('Layout constraint bug: tab Alat admin', () {
    testWidgets(
      'BEFORE FIX: 3 alat + 2 kategori di layar 360x800 → constraint error',
      (tester) async {
        final repo = _FakeCatalogRepo(
          equipments: [
            eq(1, 'Tenda Kapasitas 4 Orang', categoryId: 1, categoryName: 'Tenda'),
            eq(2, 'Sleeping Bag Premium', categoryId: 1, categoryName: 'Tenda'),
            eq(3, 'Kompor Portable Gas', stock: 2, categoryId: 2, categoryName: 'Peralatan Masak'),
          ],
          categories: [
            cat(1, 'Tenda'),
            cat(2, 'Peralatan Masak'),
          ],
        );

        await pumpCatalogWithTheme(
          tester,
          repo: repo,
          screenSize: const Size(360, 800),
        );
        await tester.pumpAndSettle();

        // Setelah pumpAndSettle, tester.takeException() harus null
        // (tidak ada overflow/constraint error).
        final exception = tester.takeException();
        expect(exception, isNull, reason: 'Layout constraint error terdeteksi');

        // Tombol Tambah dan nama alat harus terlihat.
        expect(find.text('Tambah'), findsOneWidget);
        expect(find.text('Tenda Kapasitas 4 Orang'), findsOneWidget);
        expect(find.text('Sleeping Bag Premium'), findsOneWidget);
        expect(find.text('Kompor Portable Gas'), findsOneWidget);
      },
    );

    testWidgets(
      'BEFORE FIX: 3 alat di layar 620x840 → constraint error',
      (tester) async {
        final repo = _FakeCatalogRepo(
          equipments: [
            eq(1, 'Tenda 4 Orang', categoryId: 1, categoryName: 'Tenda'),
            eq(2, 'Sleeping Bag', categoryId: 1, categoryName: 'Tenda'),
            eq(3, 'Kompor', categoryId: 2, categoryName: 'Masak'),
          ],
          categories: [
            cat(1, 'Tenda'),
            cat(2, 'Masak'),
          ],
        );

        await pumpCatalogWithTheme(
          tester,
          repo: repo,
          screenSize: const Size(620, 840),
        );
        await tester.pumpAndSettle();

        final exception = tester.takeException();
        expect(exception, isNull, reason: 'Layout constraint error terdeteksi');

        expect(find.text('Tambah'), findsOneWidget);
        expect(find.text('Tenda 4 Orang'), findsOneWidget);
      },
    );

    testWidgets(
      'BEFORE FIX: 3 alat di layar 1200x800 → constraint error',
      (tester) async {
        final repo = _FakeCatalogRepo(
          equipments: [
            eq(1, 'Tenda Dome Besar', categoryId: 1, categoryName: 'Tenda'),
            eq(2, 'Sleeping Bag', categoryId: 1, categoryName: 'Tenda'),
            eq(3, 'Kompor', categoryId: 2, categoryName: 'Masak'),
          ],
          categories: [
            cat(1, 'Tenda'),
            cat(2, 'Masak'),
          ],
        );

        await pumpCatalogWithTheme(
          tester,
          repo: repo,
          screenSize: const Size(1200, 800),
        );
        await tester.pumpAndSettle();

        final exception = tester.takeException();
        expect(exception, isNull, reason: 'Layout constraint error terdeteksi');

        expect(find.text('Tambah'), findsOneWidget);
        expect(find.text('Tenda Dome Besar'), findsOneWidget);
      },
    );

    testWidgets(
      'BEFORE FIX: loading state di layar 360x800 → constraint error',
      (tester) async {
        final repo = _FakeCatalogRepo(loading: true);

        await pumpCatalogWithTheme(
          tester,
          repo: repo,
          screenSize: const Size(360, 800),
        );
        await tester.pump();

        final exception = tester.takeException();
        expect(exception, isNull, reason: 'Layout constraint error di state loading');
      },
    );

    testWidgets(
      'BEFORE FIX: kosong di layar 360x800 → constraint error',
      (tester) async {
        final repo = _FakeCatalogRepo(equipments: []);

        await pumpCatalogWithTheme(
          tester,
          repo: repo,
          screenSize: const Size(360, 800),
        );
        await tester.pumpAndSettle();

        final exception = tester.takeException();
        expect(exception, isNull, reason: 'Layout constraint error di state kosong');

        expect(find.text('Belum ada alat.'), findsOneWidget);
        expect(find.text('Tambah Alat'), findsOneWidget);
      },
    );

    testWidgets(
      'BEFORE FIX: error state di layar 360x800 → constraint error',
      (tester) async {
        final repo = _FakeCatalogRepo(
          error: ApiException(statusCode: 500, message: 'Server error'),
        );

        await pumpCatalogWithTheme(
          tester,
          repo: repo,
          screenSize: const Size(360, 800),
        );
        await tester.pumpAndSettle();

        final exception = tester.takeException();
        expect(exception, isNull, reason: 'Layout constraint error di state error');

        expect(find.text('Server error'), findsOneWidget);
        expect(find.text('Coba Lagi'), findsOneWidget);
      },
    );
  });
}

class _FakeCatalogRepo implements CatalogRepository {
  _FakeCatalogRepo({
    this.equipments = const [],
    this.categories = const [],
    this.error,
    this.loading = false,
  });

  final List<Equipment> equipments;
  final List<Category> categories;
  final ApiException? error;
  final bool loading;

  @override
  Future<EquipmentPage> getEquipments({
    CatalogFilter filter = const CatalogFilter(),
    int page = 1,
    int limit = 20,
  }) async {
    if (loading) return Future.delayed(const Duration(hours: 1));
    if (error != null) throw error!;
    return EquipmentPage(
      items: equipments,
      pagination: Pagination(
        total: equipments.length,
        page: 1,
        limit: 100,
        totalPages: 1,
      ),
    );
  }

  @override
  Future<List<Category>> getCategories() async {
    if (loading) return Future.delayed(const Duration(hours: 1));
    if (error != null) throw error!;
    return categories;
  }

  @override
  Future<Equipment> getDetail(int id) => throw UnimplementedError();

  @override
  Future<List<Equipment>> getPopular({int limit = 8}) =>
      throw UnimplementedError();

  @override
  Future<AvailabilityResult> getAvailability({
    required int equipmentId,
    required DateTime pickupDate,
    required DateTime returnDate,
  }) =>
      throw UnimplementedError();

  @override
  Future<ReviewsPage> getReviews({
    required int equipmentId,
    int page = 1,
    int limit = 10,
  }) =>
      throw UnimplementedError();
}
