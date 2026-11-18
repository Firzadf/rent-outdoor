import '../../../core/utils/parsers.dart';
import 'pagination.dart';

/// Satu ulasan alat.
///
/// Dua bentuk nama reviewer di API:
/// - `GET /equipments/{id}` -> `reviews[].user_name` (maks. 5 terbaru)
/// - `GET /equipments/{id}/reviews` -> `reviews[].reviewer_name`
class Review {
  const Review({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.equipmentId,
    required this.rating,
    this.comment,
    this.createdAt,
    this.updatedAt,
    this.userName,
    this.profileImage,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: parseInt(json['id']),
        bookingId: parseInt(json['booking_id']),
        userId: parseInt(json['user_id']),
        equipmentId: parseInt(json['equipment_id']),
        rating: parseInt(json['rating']),
        comment: parseString(json['comment']),
        createdAt: parseString(json['created_at']),
        updatedAt: parseString(json['updated_at']),
        userName: parseString(json['user_name']) ??
            parseString(json['reviewer_name']),
        // SATU-SATUNYA gambar berupa path relatif (mis.
        // `uploads/profiles/x.jpg`) -> gabungkan dengan `resolveImageUrl`
        // saat ditampilkan.
        profileImage: parseString(json['profile_image']),
      );

  final int id;
  final int bookingId;
  final int userId;
  final int equipmentId;

  /// 1–5 (angka biasa dari server, tetap lewat parser aman).
  final int rating;
  final String? comment;
  final String? createdAt;
  final String? updatedAt;
  final String? userName;
  final String? profileImage;

  /// Inisial untuk avatar pengganti (mis. `JD`).
  String get initials {
    final source = userName ?? 'Pengguna';
    final parts =
        source.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

/// Hasil `GET /equipments/{id}/reviews`: daftar + pagination.
class ReviewsPage {
  const ReviewsPage({required this.items, required this.pagination});

  factory ReviewsPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['reviews'];
    final items = <Review>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) items.add(Review.fromJson(item));
      }
    }
    final rawPagination = json['pagination'];
    return ReviewsPage(
      items: items,
      pagination: rawPagination is Map<String, dynamic>
          ? Pagination.fromJson(rawPagination)
          : Pagination.empty(),
    );
  }

  final List<Review> items;
  final Pagination pagination;
}
