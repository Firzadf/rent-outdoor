import '../../../core/utils/parsers.dart';

/// Satu baris laporan pendapatan dari `GET /admin/reports/revenue`.
///
/// `orders` = number, `pending_orders` + `revenue` = STRING.
class RevenueRow {
  const RevenueRow({
    required this.period,
    this.orders = 0,
    this.pendingOrders = 0,
    this.revenue = 0,
  });

  factory RevenueRow.fromJson(Map<String, dynamic> json) => RevenueRow(
        period: parseString(json['period']) ?? '',
        orders: parseInt(json['orders']),
        pendingOrders: parseInt(json['pending_orders']),
        revenue: parseDouble(json['revenue']),
      );

  /// Label periode: `2026-10-08` (daily) atau `2026-10` (monthly).
  final String period;

  /// Jumlah pesanan (number dari server).
  final int orders;

  /// Pesanan pending (STRING dari server).
  final int pendingOrders;

  /// Pendapatan (STRING DECIMAL dari server).
  final double revenue;
}

/// Respons `GET /admin/reports/revenue`.
class RevenueReport {
  const RevenueReport({
    required this.startDate,
    required this.endDate,
    required this.period,
    this.rows = const [],
  });

  factory RevenueReport.fromJson(Map<String, dynamic> json) => RevenueReport(
        startDate: parseString(json['start_date']) ?? '',
        endDate: parseString(json['end_date']) ?? '',
        period: parseString(json['period']) ?? 'daily',
        rows: _rows(json['rows']),
      );

  factory RevenueReport.empty() => const RevenueReport(
        startDate: '',
        endDate: '',
        period: 'daily',
      );

  final String startDate;
  final String endDate;
  final String period;
  final List<RevenueRow> rows;

  double get totalRevenue =>
      rows.fold<double>(0, (sum, r) => sum + r.revenue);

  int get totalOrders => rows.fold<int>(0, (sum, r) => sum + r.orders);

  static List<RevenueRow> _rows(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(RevenueRow.fromJson)
        .toList();
  }
}

/// Satu baris laporan alat dari `GET /admin/reports/equipments`.
///
/// `bookings_count` = number, `total_quantity` + `revenue` = STRING.
class EquipmentReportRow {
  const EquipmentReportRow({
    required this.id,
    required this.name,
    this.categoryName,
    this.bookingsCount = 0,
    this.totalQuantity = 0,
    this.revenue = 0,
  });

  factory EquipmentReportRow.fromJson(Map<String, dynamic> json) =>
      EquipmentReportRow(
        id: parseInt(json['id']),
        name: parseString(json['name']) ?? '',
        categoryName: parseString(json['category_name']),
        bookingsCount: parseInt(json['bookings_count']),
        totalQuantity: parseInt(json['total_quantity']),
        revenue: parseDouble(json['revenue']),
      );

  final int id;
  final String name;
  final String? categoryName;
  final int bookingsCount;
  final int totalQuantity;
  final double revenue;
}

/// Respons `GET /admin/reports/equipments`.
class EquipmentReport {
  const EquipmentReport({
    required this.startDate,
    required this.endDate,
    this.rows = const [],
  });

  factory EquipmentReport.fromJson(Map<String, dynamic> json) =>
      EquipmentReport(
        startDate: parseString(json['start_date']) ?? '',
        endDate: parseString(json['end_date']) ?? '',
        rows: _rows(json['rows']),
      );

  factory EquipmentReport.empty() => const EquipmentReport(
        startDate: '',
        endDate: '',
      );

  final String startDate;
  final String endDate;
  final List<EquipmentReportRow> rows;

  double get totalRevenue =>
      rows.fold<double>(0, (sum, r) => sum + r.revenue);

  static List<EquipmentReportRow> _rows(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(EquipmentReportRow.fromJson)
        .toList();
  }
}
