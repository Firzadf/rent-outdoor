import '../../../core/utils/parsers.dart';
import 'equipment_image.dart';
import 'pagination.dart';
import 'review.dart';

/// Alat outdoor.
///
/// Bentuk field number/DECIMAL mengikuti API_DOCS.md:
/// - `price_per_day`, `deposit`, `rating_avg` -> STRING ("75000.00")
///   -> wajib lewat parser aman (`parseDouble`), JANGAN `as double`.
/// - `stock`, `total_reviews`, `total_bookings`, `is_active` -> number.
///
/// `images` dan `reviews` hanya ada pada `GET /equipments/{id}`
/// (reviews maks. 5 terbaru) — daftar/populer memakai
/// `category_name` + `primary_image_url`.
class Equipment {
  const Equipment({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.pricePerDay,
    this.description,
    this.stock = 0,
    this.deposit = 0,
    this.ratingAvg = 0,
    this.totalReviews = 0,
    this.totalBookings = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.categoryName,
    this.primaryImageUrl,
    this.images = const [],
    this.reviews = const [],
  });

  factory Equipment.fromJson(Map<String, dynamic> json) => Equipment(
        id: parseInt(json['id']),
        categoryId: parseInt(json['category_id']),
        name: parseString(json['name']) ?? '',
        description: parseString(json['description']),
        // DECIMAL dari server -> string.
        pricePerDay: parseDouble(json['price_per_day']),
        stock: parseInt(json['stock']),
        deposit: parseDouble(json['deposit']),
        ratingAvg: parseDouble(json['rating_avg']),
        totalReviews: parseInt(json['total_reviews']),
        totalBookings: parseInt(json['total_bookings']),
        isActive: parseBool(json['is_active'], fallback: true),
        createdAt: parseString(json['created_at']),
        updatedAt: parseString(json['updated_at']),
        categoryName: parseString(json['category_name']),
        // Bisa `null` bila alat belum punya gambar.
        primaryImageUrl: parseString(json['primary_image_url']),
        images: _images(json['images']),
        reviews: _reviews(json['reviews']),
      );

  final int id;
  final int categoryId;
  final String name;
  final String? description;

  /// Harga sewa per hari (DECIMAL string dari server).
  final double pricePerDay;
  final int stock;
  final double deposit;
  final double ratingAvg;
  final int totalReviews;
  final int totalBookings;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  /// Ikut muncul pada daftar/populer/detail.
  final String? categoryName;

  /// URL lengkap foto utama (nullable).
  final String? primaryImageUrl;

  /// Hanya pada detail (`GET /equipments/{id}`).
  final List<EquipmentImage> images;

  /// Hanya pada detail — maksimal 5 ulasan terbaru.
  final List<Review> reviews;

  /// URL gambar untuk kartu/galeri: foto utama dulu, kalau kosong pakai
  /// gambar pertama dari galeri.
  String? get galleryCover =>
      primaryImageUrl ??
      (images.isNotEmpty ? images.first.imageUrl : null);

  static List<EquipmentImage> _images(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(EquipmentImage.fromJson)
        .toList();
  }

  static List<Review> _reviews(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Review.fromJson)
        .toList();
  }
}

/// Hasil satu halaman `GET /equipments`:
/// `data = { equipments: [...], pagination: {...} }`.
class EquipmentPage {
  const EquipmentPage({required this.items, required this.pagination});

  factory EquipmentPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['equipments'];
    final items = <Equipment>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) items.add(Equipment.fromJson(item));
      }
    }
    final rawPagination = json['pagination'];
    return EquipmentPage(
      items: items,
      pagination: rawPagination is Map<String, dynamic>
          ? Pagination.fromJson(rawPagination)
          : Pagination.empty(),
    );
  }

  /// Halaman kosong (respons tidak sesuai kontrak).
  factory EquipmentPage.empty() =>
      EquipmentPage(items: const [], pagination: Pagination.empty());

  final List<Equipment> items;
  final Pagination pagination;
}
