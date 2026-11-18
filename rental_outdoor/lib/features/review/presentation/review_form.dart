import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_button.dart';
import 'review_provider.dart';

/// Form ulasan satu alat pada sebuah pesanan `completed`
/// (`POST /reviews`, API_DOCS.md bagian 9).
///
/// Dipakai sebagai isi bottom sheet dari halaman detail pesanan.
/// Menutup diri dengan `Navigator.pop(true)` saat berhasil supaya halaman
/// induk bisa menampilkan pesan sukses.
class ReviewForm extends ConsumerStatefulWidget {
  const ReviewForm({
    super.key,
    required this.bookingId,
    required this.equipmentId,
    required this.equipmentName,
  });

  final int bookingId;
  final int equipmentId;
  final String equipmentName;

  @override
  ConsumerState<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<ReviewForm> {
  final TextEditingController _commentController = TextEditingController();

  /// 0 = belum dipilih (rating wajib 1–5).
  int _rating = 0;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = ref.read(bookingReviewProvider(widget.bookingId));
    if (state.isSubmitting(widget.equipmentId)) return;

    setState(() => _error = null);
    if (_rating < 1) {
      setState(() => _error = 'Pilih rating bintang dulu (1 sampai 5).');
      return;
    }

    final message = await ref
        .read(bookingReviewProvider(widget.bookingId).notifier)
        .submit(
          equipmentId: widget.equipmentId,
          rating: _rating,
          comment: _commentController.text,
        );

    if (!mounted) return;
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(bookingReviewProvider(widget.bookingId));
    final submitting = state.isSubmitting(widget.equipmentId);

    // Sudah diulas (sukses sebelumnya atau server menjawab 409).
    if (state.isReviewed(widget.equipmentId)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sudah diulas',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.equipmentName} sudah pernah diulas untuk pesanan ini.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Tutup',
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Beri Ulasan',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.equipmentName,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(
            'Rating',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i bintang',
                  onPressed:
                      submitting ? null : () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating ? Icons.star : Icons.star_border,
                    size: 32,
                    color: i <= _rating
                        ? const Color(0xFFF5A623)
                        : theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            enabled: !submitting,
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Komentar (opsional)',
              hintText: 'Bagaimana kondisi alat saat disewa?',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          AppButton(
            label: 'Kirim Ulasan',
            icon: Icons.send_outlined,
            loading: submitting,
            onPressed: submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
