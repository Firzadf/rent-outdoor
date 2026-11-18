import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rental_outdoor/core/utils/image_upload.dart';

void main() {
  group('image_upload helper', () {
    group('detectMimeFromBytes', () {
      test('JPEG: FF D8 FF → image/jpeg', () {
        final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
        expect(detectMimeFromBytes(bytes), equals('image/jpeg'));
      });

      test('PNG: 89 50 4E 47 → image/png', () {
        final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
        expect(detectMimeFromBytes(bytes), equals('image/png'));
      });

      test('WEBP: RIFF + WEBP → image/webp', () {
        final bytes = Uint8List.fromList([
          0x52, 0x49, 0x46, 0x46, // RIFF
          0x00, 0x00, 0x00, 0x00, // size
          0x57, 0x45, 0x42, 0x50, // WEBP
        ]);
        expect(detectMimeFromBytes(bytes), equals('image/webp'));
      });

      test('unknown format → null', () {
        final bytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
        expect(detectMimeFromBytes(bytes), isNull);
      });

      test('kosong → null', () {
        expect(detectMimeFromBytes(Uint8List(0)), isNull);
      });

      test('text file .jpg (bukan JPEG asli) → null', () {
        final textBytes = Uint8List.fromList('fake jpeg'.codeUnits);
        expect(detectMimeFromBytes(textBytes), isNull);
      });
    });

    group('extensionFromMime', () {
      test('image/jpeg → jpg', () {
        expect(extensionFromMime('image/jpeg'), equals('jpg'));
      });

      test('image/png → png', () {
        expect(extensionFromMime('image/png'), equals('png'));
      });

      test('image/webp → webp', () {
        expect(extensionFromMime('image/webp'), equals('webp'));
      });

      test('unknown MIME → jpg (fallback)', () {
        expect(extensionFromMime('image/unknown'), equals('jpg'));
      });
    });

    group('createImageMultipartFile', () {
      test('JPEG file valid → MultipartFile with jpeg MIME', () async {
        // JPEG header
        final bytes = Uint8List.fromList([
          0xFF, 0xD8, 0xFF, 0xE0,
          // ... lebih banyak byte untuk ukuran > 0
          ...List<int>.filled(100, 0xFF),
        ]);

        final xfile = _MockXFile(bytes: bytes, name: 'test.jpg');
        final mf = await createImageMultipartFile(xfile);

        expect(mf.contentType?.mimeType, equals('image/jpeg'));
        expect(mf.filename, endsWith('.jpg'));
      });

      test('PNG file valid → MultipartFile with png MIME', () async {
        final bytes = Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47,
          ...List<int>.filled(100, 0x00),
        ]);

        final xfile = _MockXFile(bytes: bytes, name: 'test.png');
        final mf = await createImageMultipartFile(xfile);

        expect(mf.contentType?.mimeType, equals('image/png'));
        expect(mf.filename, endsWith('.png'));
      });

      test('kosong → throw', () async {
        final xfile = _MockXFile(bytes: Uint8List(0), name: 'empty.jpg');
        expect(
          () => createImageMultipartFile(xfile),
          throwsA(isA<String>()),
        );
      });

      test('unknown format (text) → throw dengan pesan ramah', () async {
        final bytes = Uint8List.fromList('hello'.codeUnits);
        final xfile = _MockXFile(bytes: bytes, name: 'text.jpg');

        expect(
          () => createImageMultipartFile(xfile),
          throwsA(
            isA<String>().having(
              (e) => e,
              'message',
              contains('Format gambar tidak valid'),
            ),
          ),
        );
      });

      test('exceed 2 MB → throw dengan ukuran', () async {
        final bytes = Uint8List(2 * 1024 * 1024 + 1);
        bytes[0] = 0xFF;
        bytes[1] = 0xD8;
        bytes[2] = 0xFF;

        final xfile = _MockXFile(bytes: bytes, name: 'big.jpg');

        expect(
          () => createImageMultipartFile(xfile),
          throwsA(
            isA<String>().having(
              (e) => e,
              'message',
              contains('2 MB'),
            ),
          ),
        );
      });

      test('filename dibangun ulang dengan ekstensi MIME', () async {
        // JPEG dengan nama asli `.png` (salah ketik)
        final bytes = Uint8List.fromList([
          0xFF, 0xD8, 0xFF, 0xE0,
          ...List<int>.filled(100, 0xFF),
        ]);

        final xfile = _MockXFile(bytes: bytes, name: 'photo.png');
        final mf = await createImageMultipartFile(xfile);

        // Filename harus .jpg, bukan .png
        expect(mf.filename, endsWith('.jpg'));
        expect(mf.filename, isNot(endsWith('.png')));
      });
    });

    group('createPaymentProofMultipartFile', () {
      test('5 MB valid → MultipartFile', () async {
        final bytes = Uint8List(5 * 1024 * 1024);
        bytes[0] = 0xFF;
        bytes[1] = 0xD8;
        bytes[2] = 0xFF;

        final xfile = _MockXFile(bytes: bytes, name: 'proof.jpg');
        final mf = await createPaymentProofMultipartFile(xfile);

        expect(mf.contentType?.mimeType, equals('image/jpeg'));
      });

      test('exceed 5 MB → throw', () async {
        final bytes = Uint8List(5 * 1024 * 1024 + 1);
        bytes[0] = 0xFF;
        bytes[1] = 0xD8;
        bytes[2] = 0xFF;

        final xfile = _MockXFile(bytes: bytes, name: 'proof.jpg');

        expect(
          () => createPaymentProofMultipartFile(xfile),
          throwsA(
            isA<String>().having(
              (e) => e,
              'message',
              contains('5 MB'),
            ),
          ),
        );
      });
    });

    group('bustCache', () {
      test('URL tanpa query → tambah ?v=version', () {
        final url = 'http://localhost/uploads/photo.jpg';
        final result = bustCache(url, version: 'v1');
        expect(result, equals('http://localhost/uploads/photo.jpg?v=v1'));
      });

      test('URL sudah ada query → tambah &v=version', () {
        final url = 'http://localhost/uploads/photo.jpg?size=large';
        final result = bustCache(url, version: 'v1');
        expect(result, equals('http://localhost/uploads/photo.jpg?size=large&v=v1'));
      });

      test('version null → gunakan timestamp', () {
        final url = 'http://localhost/uploads/photo.jpg';
        final result = bustCache(url);
        expect(result, startsWith('http://localhost/uploads/photo.jpg?v='));
        expect(result, isNot(equals(url)));
      });

      test('URL kosong → tetap kosong', () {
        expect(bustCache(''), equals(''));
      });
    });
  });
}

class _MockXFile extends XFile {
  _MockXFile({required this.bytes, required this.name})
      : super('');

  final Uint8List bytes;

  @override
  final String name;

  @override
  Future<Uint8List> readAsBytes() async => bytes;
}
