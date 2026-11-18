import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/utils/rental.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../domain/cart_item.dart';
import 'cart_provider.dart';

/// Tab Keranjang: item + pemilih jumlah, satu tanggal sewa untuk semua
/// item, dan estimasi biaya (client-side, lihat API_DOCS.md).
class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(cartProvider);
    try {
      await ref.read(cartProvider.future);
    } catch (_) {
      // Error sudah tersimpan di state provider.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang'),
        actions: [
          if (!(cart.value?.isEmpty ?? true))
            IconButton(
              tooltip: 'Kosongkan keranjang',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: cart.when(
            // Daftar lama tetap tampil saat refresh agar child tidak
            // kehilangan scroll view-nya.
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: false,
            loading: () => const LoadingView.list(),
            error: (error, _) => _scrollable(
              ErrorView(
                message: friendlyErrorMessage(error),
                onRetry: () => ref.invalidate(cartProvider),
              ),
            ),
            data: (state) {
              if (state.isEmpty) {
                return _scrollable(
                  EmptyView(
                    message: 'Keranjang masih kosong. '
                        'Peralatan yang Anda pilih akan muncul di sini.',
                    icon: Icons.shopping_cart_outlined,
                    action: FilledButton.icon(
                      onPressed: () => context.go('/catalog'),
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('Jelajahi Katalog'),
                    ),
                  ),
                );
              }
              return _buildContent(context, ref, state);
            },
          ),
        ),
      ),
    );
  }

  /// Daftar isi + tanggal sewa + estimasi + tombol checkout.
  Widget _buildContent(BuildContext context, WidgetRef ref, CartState state) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _dateCard(context, ref, state),
        const SizedBox(height: 12),
        for (final item in state.items) ...[
          _itemCard(context, ref, item),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        _totalsCard(context, state),
        const SizedBox(height: 16),
        AppButton(
          label: 'Lanjut ke Checkout',
          icon: Icons.arrow_forward,
          // Butuh tanggal sewa yang valid sebelum masuk checkout.
          onPressed:
              state.hasValidRange ? () => context.push('/checkout') : null,
        ),
        if (!state.hasValidRange) ...[
          const SizedBox(height: 8),
          Text(
            'Pilih tanggal sewa terlebih dahulu.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Tanggal sewa (berlaku untuk seluruh keranjang)
  // ---------------------------------------------------------------------

  Widget _dateCard(BuildContext context, WidgetRef ref, CartState state) {
    final theme = Theme.of(context);
    final pickup = state.pickupDate;
    final back = state.returnDate;
    final valid = state.hasValidRange;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tanggal Sewa',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (valid)
              Text(
                '${formatDate(pickup!)} - ${formatDate(back!)}'
                '  •  ${calculateTotalDays(pickup, back)} hari',
                style: theme.textTheme.titleSmall,
              )
            else
              Text(
                'Satu tanggal berlaku untuk semua item di keranjang.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _pickRange(context, ref, state),
              icon: const Icon(Icons.calendar_month, size: 18),
              label: Text(valid ? 'Ganti Tanggal' : 'Pilih Tanggal Sewa'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange(
    BuildContext context,
    WidgetRef ref,
    CartState state,
  ) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final initial = (state.pickupDate != null && state.returnDate != null)
        ? DateTimeRange(start: state.pickupDate!, end: state.returnDate!)
        : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      // Maksimal setahun ke depan (batas wajar pemesanan).
      lastDate: firstDate.add(const Duration(days: 365)),
      initialDateRange: initial,
      helpText: 'PILIH TANGGAL SEWA',
      confirmText: 'PILIH',
      cancelText: 'BATAL',
    );
    if (picked == null || !context.mounted) return;

    // Aturan server: minimal 1 malam (return > pickup), tanpa tanggal lampau.
    final ok = await ref.read(cartProvider.notifier).setRange(
          picked.start,
          picked.end,
        );
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Tanggal sewa minimal 1 malam — tanggal kembali harus '
              'setelah tanggal ambil.',
            ),
          ),
        );
    }
  }

  // ---------------------------------------------------------------------
  // Item
  // ---------------------------------------------------------------------

  Widget _itemCard(BuildContext context, WidgetRef ref, CartItem item) {
    final theme = Theme.of(context);
    final url = resolveImageUrl(item.imageUrl);
    final canIncrease = item.quantity < item.stock;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto alat (URL lengkap dari server) + placeholder.
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: url.isEmpty
                        ? ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(
                              Icons.image_outlined,
                              color: Colors.grey,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatRupiah(item.pricePerDay)}/hari',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Deposit: ${formatRupiah(item.deposit)} / unit',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus item',
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: () => _removeItem(context, ref, item),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Kurangi jumlah',
                  onPressed: () => ref
                      .read(cartProvider.notifier)
                      .setQuantity(item.equipmentId, item.quantity - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Tambah jumlah',
                  // Dibatasi stok alat.
                  onPressed: canIncrease
                      ? () => ref
                          .read(cartProvider.notifier)
                          .setQuantity(item.equipmentId, item.quantity + 1)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    canIncrease
                        ? 'Maksimal ${item.stock} unit.'
                        : 'Jumlah mentok di stok (${item.stock} unit).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeItem(
    BuildContext context,
    WidgetRef ref,
    CartItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus item?'),
        content: Text('"${item.name}" akan dihapus dari keranjang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(cartProvider.notifier).removeItem(item.equipmentId);
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kosongkan keranjang?'),
        content: const Text('Semua item akan dihapus dari keranjang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(cartProvider.notifier).clearCart();
  }

  // ---------------------------------------------------------------------
  // Estimasi biaya
  // ---------------------------------------------------------------------

  Widget _totalsCard(BuildContext context, CartState state) {
    final theme = Theme.of(context);
    final totals = state.totals;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: totals == null
            ? Text(
                'Pilih tanggal sewa untuk melihat estimasi biaya.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Estimasi Biaya',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _amountRow(
                    context,
                    'Subtotal sewa (${totals.totalDays} hari)',
                    formatRupiah(totals.subtotal),
                  ),
                  const SizedBox(height: 6),
                  _amountRow(
                    context,
                    'Deposit',
                    formatRupiah(totals.depositTotal),
                  ),
                  const Divider(height: 20),
                  _amountRow(
                    context,
                    'Total estimasi',
                    formatRupiah(totals.grandTotal),
                    highlight: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Estimasi, total final dihitung server.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _amountRow(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    final theme = Theme.of(context);
    final style = (highlight ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
        ?.copyWith(
      fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
      color: highlight ? theme.colorScheme.primary : null,
    );

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: highlight
                ? style
                : theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
        ),
        Text(value, style: style),
      ],
    );
  }

  /// ListView yang tetap bisa ditarik untuk refresh pada pesan tengah.
  Widget _scrollable(Widget child) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: child,
        ),
      ],
    );
  }
}
