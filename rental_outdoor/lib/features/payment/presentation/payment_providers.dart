import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../booking/data/booking_repository.dart';
import '../../booking/domain/booking.dart';
import '../data/payment_repository.dart';
import '../domain/payment_info.dart';

/// Daftar rekening tujuan (`GET /payments/info`) — data publik.
final paymentInfoProvider =
    AsyncNotifierProvider.autoDispose<PaymentInfoController,
        List<PaymentBankAccount>>(PaymentInfoController.new);

class PaymentInfoController
    extends AsyncNotifier<List<PaymentBankAccount>> {
  @override
  Future<List<PaymentBankAccount>> build() =>
      ref.read(paymentRepositoryProvider).getPaymentInfo();
}

/// Detail booking untuk layar pembayaran dan detail pesanan
/// (`GET /bookings/{id}`).
///
/// Family per `bookingId`, autoDispose + `ref.watch(currentUserIdProvider)`:
/// endpoint menolak booking milik akun lain (404), jadi provider diikat ke
/// user yang sedang login dan di-dispose saat halaman ditutup. Didaftarkan
/// di pengamat sesi `routerProvider`.
final bookingDetailProvider = AsyncNotifierProvider.autoDispose
    .family<BookingDetailController, Booking, int>(
  BookingDetailController.new,
);

class BookingDetailController extends AsyncNotifier<Booking> {
  BookingDetailController(this.bookingId);

  final int bookingId;

  @override
  Future<Booking> build() {
    // Provider per-user: ganti sesi -> provider ini dibuang pengamat sesi.
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return Future<Booking>.error(
        ApiException(
          statusCode: 401,
          message: 'Sesi Anda telah berakhir. Silakan login kembali.',
        ),
      );
    }
    return ref.read(bookingRepositoryProvider).getBooking(bookingId);
  }
}
