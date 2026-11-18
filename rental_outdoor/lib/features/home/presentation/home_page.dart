import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../catalog/domain/category.dart';
import '../../catalog/presentation/catalog_filter_provider.dart';
import '../../catalog/presentation/categories_provider.dart';
import '../../catalog/presentation/equipment_card.dart';
import '../../catalog/presentation/popular_provider.dart';

/// Tab Beranda: sapaan nama user, chip kategori (buka Katalog terfilter),
/// dan alat populer (kartu horizontal).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(categoriesProvider);
    ref.invalidate(popularEquipmentsProvider);
    try {
      await Future.wait([
        ref.read(categoriesProvider.future),
        ref.read(popularEquipmentsProvider.future),
      ]);
    } catch (_) {
      // Error sudah tersimpan di masing-masing provider.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Sapaan dari data sesi (login/register) — tidak memicu
    // `GET /user/profile` hanya untuk menyapa (profil tetap dimuat
    // oleh tab Profil).
    final name =
        (ref.watch(authControllerProvider).value?.name ?? '').trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Beranda')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // ---- Sapaan ----
              if (name.isNotEmpty) ...[
                Text(
                  'Hai, $name',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mau sewa alat outdoor hari ini?',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
              ],

              // ---- Kategori ----
              _sectionTitle(context, 'Kategori'),
              const SizedBox(height: 4),
              _buildCategories(context, ref),
              const SizedBox(height: 20),

              // ---- Alat populer ----
              _sectionTitle(context, 'Alat Populer'),
              const SizedBox(height: 8),
              _buildPopular(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  /// Chip kategori horizontal — tap membuka Katalog terfilter kategori itu.
  Widget _buildCategories(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider);

    return SizedBox(
      height: 48,
      child: categories.when(
        loading: () => const _RowSkeleton(),
        error: (error, _) => Center(
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Kategori gagal dimuat.',
                style: theme.textTheme.bodySmall,
              ),
              TextButton(
                onPressed: () => ref.invalidate(categoriesProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'Belum ada kategori.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            );
          }
          return ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final Category category in items)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.label_outline, size: 18),
                    label: Text(category.name),
                    onPressed: () {
                      ref
                          .read(catalogFilterProvider.notifier)
                          .setCategory(category.id);
                      // Pindah ke tab Katalog (bukan push) — state tab lain
                      // tetap tersimpan.
                      context.go('/catalog');
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Alat populer: kartu horizontal (gambar, nama, harga/hari, rating).
  Widget _buildPopular(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final popular = ref.watch(popularEquipmentsProvider);

    return SizedBox(
      height: 285,
      child: popular.when(
        loading: () => const _CardSkeleton(),
        error: (error, _) => Center(
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Alat populer gagal dimuat.',
                style: theme.textTheme.bodySmall,
              ),
              TextButton(
                onPressed: () => ref.invalidate(popularEquipmentsProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'Belum ada alat populer.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            );
          }
          return ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final equipment in items)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: EquipmentPopularCard(
                    equipment: equipment,
                    onTap: () => context.push('/equipment/${equipment.id}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Skeleton chip kategori (shimmer).
class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: const [
        ShimmerBox(width: 88, height: 36, radius: 18),
        SizedBox(width: 8),
        ShimmerBox(width: 104, height: 36, radius: 18),
        SizedBox(width: 8),
        ShimmerBox(width: 92, height: 36, radius: 18),
      ],
    );
  }
}

/// Skeleton kartu populer (shimmer).
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: const [
        ShimmerBox(width: 170, height: 275),
        SizedBox(width: 12),
        ShimmerBox(width: 170, height: 275),
        SizedBox(width: 12),
        ShimmerBox(width: 170, height: 275),
      ],
    );
  }
}
