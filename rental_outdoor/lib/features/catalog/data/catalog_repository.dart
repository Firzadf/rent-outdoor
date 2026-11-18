import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_url.dart';
import '../domain/availability.dart';
import '../domain/catalog_filter.dart';
import '../domain/category.dart';
import '../domain/equipment.dart';
import '../domain/pagination.dart';
import '../domain/review.dart';

/// Katalog dari Supabase PostgREST.
///
/// Catatan: paginasi dan hitungan total dihitung di client dari
/// hasil query yang sudah difilter (data katalog masih kecil),
/// supaya tidak bergantung pada API count PostgREST yang berubah
/// antar versi supabase-dart.
final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(supabaseServiceProvider)),
);

class CatalogRepository {
  CatalogRepository(this._sb);

  final SupabaseService _sb;

  /// `categories` — publik, diurutkan id.
  Future<List<Category>> getCategories() async {
    final rows = await _sb.guard(
      () => _sb.client.from('categories').select().order('id'),
    );
    return _rows(rows).map(Category.fromJson).toList();
  }

  /// Daftar alat aktif dengan filter, urutan, dan paginasi.
  /// `sort`: `terbaru` | `termurah` | `terpopuler`.
  Future<EquipmentPage> getEquipments({
    CatalogFilter filter = const CatalogFilter(),
    int page = 1,
    int limit = 20,
  }) async {
    final rows = await _sb.guard(
      () => _sb.client
          .from('equipments')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(100),
    );
    var items = _rows(rows);
    final search = filter.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      items = items.where((row) {
        final name = (row['name'] as String? ?? '').toLowerCase();
        final desc = (row['description'] as String? ?? '').toLowerCase();
        return name.contains(search) || desc.contains(search);
      }).toList();
    }
    if (filter.categoryId != null) {
      items = items
          .where((row) => row['category_id'] == filter.categoryId)
          .toList();
    }
    if (filter.minPrice != null) {
      items = items
          .where(
            (row) =>
                (row['price_per_day'] as num? ?? 0).toDouble() >=
                filter.minPrice!,
          )
          .toList();
    }
    if (filter.maxPrice != null) {
      items = items
          .where(
            (row) =>
                (row['price_per_day'] as num? ?? 0).toDouble() <=
                filter.maxPrice!,
          )
          .toList();
    }
    switch (filter.sort) {
      case 'termurah':
        items.sort(
          (a, b) => (a['price_per_day'] as num? ?? 0)
              .compareTo(b['price_per_day'] as num? ?? 0),
        );
      case 'terpopuler':
        items.sort((a, b) {
          final byBookings = (b['total_bookings'] as num? ?? 0)
              .compareTo(a['total_bookings'] as num? ?? 0);
          if (byBookings != 0) return byBookings;
          return (b['rating_avg'] as num? ?? 0)
              .compareTo(a['rating_avg'] as num? ?? 0);
        });
      case 'terbaru':
      default:
        items.sort((a, b) {
          final aDate = (a['created_at'] as String? ?? '');
          final bDate = (b['created_at'] as String? ?? '');
          return bDate.compareTo(aDate);
        });
    }
    final total = items.length;
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 20 : limit;
    final start = (safePage - 1) * safeLimit;
    final pageItems = start >= total
        ? <Map<String, dynamic>>[]
        : items.sublist(
            start,
            (start + safeLimit).clamp(0, total),
          );
    final enriched = await _enrichEquipments(pageItems);
    return EquipmentPage(
      items: enriched.map(Equipment.fromJson).toList(),
      pagination: Pagination(
        total: total,
        page: safePage,
        limit: safeLimit,
        totalPages: total == 0 ? 0 : (total / safeLimit).ceil(),
      ),
    );
  }

  /// Alat terpopuler (total_bookings terbanyak).
  Future<List<Equipment>> getPopular({int limit = 6}) async {
    final page = await getEquipments(
      filter: const CatalogFilter(sort: 'terpopuler'),
      page: 1,
      limit: limit,
    );
    return page.items;
  }

  /// Detail alat + galeri foto + 5 ulasan terbaru.
  Future<Equipment> getDetail(int id) async {
    final row = await _sb.guard(
      () => _sb.client.from('equipments').select().eq('id', id).maybeSingle(),
    );
    if (row == null) {
      throw ApiException(statusCode: 404, message: 'Alat tidak ditemukan.');
    }
    final map = await _enrichEquipments([row]);
    final enriched = map.single;
    final images = await _imagesFor(id);
    enriched['images'] = images;
    final reviews = await _recentReviews(id, limit: 5);
    enriched['reviews'] = reviews;
    return Equipment.fromJson(enriched);
  }

  /// Ketersediaan, logika sama dengan `Booking::getAvailableStock`
  /// di PHP lama: unit yang ter-booking pada rentang tanggal itu
  /// adalah SUM quantity dari booking berstatus pending_payment,
  /// pending_verification, confirmed, atau in_use yang tanggalnya
  /// beririsan (`pickup_date <= returnDate` dan
  /// `return_date >= pickupDate`).
  Future<AvailabilityResult> getAvailability({
    required int equipmentId,
    required DateTime pickupDate,
    required DateTime returnDate,
  }) async {
    final equipment = await _sb.guard(
      () => _sb.client
          .from('equipments')
          .select('id, stock, is_active')
          .eq('id', equipmentId)
          .maybeSingle(),
    );
    if (equipment == null || equipment['is_active'] != true) {
      throw ApiException(
        statusCode: 404,
        message: 'Alat tidak ditemukan atau tidak aktif.',
      );
    }
    final stock = (equipment['stock'] as num? ?? 0).toInt();
    final pickup = formatIsoDate(pickupDate);
    final ret = formatIsoDate(returnDate);
    final items = await _sb.guard(
      () => _sb.client
          .from('booking_items')
          .select('quantity, bookings!inner(status, pickup_date, return_date)')
          .eq('equipment_id', equipmentId),
    );
    var booked = 0;
    for (final item in _rows(items)) {
      final booking = item['bookings'];
      if (booking is! Map<String, dynamic>) continue;
      final status = booking['status'] as String? ?? '';
      if (!const {
        'pending_payment',
        'pending_verification',
        'confirmed',
        'in_use',
      }.contains(status)) {
        continue;
      }
      final bPickup = (booking['pickup_date'] as String? ?? '');
      final bReturn = (booking['return_date'] as String? ?? '');
      if (bPickup.compareTo(ret) <= 0 && bReturn.compareTo(pickup) >= 0) {
        booked += (item['quantity'] as num? ?? 0).toInt();
      }
    }
    final available = stock - booked;
    return AvailabilityResult(
      equipmentId: equipmentId,
      stock: stock,
      booked: booked,
      availableStock: available,
      isAvailable: available > 0,
    );
  }

  /// Ulasan alat, halaman demi halaman.
  Future<ReviewsPage> getReviews({
    required int equipmentId,
    int page = 1,
    int limit = 10,
  }) async {
    final all = await _allReviews(equipmentId);
    final total = all.length;
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 10 : limit;
    final start = (safePage - 1) * safeLimit;
    final pageItems = start >= total
        ? <Map<String, dynamic>>[]
        : all.sublist(start, (start + safeLimit).clamp(0, total));
    return ReviewsPage(
      items: pageItems.map(Review.fromJson).toList(),
      pagination: Pagination(
        total: total,
        page: safePage,
        limit: safeLimit,
        totalPages: total == 0 ? 0 : (total / safeLimit).ceil(),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Helper
  // -------------------------------------------------------------------

  List<Map<String, dynamic>> _rows(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Future<Map<int, String>> _categoryNames() async {
    final rows = await _sb.guard(
      () => _sb.client.from('categories').select('id, name'),
    );
    final map = <int, String>{};
    for (final row in _rows(rows)) {
      final id = row['id'];
      if (id is num) map[id.toInt()] = (row['name'] as String? ?? '');
    }
    return map;
  }

  Future<Map<int, String>> _primaryImages(List<int> equipmentIds) async {
    if (equipmentIds.isEmpty) return {};
    final rows = await _sb.guard(
      () => _sb.client
          .from('equipment_images')
          .select('equipment_id, image_url, is_primary, sort_order')
          .eq('is_primary', true),
    );
    final map = <int, String>{};
    for (final row in _rows(rows)) {
      final id = row['equipment_id'];
      if (id is num && equipmentIds.contains(id.toInt())) {
        map[id.toInt()] = (row['image_url'] as String? ?? '');
      }
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> _enrichEquipments(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return [];
    final categories = await _categoryNames();
    final ids = rows.map((r) => (r['id'] as num? ?? 0).toInt()).toList();
    final primaries = await _primaryImages(ids);
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row);
      final categoryId = (row['category_id'] as num? ?? 0).toInt();
      map['category_name'] = categories[categoryId];
      final primary = primaries[(row['id'] as num? ?? 0).toInt()];
      map['primary_image_url'] =
          primary == null ? null : resolveImageUrl(primary);
      return map;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _imagesFor(int equipmentId) async {
    final rows = await _sb.guard(
      () => _sb.client
          .from('equipment_images')
          .select()
          .eq('equipment_id', equipmentId)
          .order('is_primary', ascending: false)
          .order('sort_order'),
    );
    final images = _rows(rows).map((row) {
      final map = Map<String, dynamic>.from(row);
      map['image_url'] = resolveImageUrl(map['image_url'] as String?);
      return map;
    }).toList();
    return images;
  }

  Future<List<Map<String, dynamic>>> _allReviews(int equipmentId) async {
    final rows = await _sb.guard(
      () => _sb.client
          .from('reviews')
          .select()
          .eq('equipment_id', equipmentId)
          .order('created_at', ascending: false),
    );
    final reviews = _rows(rows);
    if (reviews.isEmpty) return [];
    final userIds = reviews
        .map((r) => r['user_id'])
        .whereType<num>()
        .map((n) => n.toInt())
        .toSet();
    final users = <int, Map<String, dynamic>>{};
    for (final userId in userIds) {
      final user = await _sb.guard(
        () => _sb.client
            .from('users')
            .select('id, name, profile_image')
            .eq('id', userId)
            .maybeSingle(),
      );
      if (user != null) users[userId] = user;
    }
    return reviews.map((row) {
      final map = Map<String, dynamic>.from(row);
      final user = users[(row['user_id'] as num? ?? 0).toInt()];
      map['user_name'] = user?['name'] as String?;
      map['profile_image'] = user?['profile_image'] as String?;
      return map;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _recentReviews(
    int equipmentId, {
    int limit = 5,
  }) async {
    final all = await _allReviews(equipmentId);
    return all.take(limit).toList();
  }
}
