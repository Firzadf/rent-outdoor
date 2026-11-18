import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/depth.dart';
import '../../../core/widgets/error_view.dart';
import 'auth_controller.dart';

/// Halaman pembuka: memulihkan sesi dari token, lalu router mengarahkan
/// ke `/login`, `/home`, atau `/admin`.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.forestGreen, AppColors.pineDark],
          ),
        ),
        child: auth.when(
        loading: () => const _SplashContent(),
        error: (error, _) => ErrorView(
          icon: Icons.wifi_off,
          message: friendlyErrorMessage(error),
          onRetry: () => ref.invalidate(authControllerProvider),
        ),
        data: (_) => const _SplashContent(),
        ),
      ),
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: FadeSlideIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GradientIconBadge(
              icon: Icons.forest_outlined,
              size: 96,
              iconSize: 48,
            ),
            const SizedBox(height: 20),
            Text(
              'OutdoorRent',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sewa alat outdoor praktis',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
