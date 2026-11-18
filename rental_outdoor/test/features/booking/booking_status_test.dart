import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/features/booking/domain/booking.dart';
import 'package:rental_outdoor/features/booking/presentation/booking_status_style.dart';

/// Pemetaan status booking -> label Indonesia + warna badge.
///
/// Status tak dikenal (mis. `rejected` yang ada di ENUM tapi tidak dipakai
/// alur server, atau nilai aneh dari server) WAJIB tetap mendapat gaya
/// cadangan supaya UI tidak crash.
void main() {
  const scheme = ColorScheme.light();

  group('label status (Bahasa Indonesia)', () {
    test('status yang dipakai server', () {
      expect(BookingStatus.label(BookingStatus.pendingPayment),
          'Menunggu Pembayaran');
      expect(BookingStatus.label(BookingStatus.pendingVerification),
          'Menunggu Verifikasi');
      expect(BookingStatus.label(BookingStatus.confirmed), 'Dikonfirmasi');
      expect(BookingStatus.label(BookingStatus.inUse), 'Sedang Disewa');
      expect(BookingStatus.label(BookingStatus.completed), 'Selesai');
      expect(BookingStatus.label(BookingStatus.cancelled), 'Dibatalkan');
    });

    test('cadangan: rejected + status tak dikenal', () {
      expect(BookingStatus.label(BookingStatus.rejected), 'Ditolak');
      expect(BookingStatus.label('entah_apa'), 'Tidak diketahui');
      expect(BookingStatus.label(''), 'Tidak diketahui');
    });
  });

  group('bookingStatusStyleFor — warna', () {
    test('enam status server punya label + gaya berbeda', () {
      final labels = <String>{
        for (final status in const [
          BookingStatus.pendingPayment,
          BookingStatus.pendingVerification,
          BookingStatus.confirmed,
          BookingStatus.inUse,
          BookingStatus.completed,
          BookingStatus.cancelled,
        ])
          bookingStatusStyleFor(scheme, status).label,
      };

      expect(labels, hasLength(6));
    });

    test('pending_payment pakai container error (perlu perhatian)', () {
      final style = bookingStatusStyleFor(scheme, BookingStatus.pendingPayment);
      expect(style.background, scheme.errorContainer);
      expect(style.foreground, scheme.onErrorContainer);
    });

    test('completed tidak memakai warna error', () {
      final style = bookingStatusStyleFor(scheme, BookingStatus.completed);
      expect(style.background, scheme.surfaceContainerHighest);
      expect(style.foreground, scheme.onSurface);
    });

    test('cancelled berbeda dari status tak dikenal', () {
      final cancelled = bookingStatusStyleFor(scheme, BookingStatus.cancelled);
      final unknown = bookingStatusStyleFor(scheme, 'entah_apa');

      expect(cancelled.background, isNot(unknown.background));
    });

    test('status tak dikenal -> label cadangan + warna cadangan', () {
      final style = bookingStatusStyleFor(scheme, 'status_baru_server');

      expect(style.label, 'Tidak diketahui');
      expect(style.background, scheme.surfaceContainerHighest);
      expect(style.foreground, scheme.onSurfaceVariant);
    });

    test('rejected tetap punya gaya (tidak crash)', () {
      final style = bookingStatusStyleFor(scheme, BookingStatus.rejected);

      expect(style.label, 'Ditolak');
      expect(style.background, scheme.errorContainer);
    });
  });
}
