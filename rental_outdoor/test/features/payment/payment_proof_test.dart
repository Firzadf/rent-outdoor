import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/features/payment/domain/payment_proof.dart';

/// Validasi bukti bayar SEBELUM `POST /payments` (API_DOCS.md bagian 8):
/// hanya jpg/png/webp, maksimal 5 MB — ukuran dicek dari PANJANG BYTES.
void main() {
  Uint8List bytesOf(int length) => Uint8List.fromList(List.filled(length, 7));

  group('validatePaymentProof — tipe file', () {
    test('jpg, jpeg, png, webp diterima', () {
      for (final name in const [
        'bukti.jpg',
        'bukti.jpeg',
        'bukti.png',
        'bukti.webp',
        'BUKTI.PNG',
      ]) {
        expect(
          validatePaymentProof(bytes: bytesOf(1024), filename: name),
          isNull,
          reason: '$name seharusnya diterima',
        );
      }
    });

    test('tipe lain ditolak dengan pesan format', () {
      for (final name in const ['bukti.pdf', 'bukti.gif', 'bukti', 'bukti.']) {
        final error = validatePaymentProof(bytes: bytesOf(1024), filename: name);
        expect(error, isNotNull, reason: '$name seharusnya ditolak');
        expect(error, contains('JPG'));
      }
    });
  });

  group('validatePaymentProof — ukuran file (panjang bytes)', () {
    test('tepat 5 MB masih diterima', () {
      expect(
        validatePaymentProof(
          bytes: bytesOf(maxPaymentProofBytes),
          filename: 'bukti.jpg',
        ),
        isNull,
      );
    });

    test('lebih dari 5 MB ditolak', () {
      final error = validatePaymentProof(
        bytes: bytesOf(maxPaymentProofBytes + 1),
        filename: 'bukti.jpg',
      );
      expect(error, isNotNull);
      expect(error, contains('5 MB'));
    });

    test('file kosong (0 byte) ditolak', () {
      final error = validatePaymentProof(bytes: bytesOf(0), filename: 'bukti.png');
      expect(error, isNotNull);
      expect(error, contains('kosong'));
    });
  });

  group('paymentProofMediaType', () {
    test('MIME sesuai ekstensi (untuk contentType multipart)', () {
      expect(paymentProofMediaType('bukti.jpg'), 'image/jpeg');
      expect(paymentProofMediaType('bukti.JPEG'), 'image/jpeg');
      expect(paymentProofMediaType('bukti.png'), 'image/png');
      expect(paymentProofMediaType('bukti.webp'), 'image/webp');
    });
  });

  group('paymentProofExtension', () {
    test('ambil ekstensi huruf kecil tanpa titik', () {
      expect(paymentProofExtension('a/b/BUKTI.Jpg'), 'jpg');
      expect(paymentProofExtension('bukti'), '');
      expect(paymentProofExtension('bukti.'), '');
    });
  });
}
