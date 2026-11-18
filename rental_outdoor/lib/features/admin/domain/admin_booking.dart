import '../../../core/utils/parsers.dart';
import '../../booking/domain/booking.dart';
import '../../catalog/domain/pagination.dart';
import '../../payment/domain/payment.dart';

/// Satu booking milik admin (`GET /admin/bookings` dan
/// `GET /admin/bookings/{id}`, API_DOCS.md bagian 10).
///
/// Bentuk row DAFTAR: kolom bookings + `user_name`, `user_email`,
/// `item_count` (STRING, hasil `SUM(quantity)`), TANPA `items`/`payments`.
/// Bentuk DETAIL: kolom bookings + data pelanggan (`user_name`, `user_email`,
/// `user_phone`, `user_address`) + `items[]` + `payments[]`.
///
/// SEMUA angka rupiah dikirim STRING DECIMAL; `item_count` juga STRING —
/// dibaca lewat parser aman yang menerima number maupun string.
class AdminBooking {
  const AdminBooking({
    required this.id,
    required this.bookingCode,
    required this.status,
    this.userId,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.userAddress,
    this.pickupDate,
    this.returnDate,
    this.actualReturnDate,
    this.totalDays = 0,
    this.itemCount = 0,
    this.subtotal = 0,
    this.depositTotal = 0,
    this.lateFee = 0,
    this.damageFee = 0,
    this.depositRefund = 0,
    this.grandTotal = 0,
    this.notes,
    this.cancellationReason,
    this.returnCondition,
    this.returnNotes,
    this.autoCancelAt,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
    this.payments = const [],
  });

  factory AdminBooking.fromJson(Map<String, dynamic> json) => AdminBooking(
        id: parseInt(json['id']),
        userId: tryParseInt(json['user_id']),
        bookingCode: parseString(json['booking_code']) ?? '',
        userName: parseString(json['user_name']),
        userEmail: parseString(json['user_email']),
        userPhone: parseString(json['user_phone']),
        userAddress: parseString(json['user_address']),
        pickupDate: parseString(json['pickup_date']),
        returnDate: parseString(json['return_date']),
        actualReturnDate: parseString(json['actual_return_date']),
        totalDays: parseInt(json['total_days']),
        // SUM(quantity) -> STRING ("2"), parser menerima keduanya.
        itemCount: parseInt(json['item_count']),
        subtotal: parseDouble(json['subtotal']),
        depositTotal: parseDouble(json['deposit_total']),
        lateFee: parseDouble(json['late_fee']),
        damageFee: parseDouble(json['damage_fee']),
        depositRefund: parseDouble(json['deposit_refund']),
        grandTotal: parseDouble(json['grand_total']),
        status: parseString(json['status']) ?? BookingStatus.pendingPayment,
        notes: parseString(json['notes']),
        cancellationReason: parseString(json['cancellation_reason']),
        returnCondition: parseString(json['return_condition']),
        returnNotes: parseString(json['return_notes']),
        autoCancelAt: parseString(json['auto_cancel_at']),
        createdAt: parseString(json['created_at']),
        updatedAt: parseString(json['updated_at']),
        items: _items(json['items']),
        payments: _payments(json['payments']),
      );

  final int id;
  final int? userId;

  /// Format `OR-YYYYMMDD-XXXX`.
  final String bookingCode;

  // Data pelanggan (hanya pada respons DETAIL).
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? userAddress;

  /// `YYYY-MM-DD`.
  final String? pickupDate;
  final String? returnDate;

  /// Diisi admin saat `complete`.
  final String? actualReturnDate;

  /// Dihitung server (`return_date - pickup_date`).
  final int totalDays;

  /// `SUM(quantity)` booking — STRING dari server, hanya ada di daftar.
  final int itemCount;

  final double subtotal;
  final double depositTotal;
  final double lateFee;
  final double damageFee;
  final double depositRefund;

  /// Total tagihan (STRING dari server).
  final double grandTotal;

  final String status;
  final String? notes;
  final String? cancellationReason;

  /// `good` | `damaged` | `lost` (diisi admin saat `complete`).
  final String? returnCondition;
  final String? returnNotes;

  /// Batas unggah bukti bayar (`YYYY-MM-DD HH:mm:ss`, +24 jam).
  final String? autoCancelAt;
  final String? createdAt;
  final String? updatedAt;

  /// Hanya pada respons DETAIL.
  final List<BookingItem> items;
  final List<Payment> payments;

  /// Pembayaran TERAKHIR (id terbesar) — penentu aksi verifikasi.
  Payment? get lastPayment {
    Payment? latest;
    for (final payment in payments) {
      if (latest == null || payment.id > latest.id) latest = payment;
    }
    return latest;
  }

  /// Tombol "Setujui"/"Tolak" tampil: booking `pending_verification` DAN
  /// pembayaran terakhir masih `pending` (syarat server, API_DOCS.md §10).
  bool get canVerify =>
      status == BookingStatus.pendingVerification &&
      (lastPayment?.isPending ?? false);

  /// Tombol "Mulai Sewa" tampil: booking `confirmed`.
  bool get canStart => status == BookingStatus.confirmed;

  /// Tombol "Selesaikan" tampil: booking `in_use`.
  bool get canComplete => status == BookingStatus.inUse;

  /// Pesanan sudah selesai -> rincian denda/deposit refund relevan.
  bool get isCompleted => status == BookingStatus.completed;

  static List<BookingItem> _items(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(BookingItem.fromJson)
        .toList();
  }

  static List<Payment> _payments(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Payment.fromJson)
        .toList();
  }
}

/// Hasil satu halaman `GET /admin/bookings`:
/// `data = { bookings: [...], pagination: {...} }`.
class AdminBookingsPage {
  const AdminBookingsPage({required this.items, required this.pagination});

  factory AdminBookingsPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['bookings'];
    final items = <AdminBooking>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) items.add(AdminBooking.fromJson(item));
      }
    }
    final rawPagination = json['pagination'];
    return AdminBookingsPage(
      items: items,
      pagination: rawPagination is Map<String, dynamic>
          ? Pagination.fromJson(rawPagination)
          : Pagination.empty(),
    );
  }

  factory AdminBookingsPage.empty() =>
      AdminBookingsPage(items: const [], pagination: Pagination.empty());

  final List<AdminBooking> items;
  final Pagination pagination;
}

/// Hasil `PUT /admin/bookings/{id}/complete` (API_DOCS.md bagian 10).
///
/// PENTING — dua bentuk angka dalam SATU respons:
/// - level ATAS: `late_fee`, `damage_fee`, `deposit_refund` bertipe NUMBER
///   (float PHP) dan `late_days` number,
/// - di dalam `booking` (kolom DB): field yang sama tetap STRING DECIMAL.
///
/// Parser aman dipakai untuk keduanya sehingga tidak peduli mana yang
/// dikirim server.
class BookingCompleteResult {
  const BookingCompleteResult({
    this.lateDays = 0,
    this.lateFee = 0,
    this.damageFee = 0,
    this.depositRefund = 0,
    this.booking,
  });

  factory BookingCompleteResult.fromJson(Map<String, dynamic> json) {
    final rawBooking = json['booking'];
    return BookingCompleteResult(
      lateDays: parseInt(json['late_days']),
      lateFee: parseDouble(json['late_fee']),
      damageFee: parseDouble(json['damage_fee']),
      depositRefund: parseDouble(json['deposit_refund']),
      booking: rawBooking is Map<String, dynamic>
          ? AdminBooking.fromJson(rawBooking)
          : null,
    );
  }

  /// Jumlah hari terlambat (dihitung SERVER dari `actual_return_date`).
  final int lateDays;

  /// NUMBER di level atas respons.
  final double lateFee;
  final double damageFee;
  final double depositRefund;

  /// Objek booking setelah update — field biayanya STRING DECIMAL.
  final AdminBooking? booking;
}
