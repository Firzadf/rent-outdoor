import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/features/booking/domain/booking.dart';
import 'package:rental_outdoor/features/payment/domain/payment.dart';

/// Logika tombol pada detail pesanan (aturan mengikuti API_DOCS.md
/// bagian 7 & 8):
/// - Bayar / Upload Ulang: `pending_payment`, atau `pending_verification`
///   dengan pembayaran terakhir `rejected`.
/// - Batalkan: `pending_payment` / `pending_verification`.
/// - Beri Ulasan: `completed`.
void main() {
  Booking bookingWith(
    String status, {
    List<Payment> payments = const [],
  }) =>
      Booking(
        id: 1,
        bookingCode: 'OR-1',
        status: status,
        payments: payments,
      );

  Payment payment(int id, String status) =>
      Payment(id: id, bookingId: 1, status: status);

  group('canPay / canSubmitPayment', () {
    test('pending_payment -> boleh bayar', () {
      final booking = bookingWith(BookingStatus.pendingPayment);
      expect(booking.canPay, isTrue);
      expect(booking.canSubmitPayment, isTrue);
    });

    test('pending_verification tanpa pembayaran -> tidak boleh', () {
      expect(bookingWith(BookingStatus.pendingVerification).canPay, isFalse);
    });

    test('pending_verification + pembayaran terakhir rejected -> boleh ulang',
        () {
      final booking = bookingWith(
        BookingStatus.pendingVerification,
        payments: [
          payment(1, PaymentStatus.pending),
          payment(2, PaymentStatus.rejected),
        ],
      );
      expect(booking.canPay, isTrue);
    });

    test('pending_verification + pembayaran terakhir pending -> tidak boleh',
        () {
      final booking = bookingWith(
        BookingStatus.pendingVerification,
        payments: [
          payment(1, PaymentStatus.rejected),
          payment(2, PaymentStatus.pending),
        ],
      );
      expect(booking.canPay, isFalse);
    });

    test('pending_verification + pembayaran terakhir approved -> tidak boleh',
        () {
      final booking = bookingWith(
        BookingStatus.pendingVerification,
        payments: [payment(1, PaymentStatus.approved)],
      );
      expect(booking.canPay, isFalse);
    });

    test('status lanjutan/terminal -> tidak boleh bayar', () {
      for (final status in const [
        BookingStatus.confirmed,
        BookingStatus.inUse,
        BookingStatus.completed,
        BookingStatus.cancelled,
        BookingStatus.rejected,
      ]) {
        expect(bookingWith(status).canPay, isFalse, reason: status);
      }
    });
  });

  group('canCancel', () {
    test('hanya pending_payment dan pending_verification', () {
      expect(bookingWith(BookingStatus.pendingPayment).canCancel, isTrue);
      expect(bookingWith(BookingStatus.pendingVerification).canCancel, isTrue);

      for (final status in const [
        BookingStatus.confirmed,
        BookingStatus.inUse,
        BookingStatus.completed,
        BookingStatus.cancelled,
        BookingStatus.rejected,
      ]) {
        expect(bookingWith(status).canCancel, isFalse, reason: status);
      }
    });
  });

  group('canReview', () {
    test('hanya completed', () {
      expect(bookingWith(BookingStatus.completed).canReview, isTrue);

      for (final status in const [
        BookingStatus.pendingPayment,
        BookingStatus.pendingVerification,
        BookingStatus.confirmed,
        BookingStatus.inUse,
        BookingStatus.cancelled,
        BookingStatus.rejected,
      ]) {
        expect(bookingWith(status).canReview, isFalse, reason: status);
      }
    });
  });

  group('isAwaitingPayment', () {
    test('true hanya untuk dua status menunggu', () {
      expect(bookingWith(BookingStatus.pendingPayment).isAwaitingPayment, isTrue);
      expect(bookingWith(BookingStatus.pendingVerification).isAwaitingPayment,
          isTrue);
      expect(bookingWith(BookingStatus.confirmed).isAwaitingPayment, isFalse);
      expect(bookingWith(BookingStatus.completed).isAwaitingPayment, isFalse);
      expect(bookingWith(BookingStatus.cancelled).isAwaitingPayment, isFalse);
    });
  });
}
