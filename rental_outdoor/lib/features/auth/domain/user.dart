import '../../../core/utils/parsers.dart';

/// Model user (dari `POST /auth/register`, `POST /auth/login`,
/// `GET /auth/me`, dan `GET /user/profile`).
class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.address,
    this.profileImage,
    this.profileImageUrl,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: parseInt(json['id']),
        email: parseString(json['email']) ?? '',
        name: parseString(json['name']) ?? '',
        role: parseString(json['role']) ?? 'customer',
        phone: parseString(json['phone']),
        address: parseString(json['address']),
        profileImage: parseString(json['profile_image']),
        profileImageUrl: parseString(json['profile_image_url']),
        isActive: parseBool(json['is_active'], fallback: true),
        createdAt: parseString(json['created_at']),
        updatedAt: parseString(json['updated_at']),
      );

  /// Semua angka dibaca lewat parser aman (bukan cast `as int`).
  final int id;
  final String email;
  final String name;

  /// `customer` | `admin`.
  final String role;
  final String? phone;
  final String? address;
  final String? profileImage;

  /// URL lengkap (hanya muncul bila [profileImage] terisi).
  final String? profileImageUrl;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  bool get isAdmin => role == 'admin';
  String get roleLabel => isAdmin ? 'Admin' : 'Customer';

  User copyWith({
    String? name,
    String? phone,
    String? address,
    String? profileImage,
    String? profileImageUrl,
  }) =>
      User(
        id: id,
        email: email,
        name: name ?? this.name,
        role: role,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        profileImage: profileImage ?? this.profileImage,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
