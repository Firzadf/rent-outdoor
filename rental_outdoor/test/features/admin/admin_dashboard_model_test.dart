import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/features/admin/domain/admin_dashboard.dart';

/// Parser dashboard admin (`GET /admin/dashboard`, API_DOCS.md bagian 11).
///
/// Angka responsnya CAMPURAN: `total_orders`/`total_revenue`/dst. number,
/// sedangkan `top_equipments[].total_rentals` STRING (hasil `SUM()`).
/// Parser aman harus menerima keduanya tanpa cast langsung.
void main() {
  group('AdminDashboard.fromJson — campuran number & string', () {
    test('bentuk asli server (angka number + total_rentals string)', () {
      final dashboard = AdminDashboard.fromJson(const {
        'total_orders': 4,
        'total_revenue': 1350000,
        'pending_verification_count': 1,
        'active_rentals_count': 2,
        'top_equipments': [
          {'id': 1, 'name': 'Tenda Kapasitas 4 Orang', 'total_rentals': '2'},
          {'id': 2, 'name': 'Sleeping Bag', 'total_rentals': 5},
        ],
      });

      expect(dashboard.totalOrders, 4);
      expect(dashboard.totalRevenue, 1350000);
      expect(dashboard.pendingVerificationCount, 1);
      expect(dashboard.activeRentalsCount, 2);
      expect(dashboard.topEquipments, hasLength(2));
      expect(dashboard.topEquipments.first.name, 'Tenda Kapasitas 4 Orang');
      expect(dashboard.topEquipments.first.totalRentals, 2);
      expect(dashboard.topEquipments[1].totalRentals, 5);
    });

    test('semua angka berupa STRING DECIMAL tetap terbaca', () {
      final dashboard = AdminDashboard.fromJson(const {
        'total_orders': '4',
        'total_revenue': '1350000.00',
        'pending_verification_count': '1',
        'active_rentals_count': '0',
        'top_equipments': [
          {'id': '1', 'name': 'Tenda', 'total_rentals': '2'},
        ],
      });

      expect(dashboard.totalOrders, 4);
      expect(dashboard.totalRevenue, 1350000);
      expect(dashboard.pendingVerificationCount, 1);
      expect(dashboard.activeRentalsCount, 0);
      expect(dashboard.topEquipments.single.totalRentals, 2);
      expect(dashboard.topEquipments.single.id, 1);
    });

    test('revenue float number maupun string', () {
      expect(
        AdminDashboard.fromJson(const {'total_revenue': 1350000.5}).totalRevenue,
        1350000.5,
      );
      expect(
        AdminDashboard.fromJson(const {'total_revenue': '1350000.50'})
            .totalRevenue,
        1350000.5,
      );
    });
  });

  group('AdminDashboard.fromJson — data rusak / hilang', () {
    test('JSON kosong -> angka 0 + daftar kosong (tanpa crash)', () {
      final dashboard = AdminDashboard.fromJson(const {});

      expect(dashboard.totalOrders, 0);
      expect(dashboard.totalRevenue, 0);
      expect(dashboard.pendingVerificationCount, 0);
      expect(dashboard.activeRentalsCount, 0);
      expect(dashboard.topEquipments, isEmpty);
    });

    test('angka tidak valid -> fallback 0, top_equipments bukan list -> kosong',
        () {
      final dashboard = AdminDashboard.fromJson(const {
        'total_orders': 'bukan angka',
        'total_revenue': null,
        'pending_verification_count': 2.7,
        'top_equipments': 'bukan list',
      });

      expect(dashboard.totalOrders, 0);
      expect(dashboard.totalRevenue, 0);
      expect(dashboard.pendingVerificationCount, 3);
      expect(dashboard.topEquipments, isEmpty);
    });

    test('item top_equipments tanpa nama -> label aman', () {
      final dashboard = AdminDashboard.fromJson(const {
        'top_equipments': [
          {'id': 3, 'total_rentals': '7'},
        ],
      });

      final top = dashboard.topEquipments.single;
      expect(top.name, 'Tanpa nama');
      expect(top.totalRentals, 7);
      expect(top.categoryName, isNull);
    });

    test('AdminDashboard.empty() aman dipakai', () {
      final empty = AdminDashboard.empty();
      expect(empty.totalOrders, 0);
      expect(empty.topEquipments, isEmpty);
    });
  });
}
