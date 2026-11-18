import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/features/admin/domain/admin_booking.dart';
import 'package:rental_outdoor/features/booking/domain/booking.dart';
import 'package:rental_outdoor/features/payment/domain/payment.dart';

/// Parser booking admin (API_DOCS.md bagian 10) — semua angka DECIMAL
/// berupa STRING, `item_count` hasil `SUM()` juga STRING, dan respons
/// `/complete` mencampurkan NUMBER (level atas) dengan STRING (di dalam
/// objek `booking`).
void main() {
  final listRow = <String, dynamic>{
    'id': 1,
    'user_id': 2,
    'booking_code': 'OR-20261008-4576',
    'user_name': 'John Doe',
    'user_email': 'customer@test.com',
    'status': 'pending_verification',
    'pickup_date': '2026-11-01',
    'return_date': '2026-11-03',
    'total_days': 2,
    'item_count': '2',
    'subtotal': '300000.00',
    'deposit_total': '600000.00',
    'grand_total': '900000.00',
    'created_at': '2026-10-08 13:24:32',
  };

  final detailJson = <String, dynamic>{
    'id': 5,
    'user_id': 2,
    'booking_code': 'OR-20261008-4576',
    'user_name': 'John Doe',
    'user_email': 'customer@test.com',
    'user_phone': '081234567890',
    'user_address': 'Jalan Mawar No. 1',
    'status': 'in_use',
    'pickup_date': '2026-11-01',
    'return_date': '2026-11-03',
    'total_days': 2,
    'subtotal': '300000.00',
    'deposit_total': '600000.00',
    'late_fee': '0.00',
    'damage_fee': '0.00',
    'deposit_refund': '0.00',
    'grand_total': '900000.00',
    'notes': 'Ambil pagi hari',
    'items': [
      {
        'equipment_id': 1,
        'equipment_name': 'Tenda Kapasitas 4 Orang',
        'quantity': 2,
        'primary_image_url':
            'http://localhost/outdoorrent/uploads/equipments/tent.jpg',
      },
    ],
    'payments': [
      {
        'id': 9,
        'booking_id': 5,
        'amount': '900000.00',
        'payment_proof': 'http://localhost/outdoorrent/uploads/payments/a.png',
        'status': 'pending',
        'created_at': '2026-10-08 14:00:00',
      },
    ],
  };

  group('AdminBooking.fromJson — baris daftar', () {
    test('item_count STRING + grand_total STRING + nama user', () {
      final booking = AdminBooking.fromJson(listRow);

      expect(booking.id, 1);
      expect(booking.userId, 2);
      expect(booking.bookingCode, 'OR-20261008-4576');
      expect(booking.userName, 'John Doe');
      expect(booking.userEmail, 'customer@test.com');
      expect(booking.itemCount, 2);
      expect(booking.totalDays, 2);
      expect(booking.grandTotal, 900000);
      expect(booking.subtotal, 300000);
      expect(booking.depositTotal, 600000);
      expect(booking.items, isEmpty, reason: 'daftar tidak mengirim items');
      expect(booking.payments, isEmpty);
      expect(booking.userPhone, isNull);
    });

    test('item_count number juga diterima', () {
      final booking = AdminBooking.fromJson({...listRow, 'item_count': 3});
      expect(booking.itemCount, 3);
    });
  });

  group('AdminBooking.fromJson — detail', () {
    test('data pelanggan + items + payments', () {
      final booking = AdminBooking.fromJson(detailJson);

      expect(booking.userName, 'John Doe');
      expect(booking.userEmail, 'customer@test.com');
      expect(booking.userPhone, '081234567890');
      expect(booking.userAddress, 'Jalan Mawar No. 1');
      expect(booking.status, BookingStatus.inUse);
      expect(booking.notes, 'Ambil pagi hari');

      final item = booking.items.single;
      expect(item.equipmentName, 'Tenda Kapasitas 4 Orang');
      expect(item.quantity, 2);
      expect(item.primaryImageUrl, endsWith('tent.jpg'));

      final payment = booking.payments.single;
      expect(payment.amount, 900000, reason: 'amount = STRING DECIMAL');
      expect(payment.isPending, isTrue);
      expect(payment.paymentProof, endsWith('a.png'));
      expect(booking.lastPayment!.id, 9);
    });

    test('field wajib null/kosong -> default aman', () {
      final booking = AdminBooking.fromJson(const {});

      expect(booking.id, 0);
      expect(booking.bookingCode, '');
      expect(booking.status, BookingStatus.pendingPayment);
      expect(booking.itemCount, 0);
      expect(booking.grandTotal, 0);
      expect(booking.userName, isNull);
      expect(booking.lastPayment, isNull);
      expect(booking.items, isEmpty);
      expect(booking.payments, isEmpty);
    });
  });

  group('AdminBookingsPage.fromJson', () {
    test('bookings[] + pagination', () {
      final page = AdminBookingsPage.fromJson({
        'bookings': [listRow],
        'pagination': {'total': 4, 'page': 1, 'limit': 10, 'total_pages': 1},
      });

      expect(page.items, hasLength(1));
      expect(page.items.single.itemCount, 2);
      expect(page.pagination.total, 4);
      expect(page.pagination.hasNextPage, isFalse);
    });

    test('respons tidak sesuai kontrak -> halaman kosong', () {
      final page = AdminBookingsPage.fromJson(const {'bookings': 'x'});
      expect(page.items, isEmpty);
      expect(page.pagination.hasNextPage, isFalse);
      expect(AdminBookingsPage.empty().items, isEmpty);
    });
  });

  group('BookingCompleteResult — NUMBER di atas, STRING di dalam booking', () {
    test('bentuk asli server: top-level number, objek booking string', () {
      final result = BookingCompleteResult.fromJson(const {
        'booking': {
          'id': 1,
          'booking_code': 'OR-1',
          'status': 'completed',
          'return_condition': 'damaged',
          'late_fee': '150000.00',
          'damage_fee': '150000.00',
          'deposit_refund': '300000.00',
        },
        'late_days': 2,
        'late_fee': 150000,
        'damage_fee': 150000,
        'deposit_refund': 300000,
      });

      expect(result.lateDays, 2);
      expect(result.lateFee, 150000);
      expect(result.damageFee, 150000);
      expect(result.depositRefund, 300000);

      final booking = result.booking!;
      expect(booking.status, BookingStatus.completed);
      expect(booking.returnCondition, 'damaged');
      expect(booking.lateFee, 150000, reason: 'STRING DECIMAL -> double');
      expect(booking.damageFee, 150000);
      expect(booking.depositRefund, 300000);
    });

    test('top-level berupa string tetap terbaca (parser aman)', () {
      final result = BookingCompleteResult.fromJson(const {
        'late_days': '2',
        'late_fee': '150000.00',
        'damage_fee': '0.00',
        'deposit_refund': '300000.00',
      });

      expect(result.lateDays, 2);
      expect(result.lateFee, 150000);
      expect(result.damageFee, 0);
      expect(result.depositRefund, 300000);
      expect(result.booking, isNull);
    });

    test('data hilang -> default aman (tanpa crash)', () {
      final result = BookingCompleteResult.fromJson(const {});

      expect(result.lateDays, 0);
      expect(result.lateFee, 0);
      expect(result.damageFee, 0);
      expect(result.depositRefund, 0);
      expect(result.booking, isNull);
    });
  });

  group('pembayaran terakhir', () {
    test('lastPayment = id terbesar (penentu aksi verifikasi)', () {
      final booking = AdminBooking.fromJson({
        ...detailJson,
        'payments': [
          {
            'id': 9,
            'booking_id': 5,
            'amount': '900000.00',
            'status': 'rejected',
            'rejection_reason': 'Foto buram',
          },
          {
            'id': 12,
            'booking_id': 5,
            'amount': '900000.00',
            'status': 'pending',
          },
        ],
      });

      expect(booking.lastPayment!.id, 12);
      expect(booking.lastPayment!.isPending, isTrue);
      expect(booking.payments.first.rejectionReason, 'Foto buram');
      expect(booking.payments.first.status, PaymentStatus.rejected);
    });
  });
}
