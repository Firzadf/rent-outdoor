import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/features/admin/domain/admin_booking.dart';
import 'package:rental_outdoor/features/booking/domain/booking.dart';
import 'package:rental_outdoor/features/payment/domain/payment.dart';

/// Logika tombol aksi admin per status (API_DOCS.md bagian 10):
/// - Verifikasi: `pending_verification` + pembayaran terakhir `pending`,
/// - Mulai Sewa: `confirmed`,
/// - Selesaikan: `in_use`.
/// Tombol hanya boleh tampil bila syarat server terpenuhi.
void main() {
  AdminBooking bookingWith(
    String status, {
    List<Payment> payments = const [],
  }) =>
      AdminBooking(
        id: 1,
        bookingCode: 'OR-1',
        status: status,
        payments: payments,
      );

  Payment payment(int id, String status) =>
      Payment(id: id, bookingId: 1, status: status);

  group('canVerify (Setujui / Tolak)', () {
    test('pending_verification + pembayaran terakhir pending -> tampil', () {
      final booking = bookingWith(
        BookingStatus.pendingVerification,
        payments: [
          payment(1, PaymentStatus.approved),
          payment(2, PaymentStatus.pending),
        ],
      );
      expect(booking.canVerify, isTrue);
    });

    test('pending_verification tanpa pembayaran -> tidak tampil', () {
      expect(
        bookingWith(BookingStatus.pendingVerification).canVerify,
        isFalse,
      );
    });

    test('pending_verification + pembayaran terakhir rejected -> tidak tampil',
        () {
      final booking = bookingWith(
        BookingStatus.pendingVerification,
        payments: [
          payment(1, PaymentStatus.pending),
          payment(2, PaymentStatus.rejected),
        ],
      );
      expect(booking.canVerify, isFalse);
    });

    test('pending_verification + pembayaran terakhir approved -> tidak tampil',
        () {
      final booking = bookingWith(
        BookingStatus.pendingVerification,
        payments: [payment(1, PaymentStatus.approved)],
      );
      expect(booking.canVerify, isFalse);
    });

    test('status lain -> tidak tampil', () {
      for (final status in const [
        BookingStatus.pendingPayment,
        BookingStatus.confirmed,
        BookingStatus.inUse,
        BookingStatus.completed,
        BookingStatus.cancelled,
        BookingStatus.rejected,
        'status_baru_server',
      ]) {
        final booking = bookingWith(
          status,
          payments: [payment(1, PaymentStatus.pending)],
        );
        expect(booking.canVerify, isFalse, reason: status);
      }
    });
  });

  group('canStart (Mulai Sewa)', () {
    test('hanya confirmed', () {
      expect(bookingWith(BookingStatus.confirmed).canStart, isTrue);

      for (final status in const [
        BookingStatus.pendingPayment,
        BookingStatus.pendingVerification,
        BookingStatus.inUse,
        BookingStatus.completed,
        BookingStatus.cancelled,
        BookingStatus.rejected,
        'status_baru_server',
      ]) {
        expect(bookingWith(status).canStart, isFalse, reason: status);
      }
    });
  });

  group('canComplete (Selesaikan)', () {
    test('hanya in_use', () {
      expect(bookingWith(BookingStatus.inUse).canComplete, isTrue);

      for (final status in const [
        BookingStatus.pendingPayment,
        BookingStatus.pendingVerification,
        BookingStatus.confirmed,
        BookingStatus.completed,
        BookingStatus.cancelled,
        BookingStatus.rejected,
        'status_baru_server',
      ]) {
        expect(bookingWith(status).canComplete, isFalse, reason: status);
      }
    });
  });

  group('kombinasi aksi', () {
    test('setiap status hanya menawarkan aksi yang sah', () {
      final pending = bookingWith(BookingStatus.pendingPayment);
      expect(pending.canVerify, isFalse);
      expect(pending.canStart, isFalse);
      expect(pending.canComplete, isFalse);

      final verified = bookingWith(BookingStatus.completed);
      expect(verified.canVerify, isFalse);
      expect(verified.canStart, isFalse);
      expect(verified.canComplete, isFalse);
      expect(verified.isCompleted, isTrue);

      final unknown = bookingWith('status_baru_server');
      expect(unknown.canVerify, isFalse);
      expect(unknown.canStart, isFalse);
      expect(unknown.canComplete, isFalse);
      expect(unknown.isCompleted, isFalse);
    });
  });
}
