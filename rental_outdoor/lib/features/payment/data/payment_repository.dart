import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/utils/image_upload.dart';
import '../../../core/utils/image_url.dart';
import '../domain/payment.dart';
import '../domain/payment_info.dart';

/// Pembayaran dari Supabase.
///
/// Rekening tujuan sama dengan PAYMENT_BANKS di PHP lama (BCA,
/// Mandiri, BRI, a.n. PT OutdoorRent Indonesia) karena tidak ada
/// tabelnya di Supabase. Bukti bayar diunggah ke bucket
/// `payment-proofs` (privat), lalu baris `payments` dibuat dan
/// status booking diubah jadi `pending_verification`.
final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(ref.watch(supabaseServiceProvider)),
);

class PaymentRepository {
  PaymentRepository(this._sb);

  final SupabaseService _sb;

  /// Rekening tujuan transfer (hardcode, sama seperti PHP lama).
  Future<List<PaymentBankAccount>> getPaymentInfo() async => AppConstants
      .paymentBanks
      .map(
        (bank) => PaymentBankAccount(
          bankName: bank.bankName,
          accountNumber: bank.accountNumber,
          accountName: bank.accountName,
        ),
      )
      .toList();

  /// Unggah bukti bayar (maks 5 MB, jpg/png/webp) dan buat
  /// pembayaran. Aturan sama seperti PHP lama: booking harus
  /// milik sendiri dan berstatus `pending_payment`, atau
  /// `pending_verification` dengan pembayaran terakhir `rejected`;
  /// tidak boleh lewat `auto_cancel_at`.
  Future<Payment> submitPayment({
    required int bookingId,
    required String bankName,
    required String accountName,
    required String accountNumber,
    required XFile proofFile,
  }) async {
    final userId = await _sb.requireAppUserId();
    final booking = await _sb.guard(
      () => _sb.client.from('bookings').select().eq('id', bookingId).maybeSingle(),
    );
    if (booking == null || booking['user_id'] != userId) {
      throw ApiException(statusCode: 404, message: 'Pesanan tidak ditemukan.');
    }
    final status = booking['status'] as String? ?? '';
    if (status == 'pending_payment') {
      // Boleh, lanjut.
    } else if (status == 'pending_verification') {
      final last = await _lastPayment(bookingId);
      if (last == null || last['status'] != 'rejected') {
        throw ApiException(
          statusCode: 400,
          message: 'Pesanan ini sudah memiliki pembayaran yang menunggu verifikasi.',
        );
      }
    } else {
      throw ApiException(
        statusCode: 400,
        message:
            'Pembayaran hanya bisa untuk pesanan Menunggu Pembayaran, atau Menunggu Verifikasi dengan pembayaran yang ditolak.',
      );
    }
    final autoCancelAt = booking['auto_cancel_at'] as String?;
    if (autoCancelAt != null) {
      final deadline = DateTime.tryParse(autoCancelAt);
      if (deadline != null && !DateTime.now().isBefore(deadline)) {
        throw ApiException(
          statusCode: 400,
          message: 'Pesanan sudah melewati batas waktu pembayaran.',
        );
      }
    }

    final bytes = await proofFile.readAsBytes();
    final validationError = _validateProof(bytes, proofFile.name);
    if (validationError != null) {
      throw ApiException(statusCode: 400, message: validationError);
    }
    final mime = detectMimeFromBytes(bytes) ?? 'image/jpeg';
    final extension = extensionFromMime(mime);
    final fileName =
        'pay_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _sb.uploadBytes(
      bucket: 'payment-proofs',
      path: 'payments/$fileName',
      bytes: bytes,
      contentType: mime,
    );

    final inserted = await _sb.guard(
      () => _sb.client
          .from('payments')
          .insert({
            'booking_id': bookingId,
            'amount': (booking['grand_total'] as num? ?? 0).toDouble(),
            'payment_proof': 'uploads/payments/$fileName',
            'bank_name': bankName.trim(),
            'account_name': accountName.trim(),
            'account_number': accountNumber.trim(),
            'status': 'pending',
            'payment_date': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single(),
    );
    await _sb.guard(
      () => _sb.client
          .from('bookings')
          .update({'status': 'pending_verification'})
          .eq('id', bookingId),
    );
    final map = Map<String, dynamic>.from(inserted);
    final proof = map['payment_proof'] as String?;
    if (proof != null) map['payment_proof'] = resolveImageUrl(proof);
    return Payment.fromJson(map);
  }

  Future<Map<String, dynamic>?> _lastPayment(int bookingId) async {
    final rows = await _sb.guard(
      () => _sb.client
          .from('payments')
          .select()
          .eq('booking_id', bookingId)
          .order('id', ascending: false)
          .limit(1),
    );
    return rows.isEmpty ? null : rows.first;
  }

  String? _validateProof(List<int> bytes, String filename) {
    // Validasi sama seperti helper bukti bayar lama: format dan 5 MB.
    final dot = filename.lastIndexOf('.');
    final extension = dot < 0
        ? ''
        : filename.substring(dot + 1).toLowerCase();
    if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      return 'Format gambar tidak didukung. Gunakan JPG, PNG, atau WEBP.';
    }
    if (bytes.isEmpty) {
      return 'File gambar kosong atau gagal dibaca. Pilih gambar lain.';
    }
    if (bytes.length > 5 * 1024 * 1024) {
      return 'Ukuran gambar melebihi batas 5 MB. Kompres gambar Anda terlebih dahulu.';
    }
    return null;
  }
}
