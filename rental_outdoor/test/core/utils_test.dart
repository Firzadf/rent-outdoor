import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:rental_outdoor/core/utils/formatters.dart';
import 'package:rental_outdoor/core/utils/image_url.dart';
import 'package:rental_outdoor/core/utils/parsers.dart';

void main() {
  group('parser angka (semua DECIMAL/SUM dikirim sebagai string)', () {
    test('parseDouble menerima string, number, dan null', () {
      expect(tryParseDouble('75000.00'), 75000.0);
      expect(tryParseDouble(75000), 75000.0);
      expect(tryParseDouble(null), isNull);
      expect(tryParseDouble('bukan-angka'), isNull);
      expect(parseDouble('2.50', fallback: 0), 2.5);
      expect(parseDouble('kosong', fallback: 9), 9);
    });

    test('parseInt menerima string DECIMAL hasil agregasi', () {
      expect(tryParseInt('2'), 2);
      expect(tryParseInt('75000.00'), 75000);
      expect(tryParseInt(3), 3);
      expect(tryParseInt(null), isNull);
      expect(parseInt('abc', fallback: 7), 7);
    });

    test('parseBool menerima 0/1 dan string', () {
      expect(parseBool(1), isTrue);
      expect(parseBool(0), isFalse);
      expect(parseBool('true'), isTrue);
      expect(parseBool(null, fallback: true), isTrue);
    });
  });

  group('formatter', () {
    setUpAll(() => initializeDateFormatting('id_ID'));

    test('Rupiah: Rp 75.000', () {
      expect(formatRupiah(75000), 'Rp 75.000');
      expect(formatRupiah(1500000), 'Rp 1.500.000');
      expect(formatRupiah(null), 'Rp 0');
      expect(formatRupiah(75000.00), 'Rp 75.000');
    });

    test('Tanggal: 8 Okt 2026', () {
      expect(formatDate('2026-10-08'), '8 Okt 2026');
      expect(formatDate('2026-10-08 13:24:32'), '8 Okt 2026');
      expect(formatDate(null), '-');
    });
  });

  group('helper URL gambar', () {
    test('URL lengkap dari server dipertahankan', () {
      expect(
        resolveImageUrl('http://localhost/outdoorrent/uploads/profiles/x.jpg'),
        'http://localhost/outdoorrent/uploads/profiles/x.jpg',
      );
    });

    // Sejak konversi Supabase, path relatif dipetakan ke bucket
    // equipment-images, bukan lagi ke base uploads backend PHP.
    test('path relatif (reviews[].profile_image) dipetakan ke bucket Supabase', () {
      expect(
        resolveImageUrl('uploads/profiles/x.jpg'),
        'https://mdpmdjmorihsjsdhvsbn.supabase.co'
        '/storage/v1/object/public/equipment-images/profiles/x.jpg',
      );
      expect(resolveImageUrl(null), '');
      expect(resolveImageUrl('  '), '');
    });
  });
}
