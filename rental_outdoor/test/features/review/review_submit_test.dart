import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/core/network/api_exception.dart';
import 'package:rental_outdoor/features/catalog/data/catalog_repository.dart';
import 'package:rental_outdoor/features/catalog/domain/availability.dart';
import 'package:rental_outdoor/features/catalog/domain/catalog_filter.dart';
import 'package:rental_outdoor/features/catalog/domain/category.dart';
import 'package:rental_outdoor/features/catalog/domain/equipment.dart';
import 'package:rental_outdoor/features/catalog/domain/pagination.dart';
import 'package:rental_outdoor/features/catalog/domain/review.dart';
import 'package:rental_outdoor/features/catalog/presentation/equipment_detail_provider.dart';
import 'package:rental_outdoor/features/catalog/presentation/equipment_reviews_provider.dart';
import 'package:rental_outdoor/features/review/data/review_repository.dart';
import 'package:rental_outdoor/features/review/presentation/review_provider.dart';

/// Pengiriman ulasan `POST /reviews` (API_DOCS.md bagian 9) tanpa jaringan:
/// - sukses -> ditandai "Sudah diulas" + provider detail/ulasan alat
///   di-invalidate,
/// - `409` (sudah pernah mengulas) -> pesan ramah + ditandai reviewed,
/// - `422` (rating tidak valid) -> pesan ramah + TIDAK ditandai reviewed,
/// - rating di luar 1–5 -> ditolak sebelum memanggil API,
/// - double tap -> hanya satu panggilan API berjalan.
void main() {
  const bookingId = 50;

  ProviderContainer buildContainer(_FakeReviewRepository review) {
    final container = ProviderContainer(
      overrides: [
        reviewRepositoryProvider.overrideWithValue(review),
        catalogRepositoryProvider.overrideWithValue(_FakeCatalogRepository()),
      ],
    );
    addTearDown(container.dispose);
    // Listener tetap hidup: provider autoDispose tidak boleh dibuang di
    // tengah pengujian (state "sedang mengirim" harus bertahan).
    final reviewSub =
        container.listen(bookingReviewProvider(bookingId), (_, __) {});
    addTearDown(reviewSub.close);
    return container;
  }

  ReviewSubmitState stateOf(ProviderContainer container) =>
      container.read(bookingReviewProvider(bookingId));

  Future<String?> submit(
    ProviderContainer container, {
    int equipmentId = 1,
    int rating = 5,
    String? comment,
  }) =>
      container
          .read(bookingReviewProvider(bookingId).notifier)
          .submit(
            equipmentId: equipmentId,
            rating: rating,
            comment: comment,
          );

  group('sukses', () {
    test('ditandai "Sudah diulas" + detail & daftar ulasan alat di-invalidate',
        () async {
      final review = _FakeReviewRepository();
      final container = buildContainer(review);

      // Listener aktif supaya invalidasi memicu muat ulang (autoDispose).
      final detailSub =
          container.listen(equipmentDetailProvider(1), (_, __) {});
      addTearDown(detailSub.close);
      final reviewsSub =
          container.listen(equipmentReviewsProvider(1), (_, __) {});
      addTearDown(reviewsSub.close);

      await container.read(equipmentDetailProvider(1).future);
      await container.read(equipmentReviewsProvider(1).future);
      final catalog =
          container.read(catalogRepositoryProvider) as _FakeCatalogRepository;
      expect(catalog.detailCalls, 1);
      expect(catalog.reviewCalls, 1);

      final message = await submit(container, comment: 'Barang mantap');

      expect(message, isNull);
      expect(review.calls, 1);
      expect(review.lastBookingId, bookingId);
      expect(review.lastEquipmentId, 1);
      expect(review.lastRating, 5);
      expect(review.lastComment, 'Barang mantap');
      expect(stateOf(container).isReviewed(1), isTrue);
      expect(stateOf(container).isSubmitting(1), isFalse);

      // Provider terkait dimuat ulang setelah sukses.
      await container.read(equipmentDetailProvider(1).future);
      await container.read(equipmentReviewsProvider(1).future);
      expect((catalog).detailCalls, 2);
      expect(catalog.reviewCalls, 2);
    });
  });

  group('409 — sudah pernah mengulas', () {
    test('pesan ramah + ditandai reviewed + submit ulang tanpa panggilan API',
        () async {
      final review = _FakeReviewRepository(
        behavior: () => throw ApiException(
          statusCode: 409,
          message: 'Review already exists',
        ),
      );
      final container = buildContainer(review);

      final message = await submit(container, rating: 4);

      expect(message, 'Alat ini sudah pernah diulas untuk pesanan ini.');
      expect(review.calls, 1);
      expect(stateOf(container).isReviewed(1), isTrue);

      // Kedua kali: langsung ditolak di client, API tidak dipanggil.
      final second = await submit(container, rating: 2);
      expect(second, 'Alat ini sudah diulas untuk pesanan ini.');
      expect(review.calls, 1);
    });
  });

  group('422 — rating tidak valid', () {
    test('pesan ramah + TIDAK ditandai reviewed', () async {
      final review = _FakeReviewRepository(
        behavior: () => throw ApiException(
          statusCode: 422,
          message: 'rating is invalid',
        ),
      );
      final container = buildContainer(review);

      final message = await submit(container);

      expect(message, 'Rating tidak valid. Pilih 1 sampai 5 bintang.');
      expect(review.calls, 1);
      expect(stateOf(container).isReviewed(1), isFalse);
      expect(stateOf(container).isSubmitting(1), isFalse);
    });

    test('rating di luar 1–5 ditolak sebelum memanggil API', () async {
      final review = _FakeReviewRepository();
      final container = buildContainer(review);

      for (final rating in const [0, -1, 6]) {
        final message = await submit(container, rating: rating);
        expect(message, 'Pilih rating 1 sampai 5 bintang.', reason: '$rating');
      }

      expect(review.calls, 0);
      expect(stateOf(container).isReviewed(1), isFalse);
    });
  });

  group('cegah double tap', () {
    test('submit kedua saat masih berjalan tidak memanggil API', () async {
      final gate = Completer<void>();
      final review = _FakeReviewRepository(gate: gate.future);
      final container = buildContainer(review);

      final first = submit(container, equipmentId: 7);
      await Future<void>.delayed(Duration.zero);

      expect(stateOf(container).isSubmitting(7), isTrue);
      expect(review.calls, 1);

      // Kedua tap saat request pertama masih berjalan.
      final second = await submit(container, equipmentId: 7, rating: 3);
      expect(second, isNull);
      expect(review.calls, 1);

      gate.complete();
      expect(await first, isNull);
      expect(stateOf(container).isSubmitting(7), isFalse);
      expect(stateOf(container).isReviewed(7), isTrue);
    });
  });
}

/// Repository ulasan palsu: perilaku diatur lewat [behavior] / [gate].
class _FakeReviewRepository implements ReviewRepository {
  _FakeReviewRepository({this.behavior, this.gate});

  /// Dijalankan tiap [createReview]; default sukses.
  void Function()? behavior;

  /// Bila diisi, menunggu future ini sebelum mengembalikan hasil.
  Future<void>? gate;

  int calls = 0;
  int? lastBookingId;
  int? lastEquipmentId;
  int? lastRating;
  String? lastComment;

  @override
  Future<Review?> createReview({
    required int bookingId,
    required int equipmentId,
    required int rating,
    String? comment,
  }) async {
    calls++;
    lastBookingId = bookingId;
    lastEquipmentId = equipmentId;
    lastRating = rating;
    lastComment = comment;

    final pending = gate;
    if (pending != null) await pending;

    behavior?.call();
    return Review(
      id: calls,
      bookingId: bookingId,
      userId: 2,
      equipmentId: equipmentId,
      rating: rating,
      comment: comment,
    );
  }
}

/// Katalog palsu: hanya `getDetail` / `getReviews` yang dipakai provider
/// terkait ulasan; sisanya tidak boleh terpanggil.
class _FakeCatalogRepository implements CatalogRepository {
  int detailCalls = 0;
  int reviewCalls = 0;

  @override
  Future<Equipment> getDetail(int id) async {
    detailCalls++;
    return Equipment(
      id: id,
      categoryId: 1,
      name: 'Tenda Kapasitas 4 Orang',
      pricePerDay: 75000,
      totalReviews: detailCalls,
    );
  }

  @override
  Future<ReviewsPage> getReviews({
    required int equipmentId,
    int page = 1,
    int limit = 10,
  }) async {
    reviewCalls++;
    return ReviewsPage(items: const [], pagination: Pagination.empty());
  }

  @override
  Future<List<Category>> getCategories() => throw UnimplementedError();

  @override
  Future<EquipmentPage> getEquipments({
    CatalogFilter filter = const CatalogFilter(),
    int page = 1,
    int limit = 20,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<Equipment>> getPopular({int limit = 6}) =>
      throw UnimplementedError();

  @override
  Future<AvailabilityResult> getAvailability({
    required int equipmentId,
    required DateTime pickupDate,
    required DateTime returnDate,
  }) =>
      throw UnimplementedError();
}
