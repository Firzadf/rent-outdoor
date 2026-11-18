import '../../../core/utils/parsers.dart';

/// Model profil lengkap (respons `GET/PUT /user/profile`).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    this.address,
    this.profileImage,
    this.profileImageUrl,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: parseInt(json['id']),
    email: parseString(json['email']) ?? '',
    name: parseString(json['name']) ?? '',
    phone: parseString(json['phone']) ?? '',
    address: parseString(json['address']),
    profileImage: parseString(json['profile_image']),
    profileImageUrl: parseString(json['profile_image_url']),
    role: parseString(json['role']) ?? 'customer',
    isActive: parseBool(json['is_active'], fallback: true),
    createdAt: parseString(json['created_at']),
    updatedAt: parseString(json['updated_at']),
  );

  final int id;
  final String email;
  final String name;
  final String phone;
  final String? address;
  final String? profileImage;

  /// URL lengkap foto profil (hanya muncul bila [profileImage] terisi).
  final String? profileImageUrl;
  final String role;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  UserProfile copyWith({
    String? name,
    String? phone,
    String? address,
    String? profileImage,
    String? profileImageUrl,
  }) => UserProfile(
    id: id,
    email: email,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    profileImage: profileImage ?? this.profileImage,
    profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    role: role,
    isActive: isActive,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
