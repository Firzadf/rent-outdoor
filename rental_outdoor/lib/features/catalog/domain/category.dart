import '../../../core/utils/parsers.dart';

/// Kategori alat (`GET /categories`, `GET /categories/{id}`).
class Category {
  const Category({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.createdAt,
    this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: parseInt(json['id']),
        name: parseString(json['name']) ?? '',
        description: parseString(json['description']),
        icon: parseString(json['icon']),
        createdAt: parseString(json['created_at']),
        updatedAt: parseString(json['updated_at']),
      );

  final int id;
  final String name;
  final String? description;

  /// Nama ikon dekoratif dari server (mis. `tent`) — dipakai opsional.
  final String? icon;
  final String? createdAt;
  final String? updatedAt;
}
