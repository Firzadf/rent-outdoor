import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/image_url.dart';

/// Widget gambar jaringan seragam dengan placeholder dan error.
///
/// Fitur:
/// - Pakai cached_network_image untuk cache lokal
/// - Resolve URL via [resolveImageUrl]
/// - Placeholder: ikon gambar
/// - Error: ikon image_not_supported
/// - [cacheVersion] untuk memaksa gambar baru setelah upload/hapus
///   (mis. `updated_at` dari server).
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage(
    this.imageUrl, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.cacheVersion,
  });

  /// URL gambar dari server (bisa relative atau absolute).
  final String? imageUrl;

  /// Lebar gambar (optional).
  final double? width;

  /// Tinggi gambar (optional).
  final double? height;

  /// Fit gambar.
  final BoxFit fit;

  /// Custom placeholder widget. Default: ikon gambar.
  final Widget? placeholder;

  /// Custom error widget. Default: ikon image_not_supported.
  final Widget? errorWidget;

  /// Versi cache (mis. `updated_at`). Bila berubah, URL gambar berubah
  /// sehingga cache lama tidak dipakai lagi.
  final String? cacheVersion;

  @override
  Widget build(BuildContext context) {
    // URL kosong/null -> tampil error widget
    if (imageUrl == null || imageUrl!.isEmpty) {
      return errorWidget ?? _defaultErrorWidget();
    }

    // Resolve URL (gabung dengan origin jika relatif)
    var url = resolveImageUrl(imageUrl);

    // URL kosong setelah resolve -> error widget
    if (url.isEmpty) {
      return errorWidget ?? _defaultErrorWidget();
    }

    final version = cacheVersion?.trim();
    if (version != null && version.isNotEmpty) {
      url = '$url${url.contains('?') ? '&' : '?'}v=$version';
    }

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => placeholder ?? _defaultPlaceholder(),
      errorWidget: (_, __, ___) => errorWidget ?? _defaultErrorWidget(),
    );
  }

  Widget _defaultPlaceholder() {
    return const Center(
      child: Icon(
        Icons.image_outlined,
        size: 32,
      ),
    );
  }

  Widget _defaultErrorWidget() {
    return const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 32,
      ),
    );
  }
}
