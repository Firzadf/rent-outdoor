import '../../../core/utils/parsers.dart';

/// Foto alat (`images[]` pada `GET /equipments/{id}`).
class EquipmentImage {
  const EquipmentImage({
    required this.id,
    required this.equipmentId,
    required this.imageUrl,
    this.isPrimary = false,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory EquipmentImage.fromJson(Map<String, dynamic> json) => EquipmentImage(
        id: parseInt(json['id']),
        equipmentId: parseInt(json['equipment_id']),
        // API_DOCS: `images[].image_url` SELALU URL lengkap.
        imageUrl: parseString(json['image_url']) ?? '',
        isPrimary: parseBool(json['is_primary']),
        sortOrder: parseInt(json['sort_order']),
        createdAt: parseString(json['created_at']),
      );

  final int id;
  final int equipmentId;
  final String imageUrl;
  final bool isPrimary;
  final int sortOrder;
  final String? createdAt;
}
