import 'package:flutter_test/flutter_test.dart';
import 'package:rental_outdoor/features/admin/domain/admin_report.dart';

void main() {
  group('RevenueReport parser', () {
    test('parse json lengkap dengan angka string & number', () {
      final json = {
        'start_date': '2026-10-01',
        'end_date': '2026-10-31',
        'period': 'daily',
        'rows': [
          {
            'period': '2026-10-08',
            'orders': 3,
            'pending_orders': '1',
            'revenue': '1350000.00',
          },
          {
            'period': '2026-10-09',
            'orders': 2,
            'pending_orders': '0',
            'revenue': '450000.00',
          },
        ],
      };

      final report = RevenueReport.fromJson(json);

      expect(report.startDate, '2026-10-01');
      expect(report.endDate, '2026-10-31');
      expect(report.period, 'daily');
      expect(report.rows.length, 2);

      final row1 = report.rows[0];
      expect(row1.period, '2026-10-08');
      expect(row1.orders, 3);
      expect(row1.pendingOrders, 1);
      expect(row1.revenue, 1350000.0);

      expect(report.totalOrders, 5);
      expect(report.totalRevenue, 1800000.0);
    });

    test('parse json kosong menghasilkan default aman', () {
      final report = RevenueReport.fromJson({});
      expect(report.startDate, '');
      expect(report.endDate, '');
      expect(report.period, 'daily');
      expect(report.rows, isEmpty);
      expect(report.totalOrders, 0);
      expect(report.totalRevenue, 0.0);
    });
  });

  group('EquipmentReport parser', () {
    test('parse json lengkap dengan angka string & number', () {
      final json = {
        'start_date': '2026-10-01',
        'end_date': '2026-10-31',
        'rows': [
          {
            'id': 1,
            'name': 'Tenda Kapasitas 4 Orang',
            'category_name': 'Tenda',
            'bookings_count': 2,
            'total_quantity': '3',
            'revenue': '450000.00',
          },
          {
            'id': 2,
            'name': 'Carrier 60L',
            'category_name': 'Tas',
            'bookings_count': 1,
            'total_quantity': '1',
            'revenue': '150000.00',
          },
        ],
      };

      final report = EquipmentReport.fromJson(json);

      expect(report.startDate, '2026-10-01');
      expect(report.endDate, '2026-10-31');
      expect(report.rows.length, 2);

      final row1 = report.rows[0];
      expect(row1.id, 1);
      expect(row1.name, 'Tenda Kapasitas 4 Orang');
      expect(row1.categoryName, 'Tenda');
      expect(row1.bookingsCount, 2);
      expect(row1.totalQuantity, 3);
      expect(row1.revenue, 450000.0);

      expect(report.totalRevenue, 600000.0);
    });

    test('parse json kosong menghasilkan default aman', () {
      final report = EquipmentReport.fromJson({});
      expect(report.startDate, '');
      expect(report.endDate, '');
      expect(report.rows, isEmpty);
      expect(report.totalRevenue, 0.0);
    });
  });
}
