import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/features/booking/domain/booking.dart';

/// Parser model booking (tanpa jaringan).
///
/// Semua angka DECIMAL server berupa STRING (API_DOCS.md bagian
/// "Tipe Angka") — harus dibaca lewat parser aman dan tidak boleh crash
/// saat field `null` atau bertipe tak terduga.
void main() {
  final bookingJson = <String, dynamic>{
    'id': 5,
    'user_id': 2,
    'booking_code': 'OR-20261008-4576',
    'pickup_date': '2026-11-01',
    'return_date': '2026-11-03',
    'actual_return_date': null,
    'total_days': 2,
    'subtotal': '300000.00',
    'deposit_total': '600000.00',
    'late_fee': '0.00',
    'damage_fee': '0.00',
    'deposit_refund': '0.00',
    'grand_total': '900000.00',
    'status': 'pending_payment',
    'notes': 'Ambil pagi hari',
    'cancellation_reason': null,
    'return_condition': null,
    'return_notes': null,
    'auto_cancel_at': '2026-10-09 13:24:32',
    'created_at': '2026-10-08 13:24:32',
    'updated_at': '2026-10-08 13:24:32',
    'items': [
      {
        'id': 1,
        'booking_id': 5,
        'equipment_id': 1,
        'quantity': 2,
        'price_per_day': '75000.00',
        'subtotal': '300000.00',
        'equipment_name': 'Tenda Kapasitas 4 Orang',
        'primary_image_url': 'http://example.test/uploads/equipments/a.jpg',
      },
    ],
    'payments': [
      {
        'id': 9,
        'booking_id': 5,
        'amount': '900000.00',
        'payment_proof': 'http://example.test/uploads/payments/a.jpg',
        'status': 'rejected',
        'rejection_reason': 'Foto buram',
        'created_at': '2026-10-08 14:00:00',
      },
      {
        'id': 12,
        'booking_id': 5,
        'amount': '900000.00',
        'payment_proof': 'http://example.test/uploads/payments/b.jpg',
        'status': 'pending',
        'rejection_reason': null,
        'created_at': '2026-10-08 15:00:00',
      },
    ],
  };

  group('Booking.fromJson — angka STRING', () {
    test('subtotal/deposit/grand_total dibaca sebagai double', () {
      final booking = Booking.fromJson(bookingJson);

      expect(booking.id, 5);
      expect(booking.userId, 2);
      expect(booking.bookingCode, 'OR-20261008-4576');
      expect(booking.totalDays, 2);
      expect(booking.subtotal, 300000);
      expect(booking.depositTotal, 600000);
      expect(booking.lateFee, 0);
      expect(booking.damageFee, 0);
      expect(booking.depositRefund, 0);
      expect(booking.grandTotal, 900000);
      expect(booking.status, BookingStatus.pendingPayment);
      expect(booking.notes, 'Ambil pagi hari');
      expect(booking.cancellationReason, isNull);
      expect(booking.returnCondition, isNull);
      expect(booking.returnNotes, isNull);
      expect(booking.pickupDate, '2026-11-01');
      expect(booking.returnDate, '2026-11-03');
      expect(booking.actualReturnDate, isNull);
      expect(booking.autoCancelAtDate, DateTime(2026, 10, 9, 13, 24, 32));
    });

    test('items[]: quantity number, harga STRING, nama + gambar', () {
      final booking = Booking.fromJson(bookingJson);
      final item = booking.items.single;

      expect(item.equipmentId, 1);
      expect(item.quantity, 2);
      expect(item.pricePerDay, 75000);
      expect(item.subtotal, 300000);
      expect(item.equipmentName, 'Tenda Kapasitas 4 Orang');
      expect(item.primaryImageUrl, endsWith('a.jpg'));
    });

    test('payments[]: amount STRING, lastPayment = id terbesar', () {
      final booking = Booking.fromJson(bookingJson);

      expect(booking.payments, hasLength(2));
      expect(booking.payments.first.amount, 900000);
      expect(booking.lastPayment, isNotNull);
      expect(booking.lastPayment!.id, 12);
      expect(booking.lastPayment!.isPending, isTrue);
      // Pembayaran id 9 memang ditolak, tapi bukan yang terakhir.
      expect(booking.payments.first.isRejected, isTrue);
      expect(booking.payments.first.rejectionReason, 'Foto buram');
    });

    test('angka number (int) juga diterima', () {
      final booking = Booking.fromJson(const {
        'id': 7,
        'booking_code': 'OR-1',
        'status': 'completed',
        'grand_total': 900000,
        'subtotal': 300000,
      });

      expect(booking.grandTotal, 900000);
      expect(booking.subtotal, 300000);
      expect(booking.canReview, isTrue);
    });
  });

  group('Booking.fromJson — field null / tipe salah', () {
    test('JSON kosong tetap menghasilkan objek aman', () {
      final booking = Booking.fromJson(const {});

      expect(booking.id, 0);
      expect(booking.bookingCode, '');
      expect(booking.status, BookingStatus.pendingPayment);
      expect(booking.totalDays, 0);
      expect(booking.subtotal, 0);
      expect(booking.grandTotal, 0);
      expect(booking.items, isEmpty);
      expect(booking.payments, isEmpty);
      expect(booking.lastPayment, isNull);
      expect(booking.autoCancelAtDate, isNull);
    });

    test('angka tidak valid -> fallback 0, items/payments bukan list -> kosong',
        () {
      final booking = Booking.fromJson(const {
        'id': '12',
        'booking_code': 'OR-2',
        'status': 'in_use',
        'grand_total': 'bukan angka',
        'total_days': '3',
        'items': 'bukan list',
        'payments': null,
      });

      expect(booking.id, 12);
      expect(booking.grandTotal, 0);
      expect(booking.totalDays, 3);
      expect(booking.items, isEmpty);
      expect(booking.payments, isEmpty);
    });
  });

  group('BookingsPage.fromJson', () {
    test('bookings[] + pagination', () {
      final page = BookingsPage.fromJson({
        'bookings': [bookingJson],
        'pagination': {'total': 3, 'page': 1, 'limit': 10, 'total_pages': 1},
      });

      expect(page.items, hasLength(1));
      expect(page.items.single.bookingCode, 'OR-20261008-4576');
      expect(page.pagination.total, 3);
      expect(page.pagination.hasNextPage, isFalse);
    });

    test('pagination multi-halaman -> hasNextPage + nextPage', () {
      final page = BookingsPage.fromJson({
        'bookings': const [],
        'pagination': {'total': 25, 'page': 2, 'limit': 10, 'total_pages': 3},
      });

      expect(page.items, isEmpty);
      expect(page.pagination.hasNextPage, isTrue);
      expect(page.pagination.nextPage, 3);
    });

    test('respons tidak sesuai kontrak -> halaman kosong tanpa crash', () {
      final page = BookingsPage.fromJson(const {'bookings': 'x'});

      expect(page.items, isEmpty);
      expect(page.pagination.total, 0);
      expect(page.pagination.hasNextPage, isFalse);
    });
  });
}
