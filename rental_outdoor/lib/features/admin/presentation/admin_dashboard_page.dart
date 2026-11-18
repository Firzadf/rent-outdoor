import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../booking/domain/booking.dart';
import '../domain/admin_dashboard.dart';
import 'admin_providers.dart';

/// Dashboard admin (`GET /admin/dashboard`): ringkasan angka + alat
/// terlaris, dengan pull-to-refresh.
///
/// Kartu **Menunggu Verifikasi** bisa diketuk -> membuka tab Pesanan
/// dengan filter `pending_verification`.
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  Future<void> _refresh() async {
    ref.invalidate(adminDashboardProvider);
    try {
      await ref.read(adminDashboardProvider.future);
    } catch (_) {
      // Error sudah tersimpan di state provider.
    }
  }

  /// Buka tab Pesanan dengan filter `pending_verification`.
  void _openPendingVerifications() {
    ref.read(adminBookingsFilterProvider.notifier)
        .setStatus(BookingStatus.pendingVerification);
    ref.read(adminBookingsSearchProvider.notifier).setSearch('');
    context.go('/admin/bookings');
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(adminDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: dashboardAsync.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: false,
          loading: _skeleton,
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorView(
                message: friendlyErrorMessage(error),
                onRetry: () => ref.invalidate(adminDashboardProvider),
              ),
            ),
          ),
          data: (dashboard) => RefreshIndicator(
            onRefresh: _refresh,
            child: _content(dashboard),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Konten
  // ---------------------------------------------------------------------

  Widget _content(AdminDashboard dashboard) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Ringkasan',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            _StatCard(
              icon: Icons.receipt_long_outlined,
              label: 'Total Pesanan',
              value: '${dashboard.totalOrders}',
            ),
            _StatCard(
              icon: Icons.payments_outlined,
              label: 'Pendapatan',
              value: formatRupiah(dashboard.totalRevenue),
              valueColor: theme.colorScheme.primary,
            ),
            _StatCard(
              icon: Icons.how_to_reg_outlined,
              label: 'Menunggu Verifikasi',
              value: '${dashboard.pendingVerificationCount}',
              onTap: _openPendingVerifications,
              hint: 'Ketuk untuk membuka daftar',
            ),
            _StatCard(
              icon: Icons.sync_alt_outlined,
              label: 'Sedang Berjalan',
              value: '${dashboard.activeRentalsCount}',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Alat Terlaris',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '5 teratas',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (dashboard.topEquipments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: EmptyView(
              message: 'Belum ada data alat terlaris.',
              icon: Icons.inventory_2_outlined,
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < dashboard.topEquipments.length; i++) ...[
                  _topEquipmentRow(dashboard.topEquipments[i], i),
                  if (i != dashboard.topEquipments.length - 1)
                    const Divider(height: 1, indent: 60),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _topEquipmentRow(TopEquipment equipment, int index) {
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: index < 3
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        foregroundColor: index < 3
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurfaceVariant,
        child: Text(
          '${index + 1}',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        equipment.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        equipment.categoryName ?? 'Jumlah unit terdisewa',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // total_rentals = STRING dari server (sudah lewat parser).
          Text(
            '${equipment.totalRentals}',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            'unit',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Skeleton (shimmer)
  // ---------------------------------------------------------------------

  Widget _skeleton() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        const ShimmerBox(height: 20, width: 120),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: List.generate(4, (_) => const ShimmerBox(height: 96)),
        ),
        const SizedBox(height: 24),
        const ShimmerBox(height: 20, width: 140),
        const SizedBox(height: 12),
        for (var i = 0; i < 5; i++) ...[
          const ShimmerBox(height: 64),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Kartu angka dashboard; [onTap] membuat kartu bisa diketuk.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return content;
    return Semantics(button: true, child: content);
  }
}
