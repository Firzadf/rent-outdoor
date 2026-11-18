import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Indicator loading tengah layar.
///
/// `LoadingView.list()` menampilkan skeleton shimmer untuk daftar.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message, this.skeleton = false});

  /// Skeleton daftar (shimmer) — pakai `const LoadingView.list()`.
  const LoadingView.list({super.key})
      : message = null,
        skeleton = true;

  final String? message;
  final bool skeleton;

  @override
  Widget build(BuildContext context) {
    if (skeleton) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const ShimmerBox(height: 92),
      );
    }

    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kotak shimmer untuk skeleton placeholder.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 12,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: dark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: dark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: dark ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
