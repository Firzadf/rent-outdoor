import '../../../core/utils/parsers.dart';
import '../../catalog/domain/pagination.dart';

/// User dari `GET /admin/users` (API_DOCS.md bagian 12).
class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.address,
    this.profileImage,
    required this.role,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: parseInt(json['id']),
        email: parseString(json['email']) ?? '',
        name: parseString(json['name']) ?? '',
        phone: parseString(json['phone']),
        address: parseString(json['address']),
        profileImage: parseString(json['profile_image']),
        role: parseString(json['role']) ?? 'customer',
        isActive: parseBool(json['is_active'], fallback: true),
        createdAt: parseString(json['created_at']),
        updatedAt: parseString(json['updated_at']),
      );

  final int id;
  final String email;
  final String name;
  final String? phone;
  final String? address;
  final String? profileImage;
  final String role;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  AdminUser copyWith({bool? isActive}) => AdminUser(
        id: id,
        email: email,
        name: name,
        phone: phone,
        address: address,
        profileImage: profileImage,
        role: role,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// Hasil satu halaman `GET /admin/users`.
class AdminUsersPage {
  const AdminUsersPage({required this.items, required this.pagination});

  factory AdminUsersPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['users'];
    final items = <AdminUser>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) items.add(AdminUser.fromJson(item));
      }
    }
    final rawPagination = json['pagination'];
    return AdminUsersPage(
      items: items,
      pagination: rawPagination is Map<String, dynamic>
          ? Pagination.fromJson(rawPagination)
          : Pagination.empty(),
    );
  }

  factory AdminUsersPage.empty() =>
      AdminUsersPage(items: const [], pagination: Pagination.empty());

  final List<AdminUser> items;
  final Pagination pagination;
}
