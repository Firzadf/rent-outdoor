import '../../../core/utils/parsers.dart';

/// Status pembayaran pada API: `pending` | `approved` | `rejected`
/// (API_DOCS.md bagian 8 dan 10).
class PaymentStatus {
  const PaymentStatus._();

  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';

  static String label(String status) => switch (status) {
        pending => 'Menunggu Verifikasi',
        approved => 'Disetujui',
        rejected => 'Ditolak',
        _ => 'Tidak diketahui',
      };
}

/// Satu pembayaran (`payments[]` pada `GET /bookings/{id}` dan respons
/// `POST /payments`).
///
/// `amount` dikirim sebagai STRING DECIMAL (hasil `grand_total` booking
/// di server) -> dibaca lewat parser aman.
class Payment {
  const Payment({
    required this.id,
    required this.bookingId,
    this.amount = 0,
    this.paymentProof,
    this.bankName,
    this.accountName,
    this.accountNumber,
    this.status,
    this.paymentDate,
    this.verifiedAt,
    this.verifiedBy,
    this.rejectionReason,
    this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: parseInt(json['id']),
        bookingId: parseInt(json['booking_id']),
        amount: parseDouble(json['amount']),
        // URL lengkap (sudah dikonversi server lewat Helper::getImageUrl).
        paymentProof: parseString(json['payment_proof']),
        bankName: parseString(json['bank_name']),
        accountName: parseString(json['account_name']),
        accountNumber: parseString(json['account_number']),
        status: parseString(json['status']),
        paymentDate: parseString(json['payment_date']),
        verifiedAt: parseString(json['verified_at']),
        verifiedBy: tryParseInt(json['verified_by']),
        rejectionReason: parseString(json['rejection_reason']),
        createdAt: parseString(json['created_at']),
      );

  final int id;
  final int bookingId;

  /// `grand_total` booking saat pembayaran dibuat (STRING DECIMAL).
  final double amount;

  /// URL lengkap bukti transfer.
  final String? paymentProof;
  final String? bankName;
  final String? accountName;
  final String? accountNumber;

  /// `pending` | `approved` | `rejected`.
  final String? status;
  final String? paymentDate;
  final String? verifiedAt;
  final int? verifiedBy;

  /// Alasan penolakan verifikasi — ditampilkan saat upload ulang.
  final String? rejectionReason;
  final String? createdAt;

  bool get isRejected => status == PaymentStatus.rejected;
  bool get isPending => status == PaymentStatus.pending;
  bool get isApproved => status == PaymentStatus.approved;
}
