import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/widgets/depth.dart';
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

/// Foto kartu dengan scrim gradien di bawah dan chip kaca di atas:
/// chip kategori di kiri atas, chip stok di kanan atas.
class _CardPhoto extends StatelessWidget {
  const _CardPhoto({required this.equipment, required this.aspectRatio});

  final Equipment equipment;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          EquipmentThumb(imageUrl: equipment.primaryImageUrl),
          // Scrim gradien supaya chip tetap terbaca di atas foto terang.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromRGBO(0, 0, 0, 0.18),
                  Color.fromRGBO(0, 0, 0, 0),
                  Color.fromRGBO(0, 0, 0, 0),
                ],
                stops: [0, 0.35, 1],
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: GlassPanel(
              child: Text(
                equipment.categoryName ?? 'Outdoor',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestGreenDark,
                    ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: StockChip(stock: equipment.stock),
          ),
        ],
      ),
    );
  }
}

/// Kartu alat untuk GRID 2 kolom (Katalog): foto menonjol, nama,
/// rating, harga per hari, dan deposit dengan hierarki yang jelas.
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

    return DepthCard(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardPhoto(equipment: equipment, aspectRatio: 4 / 3),
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
                  const SizedBox(height: 6),
                  Text(
                    'Deposit ${formatRupiah(equipment.deposit)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
                            fontWeight: FontWeight.w800,
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
    );
  }
}

/// Kartu alat HORIZONTAL (Beranda "Alat Populer"): foto, nama,
/// harga/hari, rating, dan deposit.
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
      child: DepthCard(
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardPhoto(equipment: equipment, aspectRatio: 4 / 3),
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
                    const SizedBox(height: 6),
                    Text(
                      'Deposit ${formatRupiah(equipment.deposit)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${formatRupiah(equipment.pricePerDay)}/hari',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
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
