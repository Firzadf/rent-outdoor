import '../../../core/utils/parsers.dart';

/// Hasil `GET /equipments/{id}/availability`.
///
/// API_DOCS: semua field bertipe number (`stock`, `booked`,
/// `available_stock`) + boolean `is_available` — tetap dibaca lewat
/// parser aman (bukan cast `as int`).
class AvailabilityResult {
  const AvailabilityResult({
    required this.equipmentId,
    required this.stock,
    required this.booked,
    required this.availableStock,
    required this.isAvailable,
  });

  factory AvailabilityResult.fromJson(Map<String, dynamic> json) =>
      AvailabilityResult(
        equipmentId: parseInt(json['equipment_id']),
        stock: parseInt(json['stock']),
        booked: parseInt(json['booked']),
        availableStock: parseInt(json['available_stock']),
        isAvailable: parseBool(json['is_available']),
      );

  final int equipmentId;

  /// Stok total alat.
  final int stock;

  /// Unit yang sudah dibooking untuk rentang tanggal itu.
  final int booked;

  /// `stock - booked` — batas maksimal jumlah yang bisa dipilih.
  final int availableStock;

  /// `true` bila tersedia pada tanggal tersebut.
  final bool isAvailable;

  /// Bisa disewa pada rentang tanggal ini.
  bool get rentable => isAvailable && availableStock > 0;
}
