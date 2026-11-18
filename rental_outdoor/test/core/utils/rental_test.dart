import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/core/utils/rental.dart';

/// Aturan hitung dari API_DOCS.md:
/// `total_days = return_date - pickup_date` dalam hari, tanpa +1,
/// minimal 1; tanggal lampau ditolak.
void main() {
  group('calculateTotalDays (tanpa +1)', () {
    test('1 Nov -> 3 Nov = 2 hari (bukan 3)', () {
      expect(
        calculateTotalDays(DateTime(2026, 11, 1), DateTime(2026, 11, 3)),
        2,
      );
    });

    test('satu hari penuh = 1', () {
      expect(
        calculateTotalDays(DateTime(2026, 11, 1), DateTime(2026, 11, 2)),
        1,
      );
    });

    test('hari yang sama = 0 (tidak valid untuk sewa)', () {
      final day = DateTime(2026, 11, 1);
      expect(calculateTotalDays(day, day), 0);
    });

    test('waktu (jam) diabaikan — hanya tanggal murni', () {
      expect(
        calculateTotalDays(
          DateTime(2026, 11, 1, 13, 45),
          DateTime(2026, 11, 3, 8, 10),
        ),
        2,
      );
      expect(
        calculateTotalDays(
          DateTime(2026, 11, 1, 23, 59),
          DateTime(2026, 11, 2, 0, 1),
        ),
        1,
      );
    });

    test('melewati batas bulan', () {
      expect(
        calculateTotalDays(DateTime(2026, 4, 30), DateTime(2026, 5, 2)),
        2,
      );
    });

    test('tanggal kembali sebelum tanggal ambil -> negatif', () {
      expect(
        calculateTotalDays(DateTime(2026, 11, 3), DateTime(2026, 11, 1)),
        -2,
      );
    });
  });

  group('isValidRentalRange', () {
    final today = DateTime(2026, 10, 8);

    test('menolak tanggal lampau (pickup sebelum hari ini)', () {
      expect(
        isValidRentalRange(
          DateTime(2026, 10, 7),
          DateTime(2026, 10, 9),
          today: today,
        ),
        isFalse,
      );
    });

    test('mengizinkan ambil hari ini (bukan lampau)', () {
      expect(
        isValidRentalRange(
          DateTime(2026, 10, 8),
          DateTime(2026, 10, 9),
          today: today,
        ),
        isTrue,
      );
    });

    test('menolak durasi 0 (return == pickup, minimal 1 malam)', () {
      expect(
        isValidRentalRange(
          DateTime(2026, 10, 8),
          DateTime(2026, 10, 8),
          today: today,
        ),
        isFalse,
      );
    });

    test('menolak return_date sebelum pickup_date', () {
      expect(
        isValidRentalRange(
          DateTime(2026, 10, 9),
          DateTime(2026, 10, 8),
          today: today,
        ),
        isFalse,
      );
    });

    test('waktu hari yang sama tidak membatalkan aturan tanggal', () {
      expect(
        isValidRentalRange(
          DateTime(2026, 10, 8, 23, 59),
          DateTime(2026, 10, 9, 0, 1),
          today: today,
        ),
        isTrue,
      );
    });

    test('default memakai hari ini bila today tidak diisi', () {
      final now = DateTime.now();
      final todayOnly = DateTime(now.year, now.month, now.day);
      expect(
        isValidRentalRange(todayOnly, todayOnly.add(const Duration(days: 1))),
        isTrue,
      );
      expect(
        isValidRentalRange(
          todayOnly.subtract(const Duration(days: 1)),
          todayOnly,
        ),
        isFalse,
      );
    });
  });
}
