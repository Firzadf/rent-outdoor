import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/features/cart/domain/cart_item.dart';
import 'package:rental_outdoor/features/cart/presentation/cart_provider.dart';

/// Aturan hitung estimasi keranjang (API_DOCS.md "Aturan Hitung"):
/// `total_days = return_date - pickup_date` TANPA +1,
/// `subtotal` = Σ(`price_per_day × quantity × total_days`),
/// `deposit_total` = Σ(`deposit × quantity`),
/// `grand_total` = `subtotal + deposit_total`.
void main() {
  const tenda = CartItem(
    equipmentId: 1,
    name: 'Tenda Kapasitas 4 Orang',
    pricePerDay: 75000,
    deposit: 300000,
    quantity: 2,
    stock: 10,
  );
  const lampu = CartItem(
    equipmentId: 2,
    name: 'Lampu Tenda',
    pricePerDay: 20000,
    deposit: 0,
    quantity: 1,
    stock: 5,
  );

  group('computeCartTotals', () {
    test('total_days tanpa +1: 1 Nov -> 3 Nov = 2 hari', () {
      final totals = computeCartTotals(
        const [tenda, lampu],
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 3),
      );

      expect(totals.totalDays, 2);
    });

    test('subtotal, deposit, dan total sesuai rumus server', () {
      final totals = computeCartTotals(
        const [tenda, lampu],
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 3),
      );

      // 75000 × 2 × 2 = 300000 ; 20000 × 1 × 2 = 40000
      expect(totals.subtotal, 340000);
      // 300000 × 2 = 600000 ; deposit 0
      expect(totals.depositTotal, 600000);
      expect(totals.grandTotal, 940000);
    });

    test('satu hari penuh (1 Nov -> 2 Nov) tetap 1 hari', () {
      final totals = computeCartTotals(
        const [tenda],
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 2),
      );

      expect(totals.totalDays, 1);
      expect(totals.subtotal, 150000); // 75000 × 2 × 1
      expect(totals.depositTotal, 600000);
      expect(totals.grandTotal, 750000);
    });

    test('waktu (jam) diabaikan — hanya tanggal murni', () {
      final totals = computeCartTotals(
        const [tenda],
        DateTime(2026, 11, 1, 23, 59),
        DateTime(2026, 11, 3, 0, 1),
      );

      expect(totals.totalDays, 2);
    });

    test('keranjang kosong -> semua nol', () {
      final totals = computeCartTotals(
        const [],
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 3),
      );

      expect(totals.subtotal, 0);
      expect(totals.depositTotal, 0);
      expect(totals.grandTotal, 0);
    });
  });

  group('CartState', () {
    test('totals null bila tanggal belum dipilih', () {
      const state = CartState(items: [tenda]);
      expect(state.hasValidRange, isFalse);
      expect(state.totalDays, isNull);
      expect(state.totals, isNull);
    });

    test('rentang tidak valid (return == pickup) -> tanpa estimasi', () {
      final state = CartState(
        items: const [tenda],
        pickupDate: DateTime(2026, 11, 1),
        returnDate: DateTime(2026, 11, 1),
      );
      expect(state.hasValidRange, isFalse);
      expect(state.totals, isNull);
    });

    test('totalQuantity = jumlah semua quantity', () {
      const state = CartState(items: [tenda, lampu]);
      expect(state.totalQuantity, 3);
    });

    test('itemOf menemukan item berdasarkan equipment_id', () {
      const state = CartState(items: [tenda, lampu]);
      expect(state.itemOf(2)?.name, 'Lampu Tenda');
      expect(state.itemOf(99), isNull);
    });
  });
}
