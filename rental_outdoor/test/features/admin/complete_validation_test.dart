import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/features/admin/presentation/admin_complete_input.dart';

/// Validasi form **Selesaikan Sewa** (tanpa jaringan).
///
/// Aturan server (API_DOCS.md bagian 10): `return_condition` wajib
/// `good|damaged|lost`; `damage_fee` wajib & tidak negatif HANYA saat
/// `damaged`; `actual_return_date` tidak boleh sebelum `pickup_date`;
/// `late_days` TIDAK pernah dihitung client.
void main() {
  final pickup = DateTime(2026, 11, 1);

  String? validate({
    String returnCondition = 'good',
    DateTime? actualReturnDate,
    String? damageFeeText,
    String? returnNotes,
  }) =>
      validateCompleteInput(
        returnCondition: returnCondition,
        actualReturnDate: actualReturnDate ?? DateTime(2026, 11, 5),
        pickupDate: pickup,
        damageFeeText: damageFeeText,
        returnNotes: returnNotes,
      );

  group('return_condition', () {
    test('kondisi tidak dikenal -> ditolak', () {
      expect(
        validate(returnCondition: 'buruk'),
        'Pilih kondisi alat saat kembali.',
      );
      expect(validate(returnCondition: ''), isNotNull);
    });

    test('good / damaged / lost diterima (label Indonesia tersedia)', () {
      expect(validate(returnCondition: 'good'), isNull);
      expect(validate(returnCondition: 'lost'), isNull);
      expect(returnConditionLabel('good'), 'Baik');
      expect(returnConditionLabel('damaged'), 'Rusak');
      expect(returnConditionLabel('lost'), 'Hilang');
    });
  });

  group('damage_fee', () {
    test('wajib diisi saat kondisi "Rusak"', () {
      expect(
        validate(returnCondition: 'damaged'),
        'Biaya kerusakan wajib diisi saat kondisi "Rusak".',
      );
      expect(
        validate(returnCondition: 'damaged', damageFeeText: '   '),
        'Biaya kerusakan wajib diisi saat kondisi "Rusak".',
      );
    });

    test('tidak boleh negatif', () {
      expect(
        validate(returnCondition: 'damaged', damageFeeText: '-5000'),
        'Biaya kerusakan tidak boleh negatif.',
      );
    });

    test('harus berupa angka', () {
      expect(
        validate(returnCondition: 'damaged', damageFeeText: 'rusak'),
        'Biaya kerusakan harus angka, misalnya 150000.',
      );
      expect(
        validate(returnCondition: 'damaged', damageFeeText: '12,5'),
        'Biaya kerusakan harus angka, misalnya 150000.',
      );
    });

    test('angka valid diterima (termasuk desimal titik)', () {
      expect(
        validate(returnCondition: 'damaged', damageFeeText: '150000'),
        isNull,
      );
      expect(
        validate(returnCondition: 'damaged', damageFeeText: '150000.50'),
        isNull,
      );
      expect(parseDamageFee('150000'), 150000);
      expect(parseDamageFee('150000.50'), 150000.5);
    });

    test('TIDAK dituntut untuk kondisi selain "Rusak"', () {
      expect(validate(returnCondition: 'good'), isNull);
      expect(validate(returnCondition: 'lost'), isNull);
      expect(
        validate(returnCondition: 'good', damageFeeText: 'bukan-angka'),
        isNull,
        reason: 'field disembunyikan sehingga isian diabaikan server',
      );
    });

    test('parseDamageFee menolak nilai kosong / negatif / bukan angka', () {
      expect(parseDamageFee(null), isNull);
      expect(parseDamageFee(''), isNull);
      expect(parseDamageFee('  '), isNull);
      expect(parseDamageFee('-1'), isNull);
      expect(parseDamageFee('150000.00.1'), isNull);
      expect(parseDamageFee('Rp 150000'), isNull);
    });
  });

  group('actual_return_date', () {
    test('sebelum tanggal ambil -> ditolak', () {
      expect(
        validate(actualReturnDate: DateTime(2026, 10, 31)),
        'Tanggal kembali tidak boleh sebelum tanggal ambil.',
      );
    });

    test('sama dengan tanggal ambil atau sesudahnya -> diterima', () {
      expect(validate(actualReturnDate: pickup), isNull);
      expect(validate(actualReturnDate: DateTime(2026, 11, 2)), isNull);
    });

    test('perbandingan memakai tanggal saja (jam diabaikan)', () {
      expect(
        validate(actualReturnDate: DateTime(2026, 11, 1, 23, 59)),
        isNull,
      );
    });
  });

  group('return_notes', () {
    test('opsional dan boleh kosong', () {
      expect(validate(returnNotes: ''), isNull);
      expect(validate(returnNotes: null), isNull);
      expect(validate(returnNotes: 'Tenda sobek di sisi kanan'), isNull);
    });

    test('maksimal 1000 karakter', () {
      expect(validate(returnNotes: 'x' * 1000), isNull);
      expect(
        validate(returnNotes: 'x' * 1001),
        'Catatan kondisi maksimal 1000 karakter.',
      );
    });
  });

  group('kombinasi', () {
    test('semua valid -> null (siap dikirim tanpa late_days)', () {
      expect(
        validate(
          returnCondition: 'damaged',
          damageFeeText: '150000',
          actualReturnDate: DateTime(2026, 11, 6),
          returnNotes: 'Bodi penyok',
        ),
        isNull,
      );
    });

    test('kondisi rusak + tanggal lebih awal -> tanggal dilaporkan duluan', () {
      expect(
        validate(
          returnCondition: 'damaged',
          actualReturnDate: DateTime(2026, 10, 1),
        ),
        'Tanggal kembali tidak boleh sebelum tanggal ambil.',
      );
    });
  });
}
