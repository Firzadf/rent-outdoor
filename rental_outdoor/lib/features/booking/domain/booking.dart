import '../../../core/utils/parsers.dart';
import '../../catalog/domain/pagination.dart';
import '../../payment/domain/payment.dart';

/// Nilai ENUM `bookings.status` (API_DOCS.md bagian "Status Booking").
class BookingStatus {
  const BookingStatus._();

  static const String pendingPayment = 'pending_payment';
  static const String pendingVerification = 'pending_verification';
  static const String confirmed = 'confirmed';
  static const String inUse = 'in_use';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String rejected = 'rejected';

  /// Label tampilan (Bahasa Indonesia).
  static String label(String status) => switch (status) {
        pendingPayment => 'Menunggu Pembayaran',
        pendingVerification => 'Menunggu Verifikasi',
        confirmed => 'Dikonfirmasi',
        inUse => 'Sedang Disewa',
        completed => 'Selesai',
        cancelled => 'Dibatalkan',
        rejected => 'Ditolak',
        _ => 'Tidak diketahui',
      };
}

/// Satu baris pada booking (`items[]`).
///
/// Bentuk field mengikuti API_DOCS.md:
/// - `POST /bookings` -> `items[]` berisi `quantity`, `price_per_day`
///   (STRING DECIMAL), `subtotal` (STRING DECIMAL), `equipment_name`.
/// - `GET /bookings/{id}` -> `items[]` berisi `quantity`,
///   `equipment_name`, `primary_image_url` (URL lengkap).
class BookingItem {
  const BookingItem({
    required this.equipmentId,
    required this.quantity,
    this.equipmentName,
    this.primaryImageUrl,
    this.pricePerDay,
    this.subtotal,
  });

  factory BookingItem.fromJson(Map<String, dynamic> json) => BookingItem(
        equipmentId: parseInt(json['equipment_id']),
        quantity: parseInt(json['quantity']),
        equipmentName: parseString(json['equipment_name']),
        primaryImageUrl: parseString(json['primary_image_url']),
        pricePerDay: parseDouble(json['price_per_day']),
        subtotal: parseDouble(json['subtotal']),
      );

  final int equipmentId;
  final int quantity;
  final String? equipmentName;
  final String? primaryImageUrl;

  /// Hanya pada respons `POST /bookings` (STRING DECIMAL dari server).
  final double? pricePerDay;
  final double? subtotal;
}

/// Satu booking milik customer.
///
/// SEMUA angka rupiah (`subtotal`, `deposit_total`, `grand_total`, ...)
/// dikirim sebagai STRING DECIMAL (API_DOCS.md bagian "Tipe Angka") dan
/// dibaca lewat parser aman. `grand_total` yang dipakai di layar
/// pembayaran diambil dari respons INI, bukan dihitung client.
class Booking {
  const Booking({
    required this.id,
    required this.bookingCode,
    required this.status,
    this.userId,
    this.pickupDate,
    this.returnDate,
    this.actualReturnDate,
    this.totalDays = 0,
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

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: parseInt(json['id']),
        userId: parseInt(json['user_id']),
        bookingCode: parseString(json['booking_code']) ?? '',
        pickupDate: parseString(json['pickup_date']),
        returnDate: parseString(json['return_date']),
        actualReturnDate: parseString(json['actual_return_date']),
        totalDays: parseInt(json['total_days']),
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

  /// `YYYY-MM-DD`.
  final String? pickupDate;
  final String? returnDate;

  /// Tanggal kembali sebenarnya (diisi admin saat `complete`).
  final String? actualReturnDate;

  /// `return_date - pickup_date` (tanpa +1) — dihitung server.
  final int totalDays;

  final double subtotal;
  final double depositTotal;
  final double lateFee;
  final double damageFee;
  final double depositRefund;

  /// Total tagihan (server) — SUMBER SATU-SATUNYA di layar pembayaran.
  final double grandTotal;

  final String status;
  final String? notes;
  final String? cancellationReason;

  /// Kondisi kembali: `good` | `damaged` | `lost` (diisi admin).
  final String? returnCondition;

  /// Catatan kondisi alat dari admin (`return_notes`).
  final String? returnNotes;

  /// Batas unggah bukti bayar (`YYYY-MM-DD HH:mm:ss`, +24 jam).
  final String? autoCancelAt;
  final String? createdAt;
  final String? updatedAt;

  final List<BookingItem> items;
  final List<Payment> payments;

  /// Waktu batas bayar sebagai `DateTime`; `null` bila tidak terbaca.
  DateTime? get autoCancelAtDate => DateTime.tryParse(autoCancelAt ?? '');

  /// Pembayaran TERAKHIR (id terbesar) — dipakai untuk mengecek
  /// `rejection_reason` saat status `pending_verification`.
  Payment? get lastPayment {
    Payment? latest;
    for (final payment in payments) {
      if (latest == null || payment.id > latest.id) latest = payment;
    }
    return latest;
  }

  /// Form pembayaran boleh diisi (API_DOCS.md bagian 8):
  /// - `pending_payment`, atau
  /// - `pending_verification` dengan pembayaran terakhir berstatus
  ///   `rejected` (customer mengunggah ulang).
  bool get canSubmitPayment {
    if (status == BookingStatus.pendingPayment) return true;
    if (status == BookingStatus.pendingVerification) {
      return lastPayment?.isRejected ?? false;
    }
    return false;
  }

  /// Tombol "Bayar" / "Upload Ulang" tampil (sama dengan aturan server).
  bool get canPay => canSubmitPayment;

  /// Tombol "Batalkan" tampil — hanya `pending_payment` /
  /// `pending_verification` (API_DOCS.md bagian 7).
  bool get canCancel =>
      status == BookingStatus.pendingPayment ||
      status == BookingStatus.pendingVerification;

  /// Tombol "Beri Ulasan" tampil — hanya `completed` (API_DOCS.md bagian 9).
  bool get canReview => status == BookingStatus.completed;

  /// Masih menunggu pembayaran/verifikasi -> informasi batas bayar relevan.
  bool get isAwaitingPayment =>
      status == BookingStatus.pendingPayment ||
      status == BookingStatus.pendingVerification;

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

/// Hasil satu halaman `GET /bookings`:
/// `data = { bookings: [...], pagination: {...} }`.
///
/// `bookings[]` = kolom mentah tabel `bookings` saja (TANPA items/payments),
/// jadi `items` pada baris daftar biasanya kosong.
class BookingsPage {
  const BookingsPage({required this.items, required this.pagination});

  factory BookingsPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['bookings'];
    final items = <Booking>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) items.add(Booking.fromJson(item));
      }
    }
    final rawPagination = json['pagination'];
    return BookingsPage(
      items: items,
      pagination: rawPagination is Map<String, dynamic>
          ? Pagination.fromJson(rawPagination)
          : Pagination.empty(),
    );
  }

  /// Halaman kosong (respons tidak sesuai kontrak).
  factory BookingsPage.empty() =>
      BookingsPage(items: const [], pagination: Pagination.empty());

  final List<Booking> items;
  final Pagination pagination;
}
