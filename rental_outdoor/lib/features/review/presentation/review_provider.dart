import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../catalog/presentation/equipment_detail_provider.dart';
import '../../catalog/presentation/equipment_reviews_provider.dart';
import '../data/review_repository.dart';

/// State pengiriman ulasan untuk SATU booking (per alat).
///
/// `reviewedEquipmentIds` dipakai menandai alat "Sudah diulas" — baik
/// setelah sukses maupun setelah server menjawab `409` (sudah pernah
/// diulas). Tidak ada endpoint "ulasan milik saya" di API (API_DOCS.md),
/// jadi penandaan bersifat sesi halaman.
class ReviewSubmitState {
  const ReviewSubmitState({
    this.reviewedEquipmentIds = const {},
    this.submittingEquipmentIds = const {},
  });

  final Set<int> reviewedEquipmentIds;
  final Set<int> submittingEquipmentIds;

  bool isReviewed(int equipmentId) =>
      reviewedEquipmentIds.contains(equipmentId);

  bool isSubmitting(int equipmentId) =>
      submittingEquipmentIds.contains(equipmentId);

  ReviewSubmitState copyWith({
    Set<int>? reviewedEquipmentIds,
    Set<int>? submittingEquipmentIds,
  }) =>
      ReviewSubmitState(
        reviewedEquipmentIds: reviewedEquipmentIds ?? this.reviewedEquipmentIds,
        submittingEquipmentIds:
            submittingEquipmentIds ?? this.submittingEquipmentIds,
      );
}

/// Pengiriman ulasan per booking (`POST /reviews`), autoDispose family.
final bookingReviewProvider = NotifierProvider.autoDispose
    .family<BookingReviewController, ReviewSubmitState, int>(
  BookingReviewController.new,
);

class BookingReviewController extends Notifier<ReviewSubmitState> {
  BookingReviewController(this.bookingId);

  final int bookingId;

  @override
  ReviewSubmitState build() => const ReviewSubmitState();

  /// Kirim ulasan satu alat.
  ///
  /// Hasil `null` = sukses; selain itu pesan ramah untuk ditampilkan.
  /// `409` (sudah pernah diulas) ditandai "Sudah diulas" dan TIDAK
  /// dianggap kegagalan fatal.
  Future<String?> submit({
    required int equipmentId,
    required int rating,
    String? comment,
  }) async {
    if (state.isSubmitting(equipmentId)) return null;
    if (state.isReviewed(equipmentId)) {
      return 'Alat ini sudah diulas untuk pesanan ini.';
    }
    if (rating < 1 || rating > 5) {
      return 'Pilih rating 1 sampai 5 bintang.';
    }

    state = state.copyWith(
      submittingEquipmentIds: {...state.submittingEquipmentIds, equipmentId},
    );

    try {
      await ref.read(reviewRepositoryProvider).createReview(
            bookingId: bookingId,
            equipmentId: equipmentId,
            rating: rating,
            comment: comment,
          );
      _markReviewed(equipmentId);

      // Perbarui detail alat + daftar ulasan alat (rata-rata & jumlah ulasan
      // dihitung ulang server setelah insert).
      ref.invalidate(equipmentDetailProvider(equipmentId));
      ref.invalidate(equipmentReviewsProvider(equipmentId));
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        // Sudah pernah diulas -> tandai supaya tombol tidak ditawarkan lagi.
        _markReviewed(equipmentId);
        return 'Alat ini sudah pernah diulas untuk pesanan ini.';
      }
      if (e.statusCode == 422) {
        return 'Rating tidak valid. Pilih 1 sampai 5 bintang.';
      }
      return e.message;
    } catch (_) {
      return 'Gagal mengirim ulasan. Coba lagi.';
    } finally {
      _unmarkSubmitting(equipmentId);
    }
  }

  void _markReviewed(int equipmentId) {
    state = state.copyWith(
      reviewedEquipmentIds: {...state.reviewedEquipmentIds, equipmentId},
    );
  }

  void _unmarkSubmitting(int equipmentId) {
    state = state.copyWith(
      submittingEquipmentIds: {...state.submittingEquipmentIds}
        ..remove(equipmentId),
    );
  }
}
