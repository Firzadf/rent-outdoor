import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/features/catalog/domain/catalog_filter.dart';
import 'package:rental_outdoor/features/catalog/domain/equipment.dart';
import 'package:rental_outdoor/features/catalog/domain/review.dart';

void main() {
  group('Equipment.fromJson', () {
    test('DECIMAL string (harga, deposit, rating) dibaca parser aman', () {
      final equipment = Equipment.fromJson(<String, dynamic>{
        'id': 1,
        'category_id': 2,
        'name': 'Tenda Kapasitas 4 Orang',
        'description': 'Tenda 4 orang',
        'price_per_day': '75000.00',
        'stock': 10,
        'deposit': '300000.00',
        'rating_avg': '4.50',
        'total_reviews': 12,
        'total_bookings': 3,
        'is_active': 1,
        'created_at': '2026-10-08 10:00:00',
        'updated_at': '2026-10-08 10:00:00',
        'category_name': 'Tenda',
        'primary_image_url':
            'http://localhost/outdoorrent/uploads/equipments/tent.jpg',
      });

      // Harga/deposit/rating datang sebagai STRING -> tidak pernah cast.
      expect(equipment.pricePerDay, 75000.0);
      expect(equipment.deposit, 300000.0);
      expect(equipment.ratingAvg, 4.5);
      expect(equipment.stock, 10);
      expect(equipment.totalReviews, 12);
      expect(equipment.totalBookings, 3);
      expect(equipment.isActive, isTrue);
      expect(equipment.categoryName, 'Tenda');
      expect(
        equipment.primaryImageUrl,
        'http://localhost/outdoorrent/uploads/equipments/tent.jpg',
      );
      // Daftar/populer tidak punya images/reviews -> kosong, bukan error.
      expect(equipment.images, isEmpty);
      expect(equipment.reviews, isEmpty);
    });

    test('field hilang / string kotor tidak melempar', () {
      final missing = Equipment.fromJson(const {'id': 5, 'name': 'Alat'});
      expect(missing.pricePerDay, 0.0);
      expect(missing.deposit, 0.0);
      expect(missing.ratingAvg, 0.0);
      expect(missing.stock, 0);
      expect(missing.primaryImageUrl, isNull);
      expect(missing.description, isNull);
      expect(missing.isActive, isTrue); // fallback default

      final weird = Equipment.fromJson(const <String, dynamic>{
        'price_per_day': 'bukan-angka',
        'rating_avg': null,
        'is_active': '0',
      });
      expect(weird.pricePerDay, 0.0);
      expect(weird.ratingAvg, 0.0);
      expect(weird.isActive, isFalse);
    });

    test('detail: images[] dan reviews[] terparsing', () {
      final detail = Equipment.fromJson(<String, dynamic>{
        'id': 1,
        'category_id': 1,
        'name': 'Tenda',
        'price_per_day': '75000.00',
        'primary_image_url':
            'http://localhost/outdoorrent/uploads/equipments/tent.jpg',
        'images': [
          <String, dynamic>{
            'id': 1,
            'equipment_id': 1,
            'image_url':
                'http://localhost/outdoorrent/uploads/equipments/tent.jpg',
            'is_primary': 1,
            'sort_order': 0,
          },
        ],
        'reviews': [
          <String, dynamic>{
            'id': 1,
            'booking_id': 1,
            'user_id': 2,
            'equipment_id': 1,
            'rating': 5,
            'comment': 'Mantap',
            'created_at': '2026-10-08 10:00:00',
            'user_name': 'John Doe',
            // profile_image SATU-SATUNYA gambar relatif di seluruh API.
            'profile_image': 'uploads/profiles/x.jpg',
          },
        ],
      });

      expect(detail.images, hasLength(1));
      expect(detail.images.first.imageUrl, startsWith('http://'));
      expect(detail.images.first.isPrimary, isTrue);
      expect(detail.reviews, hasLength(1));
      expect(detail.reviews.first.userName, 'John Doe');
      expect(detail.reviews.first.rating, 5);
      expect(detail.reviews.first.profileImage, 'uploads/profiles/x.jpg');
      expect(detail.galleryCover, startsWith('http://'));
    });
  });

  group('EquipmentPage.fromJson (data.equipments + data.pagination)', () {
    test('memecah envelope daftar dan pagination number', () {
      final page = EquipmentPage.fromJson(<String, dynamic>{
        'equipments': [
          <String, dynamic>{
            'id': 1,
            'name': 'A',
            'price_per_day': '10000.00',
          },
          <String, dynamic>{
            'id': 2,
            'name': 'B',
            'price_per_day': '20000.00',
          },
        ],
        'pagination': {'total': 12, 'page': 2, 'limit': 10, 'total_pages': 2},
      });

      expect(page.items, hasLength(2));
      expect(page.items.first.pricePerDay, 10000.0);
      expect(page.pagination.total, 12);
      expect(page.pagination.page, 2);
      expect(page.pagination.limit, 10);
      expect(page.pagination.hasNextPage, isFalse);
      expect(page.pagination.nextPage, 3);
    });

    test('respons tidak sesuai kontrak -> halaman kosong, bukan crash', () {
      final page = EquipmentPage.fromJson(const {});
      expect(page.items, isEmpty);
      expect(page.pagination.hasNextPage, isFalse);
    });
  });

  group('Review', () {
    test('user_name (detail) ATAU reviewer_name (daftar ulasan)', () {
      final fromDetail = Review.fromJson(const {'id': 1, 'user_name': 'John Doe'});
      expect(fromDetail.userName, 'John Doe');
      expect(fromDetail.initials, 'JD');

      final fromList =
          Review.fromJson(const {'id': 2, 'reviewer_name': 'Jane Doe'});
      expect(fromList.userName, 'Jane Doe');

      final anonymous = Review.fromJson(const {'id': 3});
      expect(anonymous.userName, isNull);
      expect(anonymous.initials, 'P'); // fallback 'Pengguna'
    });
  });

  group('EquipmentSort', () {
    test('hanya nilai sort yang valid menurut API_DOCS.md', () {
      expect(EquipmentSort.values, <String>['terbaru', 'termurah', 'terpopuler']);
      expect(EquipmentSort.terbaru, 'terbaru');
      expect(EquipmentSort.label('termurah'), 'Termurah');
      expect(EquipmentSort.label('terpopuler'), 'Terpopuler');
      expect(EquipmentSort.label('tidak-ada'), 'Terbaru');
    });

    test('CatalogFilter tidak berubah saat copyWith tanpa perubahan', () {
      const filter = CatalogFilter(search: 'tenda', categoryId: 2);
      expect(filter.copyWith(), filter);
      expect(filter.hasActiveFilter, isTrue);

      // null yang eksplisit menghapus filter (bukan dianggap "tidak diisi").
      final cleared = filter.copyWith(categoryId: null, search: '');
      expect(cleared.categoryId, isNull);
      expect(cleared.search, '');
      expect(cleared.hasActiveFilter, isFalse);
    });
  });
}
