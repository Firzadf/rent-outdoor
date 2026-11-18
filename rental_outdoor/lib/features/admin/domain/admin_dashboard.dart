import '../../../core/utils/parsers.dart';

/// Ringkasan admin dari `GET /admin/dashboard` (API_DOCS.md bagian 11).
///
/// Tipe angka di respons ini CAMPURAN:
/// - `total_orders`, `pending_verification_count`, `active_rentals_count`,
///   `total_revenue` sudah number di server,
/// - `top_equipments[].total_rentals` berupa STRING (hasil `SUM()`).
///
/// Semua dibaca lewat parser aman sehingga menerima number maupun string
/// tanpa cast langsung.
class AdminDashboard {
  const AdminDashboard({
    this.totalOrders = 0,
    this.totalRevenue = 0,
    this.pendingVerificationCount = 0,
    this.activeRentalsCount = 0,
    this.topEquipments = const [],
  });

  factory AdminDashboard.fromJson(Map<String, dynamic> json) => AdminDashboard(
        totalOrders: parseInt(json['total_orders']),
        totalRevenue: parseDouble(json['total_revenue']),
        pendingVerificationCount: parseInt(json['pending_verification_count']),
        activeRentalsCount: parseInt(json['active_rentals_count']),
        topEquipments: _topEquipments(json['top_equipments']),
      );

  /// Respons tidak sesuai kontrak -> tampilan kosong (tanpa crash).
  factory AdminDashboard.empty() => const AdminDashboard();

  /// Jumlah semua booking (number).
  final int totalOrders;

  /// `SUM(subtotal + late_fee + damage_fee)` booking `completed`.
  /// Bisa number atau string DECIMAL — parser aman.
  final double totalRevenue;

  /// Booking `pending_verification` — kartu ini bisa diketuk untuk
  /// membuka daftar pesanan terfilter.
  final int pendingVerificationCount;

  /// Booking `confirmed` atau `in_use` (number).
  final int activeRentalsCount;

  /// 5 alat dengan `SUM(quantity)` terbanyak; `total_rentals` STRING.
  final List<TopEquipment> topEquipments;

  static List<TopEquipment> _topEquipments(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(TopEquipment.fromJson)
        .toList();
  }
}

/// Satu baris `top_equipments` pada dashboard admin.
class TopEquipment {
  const TopEquipment({
    required this.id,
    required this.name,
    this.totalRentals = 0,
    this.categoryName,
  });

  factory TopEquipment.fromJson(Map<String, dynamic> json) => TopEquipment(
        id: parseInt(json['id']),
        name: parseString(json['name']) ?? 'Tanpa nama',
        // SUM(quantity) -> STRING, tapi parser menerima keduanya.
        totalRentals: parseInt(json['total_rentals']),
        categoryName: parseString(json['category_name']),
      );

  final int id;
  final String name;

  /// Jumlah unit terdisewa (STRING dari server, dibaca parser aman).
  final int totalRentals;

  /// Tidak selalu dikirim server — opsional.
  final String? categoryName;
}
