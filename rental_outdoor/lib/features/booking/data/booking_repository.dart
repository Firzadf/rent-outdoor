import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_url.dart';
import '../../catalog/domain/pagination.dart';
import '../domain/booking.dart';

/// Booking customer dari Supabase PostgREST.
///
/// Harga dan deposit TIDAK PERNAH dikirim dari client — diambil
/// dari tabel `equipments` lalu dihitung di sini, sama seperti
/// `BookingController::store` di PHP lama:
/// `subtotal = SUM(price_per_day * quantity * total_days)`,
/// `deposit_total = SUM(deposit * quantity)`,
/// `grand_total = subtotal + deposit_total`,
/// `total_days = return_date - pickup_date` (tanpa +1),
/// `auto_cancel_at = sekarang + 24 jam`,
/// `booking_code = OR-YYYYMMDD-XXXX` (acak 4 digit, dicek unik).
///
/// Batasan: tanpa transaksi database, jadi bila insert item gagal
/// di tengah jalan, booking bisa tertinggal tanpa item. Itu dicatat
/// sebagai batasan MVP; data seed masih kecil dan kegagalan seperti
/// itu akan terlihat sebagai ApiException.
final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.watch(supabaseServiceProvider)),
);

class BookingRepository {
  BookingRepository(this._sb);

  final SupabaseService _sb;

  Future<Booking> createBooking({
    required DateTime pickupDate,
    required DateTime returnDate,
    String? notes,
    required List<({int equipmentId, int quantity})> items,
  }) async {
    final userId = await _sb.requireAppUserId();
    final today = DateTime.now();
    final pickupDay = DateTime(pickupDate.year, pickupDate.month, pickupDate.day);
    final returnDay = DateTime(returnDate.year, returnDate.month, returnDate.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    if (pickupDay.isBefore(todayDay)) {
      throw ApiException(
        statusCode: 400,
        message: 'Tanggal ambil tidak boleh di masa lalu.',
      );
    }
    final totalDays = returnDay.difference(pickupDay).inDays;
    if (totalDays < 1) {
      throw ApiException(
        statusCode: 400,
        message: 'Tanggal kembali harus minimal 1 hari setelah tanggal ambil.',
      );
    }
    if (items.isEmpty) {
      throw ApiException(
        statusCode: 400,
        message: 'Pilih minimal satu alat.',
      );
    }
    final seen = <int>{};
    for (final item in items) {
      if (item.quantity <= 0) {
        throw ApiException(
          statusCode: 400,
          message: 'Jumlah alat harus lebih dari 0.',
        );
      }
      if (!seen.add(item.equipmentId)) {
        throw ApiException(
          statusCode: 400,
          message: 'Ada alat yang duplikat di pesanan.',
        );
      }
    }

    final pickupIso = formatIsoDate(pickupDate);
    final returnIso = formatIsoDate(returnDate);
    double subtotal = 0;
    double depositTotal = 0;
    final pricedItems = <Map<String, dynamic>>[];
    for (final item in items) {
      final equipment = await _sb.guard(
        () => _sb.client
            .from('equipments')
            .select('id, name, price_per_day, deposit, is_active')
            .eq('id', item.equipmentId)
            .maybeSingle(),
      );
      if (equipment == null) {
        throw ApiException(
          statusCode: 400,
          message: 'Alat dengan ID ${item.equipmentId} tidak ditemukan.',
        );
      }
      if (equipment['is_active'] != true) {
        throw ApiException(
          statusCode: 400,
          message: "Alat '${equipment['name']}' sedang tidak aktif.",
        );
      }
      final available = await _availableStock(
        item.equipmentId,
        pickupIso,
        returnIso,
      );
      if (available < item.quantity) {
        throw ApiException(
          statusCode: 400,
          message:
              "Stok '${equipment['name']}' tidak cukup. Hanya $available tersedia pada tanggal itu.",
        );
      }
      final price = (equipment['price_per_day'] as num? ?? 0).toDouble();
      final deposit = (equipment['deposit'] as num? ?? 0).toDouble();
      final itemSubtotal = price * item.quantity * totalDays;
      subtotal += itemSubtotal;
      depositTotal += deposit * item.quantity;
      pricedItems.add({
        'equipment_id': item.equipmentId,
        'quantity': item.quantity,
        'price_per_day': price,
        'subtotal': itemSubtotal,
        'equipment_name': equipment['name'] as String? ?? '',
      });
    }
    final grandTotal = subtotal + depositTotal;

    var bookingCode = _newBookingCode();
    for (var attempt = 0; attempt < 5; attempt++) {
      final existing = await _sb.guard(
        () => _sb.client
            .from('bookings')
            .select('id')
            .eq('booking_code', bookingCode)
            .maybeSingle(),
      );
      if (existing == null) break;
      bookingCode = _newBookingCode();
    }

    final autoCancelAt =
        DateTime.now().toUtc().add(const Duration(hours: 24)).toIso8601String();
    final inserted = await _sb.guard(
      () => _sb.client
          .from('bookings')
          .insert({
            'user_id': userId,
            'booking_code': bookingCode,
            'pickup_date': pickupIso,
            'return_date': returnIso,
            'total_days': totalDays,
            'subtotal': subtotal,
            'deposit_total': depositTotal,
            'grand_total': grandTotal,
            'status': 'pending_payment',
            'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
            'auto_cancel_at': autoCancelAt,
          })
          .select()
          .single(),
    );
    final bookingId = inserted['id'] as int;
    for (final item in pricedItems) {
      await _sb.guard(
        () => _sb.client.from('booking_items').insert({
          'booking_id': bookingId,
          'equipment_id': item['equipment_id'],
          'quantity': item['quantity'],
          'price_per_day': item['price_per_day'],
          'subtotal': item['subtotal'],
        }),
      );
    }
    return getBooking(bookingId);
  }

  /// Detail booking milik sendiri + items + payments.
  Future<Booking> getBooking(int id) async {
    final userId = await _sb.requireAppUserId();
    final row = await _sb.guard(
      () => _sb.client.from('bookings').select().eq('id', id).maybeSingle(),
    );
    if (row == null || row['user_id'] != userId) {
      throw ApiException(statusCode: 404, message: 'Pesanan tidak ditemukan.');
    }
    final map = await _enrichBooking(row);
    return Booking.fromJson(map);
  }

  /// Daftar booking milik sendiri, terbaru dulu.
  Future<BookingsPage> getBookings({
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    final userId = await _sb.requireAppUserId();
    await _autoCancelExpired(userId);
    final rows = await _sb.guard(
      () => _sb.client
          .from('bookings')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100),
    );
    var items = _rows(rows);
    if (status != null && status.isNotEmpty) {
      items = items.where((row) => row['status'] == status).toList();
    }
    final total = items.length;
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 10 : limit;
    final start = (safePage - 1) * safeLimit;
    final pageItems = start >= total
        ? <Map<String, dynamic>>[]
        : items.sublist(start, (start + safeLimit).clamp(0, total));
    return BookingsPage(
      items: pageItems.map(Booking.fromJson).toList(),
      pagination: Pagination(
        total: total,
        page: safePage,
        limit: safeLimit,
        totalPages: total == 0 ? 0 : (total / safeLimit).ceil(),
      ),
    );
  }

  /// Batalkan booking, hanya untuk `pending_payment` /
  /// `pending_verification`.
  Future<void> cancelBooking(int id, {String? reason}) async {
    final userId = await _sb.requireAppUserId();
    final row = await _sb.guard(
      () => _sb.client.from('bookings').select().eq('id', id).maybeSingle(),
    );
    if (row == null || row['user_id'] != userId) {
      throw ApiException(statusCode: 404, message: 'Pesanan tidak ditemukan.');
    }
    final status = row['status'] as String? ?? '';
    if (status != 'pending_payment' && status != 'pending_verification') {
      throw ApiException(
        statusCode: 400,
        message:
            'Hanya pesanan Menunggu Pembayaran atau Menunggu Verifikasi yang bisa dibatalkan.',
      );
    }
    await _sb.guard(
      () => _sb.client.from('bookings').update({
        'status': 'cancelled',
        'cancellation_reason':
            reason?.trim().isEmpty == true ? 'Cancelled by customer' : reason!.trim(),
      }).eq('id', id),
    );
  }

  // -------------------------------------------------------------------
  // Helper
  // -------------------------------------------------------------------

  List<Map<String, dynamic>> _rows(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  String _newBookingCode() {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final random = Random().nextInt(9999) + 1;
    return 'OR-$date-${random.toString().padLeft(4, '0')}';
  }

  Future<int> _availableStock(
    int equipmentId,
    String pickupIso,
    String returnIso,
  ) async {
    final equipment = await _sb.guard(
      () => _sb.client
          .from('equipments')
          .select('stock')
          .eq('id', equipmentId)
          .maybeSingle(),
    );
    if (equipment == null) return 0;
    final stock = (equipment['stock'] as num? ?? 0).toInt();
    final items = await _sb.guard(
      () => _sb.client
          .from('booking_items')
          .select('quantity, bookings!inner(status, pickup_date, return_date)')
          .eq('equipment_id', equipmentId),
    );
    var booked = 0;
    for (final item in _rows(items)) {
      final booking = item['bookings'];
      if (booking is! Map<String, dynamic>) continue;
      final status = booking['status'] as String? ?? '';
      if (!const {
        'pending_payment',
        'pending_verification',
        'confirmed',
        'in_use',
      }.contains(status)) {
        continue;
      }
      final bPickup = (booking['pickup_date'] as String? ?? '');
      final bReturn = (booking['return_date'] as String? ?? '');
      if (bPickup.compareTo(returnIso) <= 0 &&
          bReturn.compareTo(pickupIso) >= 0) {
        booked += (item['quantity'] as num? ?? 0).toInt();
      }
    }
    return stock - booked;
  }

  Future<Map<String, dynamic>> _enrichBooking(
    Map<String, dynamic> row,
  ) async {
    final map = Map<String, dynamic>.from(row);
    final bookingId = row['id'] as int;
    final items = await _sb.guard(
      () => _sb.client
          .from('booking_items')
          .select()
          .eq('booking_id', bookingId),
    );
    final enrichedItems = <Map<String, dynamic>>[];
    for (final item in _rows(items)) {
      final itemMap = Map<String, dynamic>.from(item);
      final equipment = await _sb.guard(
        () => _sb.client
            .from('equipments')
            .select('name')
            .eq('id', item['equipment_id'])
            .maybeSingle(),
      );
      itemMap['equipment_name'] = equipment?['name'] as String?;
      final primary = await _sb.guard(
        () => _sb.client
            .from('equipment_images')
            .select('image_url')
            .eq('equipment_id', item['equipment_id'])
            .eq('is_primary', true)
            .order('sort_order')
            .limit(1)
            .maybeSingle(),
      );
      final imageUrl = primary?['image_url'] as String?;
      itemMap['primary_image_url'] =
          imageUrl == null ? null : resolveImageUrl(imageUrl);
      enrichedItems.add(itemMap);
    }
    map['items'] = enrichedItems;
    final payments = await _sb.guard(
      () => _sb.client
          .from('payments')
          .select()
          .eq('booking_id', bookingId)
          .order('created_at', ascending: false),
    );
    map['payments'] = _rows(payments).map((payment) {
      final paymentMap = Map<String, dynamic>.from(payment);
      final proof = paymentMap['payment_proof'] as String?;
      if (proof != null && proof.isNotEmpty) {
        paymentMap['payment_proof'] = resolveImageUrl(proof);
      }
      return paymentMap;
    }).toList();
    return map;
  }

  /// Auto-cancel seperti PHP lama: booking `pending_payment` yang
  /// sudah lewat `auto_cancel_at` diubah jadi `cancelled`.
  /// Kegagalan diabaikan supaya daftar pesanan tetap tampil.
  Future<void> _autoCancelExpired(int userId) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _sb.guard(
        () => _sb.client
            .from('bookings')
            .update({
              'status': 'cancelled',
              'cancellation_reason':
                  'Auto-cancel: pembayaran melewati batas waktu',
            })
            .eq('user_id', userId)
            .eq('status', 'pending_payment')
            .lte('auto_cancel_at', now),
      );
    } catch (_) {
      // Abaikan, lihat komentar di atas.
    }
  }
}
