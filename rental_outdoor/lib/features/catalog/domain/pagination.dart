import '../../../core/utils/parsers.dart';

/// `data.pagination` pada daftar (`/equipments`, `/equipments/{id}/reviews`).
class Pagination {
  const Pagination({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        total: parseInt(json['total']),
        page: parseInt(json['page'], fallback: 1),
        limit: parseInt(json['limit'], fallback: 10),
        totalPages: parseInt(json['total_pages']),
      );

  /// Halaman kosong (dipakai saat respons tidak sesuai kontrak).
  factory Pagination.empty() => const Pagination(
        total: 0,
        page: 1,
        limit: 10,
        totalPages: 0,
      );

  final int total;
  final int page;
  final int limit;
  final int totalPages;

  /// Masih ada halaman berikutnya (dasar infinite scroll).
  bool get hasNextPage => page < totalPages;

  /// Nomor halaman berikutnya.
  int get nextPage => page + 1;
}
