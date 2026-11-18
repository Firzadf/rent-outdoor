import 'package:flutter/material.dart';

/// Bintang rating kecil (bisa separuh? tidak — rating server desimal,
/// dibulatkan ke bintang penuh + tampil nilai numerik di sebelahnya opsional).
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.size = 16,
    this.showValue = false,
    this.totalReviews,
  });

  /// Nilai rating 0–5 (dari `rating_avg`, sudah lewat parser aman).
  final double rating;
  final double size;

  /// Tampilkan angka rating di sebelah bintang.
  final bool showValue;

  /// Jumlah ulasan — bila terisi, tampil sebagai `(12 ulasan)`.
  final int? totalReviews;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rounded = rating.round().clamp(0, 5);

    final stars = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rounded ? Icons.star : Icons.star_border,
            size: size,
            color: i <= rounded
                ? const Color(0xFFF5A623)
                : theme.colorScheme.outline,
          ),
      ],
    );

    final label = <String>[
      if (showValue) rating.toStringAsFixed(1),
      if (totalReviews != null) '($totalReviews ulasan)',
    ].join(' ');

    if (label.isEmpty) return stars;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        stars,
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
