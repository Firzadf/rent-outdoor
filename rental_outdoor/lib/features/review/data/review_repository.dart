import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../catalog/domain/review.dart';

/// Ulasan dari Supabase.
///
/// Syarat sama seperti PHP lama: booking milik sendiri berstatus
/// `completed` dan alat bagian dari booking itu. `409` bila ulasan
/// untuk (booking, alat) sudah ada (unique constraint di migrasi).
final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(ref.watch(supabaseServiceProvider)),
);

class ReviewRepository {
  ReviewRepository(this._sb);

  final SupabaseService _sb;

  Future<Review?> createReview({
    required int bookingId,
    required int equipmentId,
    required int rating,
    String? comment,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ApiException(
        statusCode: 400,
        message: 'Rating harus antara 1 sampai 5.',
      );
    }
    final userId = await _sb.requireAppUserId();
    final booking = await _sb.guard(
      () => _sb.client.from('bookings').select().eq('id', bookingId).maybeSingle(),
    );
    if (booking == null || booking['user_id'] != userId) {
      throw ApiException(statusCode: 404, message: 'Pesanan tidak ditemukan.');
    }
    if (booking['status'] != 'completed') {
      throw ApiException(
        statusCode: 400,
        message: 'Ulasan hanya bisa untuk pesanan yang sudah selesai.',
      );
    }
    final items = await _sb.guard(
      () => _sb.client
          .from('booking_items')
          .select('equipment_id')
          .eq('booking_id', bookingId),
    );
    final equipmentIds = <int>[];
    for (final item in items) {
      final equipmentId = item['equipment_id'];
      if (equipmentId is num) {
        equipmentIds.add(equipmentId.toInt());
      }
    }
    if (!equipmentIds.contains(equipmentId)) {
      throw ApiException(
        statusCode: 400,
        message: 'Alat ini bukan bagian dari pesanan tersebut.',
      );
    }
    final userRow = await _sb.requireUserRow();
    final inserted = await _sb.guard(
      () => _sb.client
          .from('reviews')
          .insert({
            'booking_id': bookingId,
            'equipment_id': equipmentId,
            'user_id': userId,
            'rating': rating,
            if (comment != null && comment.trim().isNotEmpty)
              'comment': comment.trim(),
          })
          .select()
          .single(),
    );
    final map = Map<String, dynamic>.from(inserted);
    map['user_name'] = userRow['name'] as String?;
    map['profile_image'] = userRow['profile_image'] as String?;
    // Review.fromJson membaca profile_image apa adanya; UI memakai
    // resolveImageUrl, jadi path storage tetap valid.
    return Review.fromJson(map);
  }
}
