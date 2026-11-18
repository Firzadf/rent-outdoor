import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/widgets/rating_stars.dart';
import '../domain/equipment.dart';

/// Thumbnail alat: gambar dari server (URL penuh) dengan placeholder
/// bila kosong/gagal dimuat ([CachedNetworkImage] + `errorWidget`).
class EquipmentThumb extends StatelessWidget {
  const EquipmentThumb({
    super.key,
    required this.imageUrl,
    this.icon = Icons.image_outlined,
  });

  /// Bisa `null` (alat belum punya gambar) — tampil placeholder.
  final String? imageUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = resolveImageUrl(imageUrl);

    if (url.isEmpty) return _placeholder(theme);

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) => _placeholder(theme),
    );
  }

  Widget _placeholder(ThemeData theme) => ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(icon, size: 40, color: theme.colorScheme.outline),
        ),
      );
}

/// Kartu alat untuk GRID 2 kolom (Katalog): gambar, nama, rating,
/// harga/hari.
class EquipmentGridCard extends StatelessWidget {
  const EquipmentGridCard({
    super.key,
    required this.equipment,
    required this.onTap,
  });

  final Equipment equipment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: EquipmentThumb(imageUrl: equipment.primaryImageUrl),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipment.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    RatingStars(
                      rating: equipment.ratingAvg,
                      size: 15,
                      showValue: true,
                      totalReviews: equipment.totalReviews,
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            formatRupiah(equipment.pricePerDay),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '/hari',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu alat HORIZONTAL (Beranda "Alat Populer"): gambar, nama,
/// harga/hari, rating.
class EquipmentPopularCard extends StatelessWidget {
  const EquipmentPopularCard({
    super.key,
    required this.equipment,
    required this.onTap,
    this.width = 170,
  });

  final Equipment equipment;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: EquipmentThumb(imageUrl: equipment.primaryImageUrl),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipment.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      RatingStars(
                        rating: equipment.ratingAvg,
                        size: 15,
                        showValue: true,
                        totalReviews: equipment.totalReviews,
                      ),
                      const Spacer(),
                      Text(
                        '${formatRupiah(equipment.pricePerDay)}/hari',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
