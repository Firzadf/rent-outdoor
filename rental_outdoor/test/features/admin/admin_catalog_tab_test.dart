import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/core/network/api_exception.dart';
import 'package:rental_outdoor/core/network/app_retry.dart';
import 'package:rental_outdoor/features/admin/presentation/admin_catalog_page.dart';
import 'package:rental_outdoor/features/auth/presentation/auth_controller.dart';
import 'package:rental_outdoor/features/catalog/data/catalog_repository.dart';
import 'package:rental_outdoor/features/catalog/domain/availability.dart';
import 'package:rental_outdoor/features/catalog/domain/catalog_filter.dart';
import 'package:rental_outdoor/features/catalog/domain/category.dart';
import 'package:rental_outdoor/features/catalog/domain/equipment.dart';
import 'package:rental_outdoor/features/catalog/domain/pagination.dart';
import 'package:rental_outdoor/features/catalog/domain/review.dart';

/// Bug: tab Alat admin kosong total (tanpa daftar, EmptyView, ErrorView,
/// loading, atau tombol Tambah). Test ini HARUS GAGAL pada kode saat ini.
void main() {
  Equipment eq(
    int id,
    String name, {
    int stock = 5,
    bool isActive = true,
    int categoryId = 1,
  }) =>
      Equipment(
        id: id,
        categoryId: categoryId,
        name: name,
        pricePerDay: 50000,
        stock: stock,
        isActive: isActive,
        primaryImageUrl: 'http://localhost/alat$id.jpg',
        createdAt: '2026-10-01 10:00:00',
        updatedAt: '2026-10-01 10:00:00',
      );

  Future<void> pumpCatalog(
    WidgetTester tester, {
    required _FakeCatalogRepo repo,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: appRetry,
        overrides: [
          currentUserIdProvider.overrideWithValue(1),
          catalogRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: AdminCatalogPage()),
      ),
    );
  }

  group('bug: tab Alat kosong total', () {
    testWidgets('3 alat: kartu tampil + tombol Tambah tampil', (tester) async {
      final repo = _FakeCatalogRepo(
        equipments: [
          eq(1, 'Tenda Kapasitas 4 Orang'),
          eq(2, 'Sleeping Bag'),
          eq(3, 'Kompor Portable', stock: 0),
        ],
      );
      await pumpCatalog(tester, repo: repo);
      await tester.pumpAndSettle();

      // 3 kartu alat harus tampil.
      expect(find.text('Tenda Kapasitas 4 Orang'), findsOneWidget);
      expect(find.text('Sleeping Bag'), findsOneWidget);
      expect(find.text('Kompor Portable'), findsOneWidget);

      // Stok & harga tampil.
      expect(find.text('Stok: 5'), findsNWidgets(2));
      expect(find.text('Stok: 0'), findsOneWidget);
      expect(find.textContaining('Rp'), findsNWidgets(3));

      // Tombol Tambah SELALU ada (state data).
      expect(find.text('Tambah'), findsOneWidget);

      // TextField pencarian tampil.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('kosong: EmptyView + tombol Tambah Alat tampil', (tester) async {
      final repo = _FakeCatalogRepo(equipments: []);
      await pumpCatalog(tester, repo: repo);
      await tester.pumpAndSettle();

      expect(find.text('Belum ada alat.'), findsOneWidget);
      expect(find.text('Tambah Alat'), findsOneWidget);

      // Pencarian tidak tampil saat kosong.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('error: ErrorView + Coba Lagi tampil', (tester) async {
      final repo = _FakeCatalogRepo(
        error: ApiException(statusCode: 500, message: 'Server error.'),
      );
      await pumpCatalog(tester, repo: repo);
      await tester.pumpAndSettle();

      expect(find.text('Server error.'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      // Tombol Tambah tidak tampil di state error (ErrorView tampil penuh).
      expect(find.widgetWithText(FilledButton, 'Tambah'), findsNothing);
    });

    testWidgets('pencarian filter nama (case-insensitive)', (tester) async {
      final repo = _FakeCatalogRepo(
        equipments: [
          eq(1, 'Tenda Kapasitas 4 Orang'),
          eq(2, 'Sleeping Bag'),
        ],
      );
      await pumpCatalog(tester, repo: repo);
      await tester.pumpAndSettle();

      expect(find.text('Tenda Kapasitas 4 Orang'), findsOneWidget);
      expect(find.text('Sleeping Bag'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'sleeping');
      await tester.pumpAndSettle();

      expect(find.text('Sleeping Bag'), findsOneWidget);
      expect(find.text('Tenda Kapasitas 4 Orang'), findsNothing);

      // Pencarian kosong → EmptyView (tanpa tombol Tambah Alat).
      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada alat yang cocok.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Tambah Alat'), findsNothing);
    });
  });

  group('tab Kategori (referensi: struktur serupa, berfungsi normal)', () {
    testWidgets('filter kategori: FilterChip mengubah daftar alat', (tester) async {
      final repo = _FakeCatalogRepo(
        equipments: [
          eq(1, 'Tenda 3 Orang', categoryId: 1),
          eq(2, 'Tenda 4 Orang', categoryId: 1),
          eq(3, 'Kompor Gas', categoryId: 2),
          eq(4, 'Panci Stainless', categoryId: 2),
        ],
        categories: [
          Category(
            id: 1,
            name: 'Tenda',
            description: 'Semua jenis tenda',
            createdAt: '2026-10-01',
          ),
          Category(
            id: 2,
            name: 'Peralatan Masak',
            createdAt: '2026-10-01',
          ),
        ],
      );
      await pumpCatalog(tester, repo: repo);
      await tester.pumpAndSettle();

      // Pastikan tampil tab Alat.
      await tester.tap(find.text('Alat'));
      await tester.pumpAndSettle();

      // Semua 4 alat tampil awal (FilterChip 'Semua' terpilih).
      expect(find.text('Tenda 3 Orang'), findsOneWidget);
      expect(find.text('Tenda 4 Orang'), findsOneWidget);
      expect(find.text('Kompor Gas'), findsOneWidget);
      expect(find.text('Panci Stainless'), findsOneWidget);

      // Pilih FilterChip 'Tenda' (index 1, setelah 'Semua').
      await tester.tap(find.byType(FilterChip).at(1));
      await tester.pumpAndSettle();

      // Hanya 2 alat Tenda yang tampil.
      expect(find.text('Tenda 3 Orang'), findsOneWidget);
      expect(find.text('Tenda 4 Orang'), findsOneWidget);
      expect(find.text('Kompor Gas'), findsNothing);
      expect(find.text('Panci Stainless'), findsNothing);

      // Kembali ke 'Semua'.
      await tester.tap(find.byType(FilterChip).first);
      await tester.pumpAndSettle();

      // Semua 4 alat muncul kembali.
      expect(find.text('Tenda 3 Orang'), findsOneWidget);
      expect(find.text('Tenda 4 Orang'), findsOneWidget);
      expect(find.text('Kompor Gas'), findsOneWidget);
      expect(find.text('Panci Stainless'), findsOneWidget);
    });

    testWidgets('2 kategori tampil + tombol Tambah Kategori', (tester) async {
      final repo = _FakeCatalogRepo(
        equipments: [],
        categories: [
          Category(
            id: 1,
            name: 'Tenda',
            description: 'Semua jenis tenda',
            createdAt: '2026-10-01',
          ),
          Category(
            id: 2,
            name: 'Peralatan Masak',
            createdAt: '2026-10-01',
          ),
        ],
      );
      await pumpCatalog(tester, repo: repo);
      await tester.pumpAndSettle();

      // Ganti ke tab Kategori.
      await tester.tap(find.text('Kategori'));
      await tester.pumpAndSettle();

      // Scroll ke atasagar tombol terlihat.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(find.text('Tenda'), findsOneWidget);
      expect(find.text('Peralatan Masak'), findsOneWidget);
      expect(find.text('Tambah Kategori'), findsOneWidget);
    });
  });
}

/// Repository katalog palsu tanpa jaringan.
class _FakeCatalogRepo implements CatalogRepository {
  _FakeCatalogRepo({
    this.equipments = const [],
    this.categories = const [],
    this.error,
  });

  final List<Equipment> equipments;
  final List<Category> categories;
  final ApiException? error;

  @override
  Future<EquipmentPage> getEquipments({
    CatalogFilter filter = const CatalogFilter(),
    int page = 1,
    int limit = 20,
  }) async {
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
