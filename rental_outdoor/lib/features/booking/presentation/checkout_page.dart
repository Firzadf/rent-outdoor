import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../cart/domain/cart_item.dart';
import '../../cart/presentation/cart_provider.dart';
import '../data/booking_repository.dart';

/// Ringkasan pesanan sebelum dibuat: item, tanggal sewa, estimasi biaya,
/// catatan opsional, dan tombol "Buat Pesanan" (`POST /bookings`).
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final TextEditingController _notesController = TextEditingController();

  /// Mencegah double tap: satu alur "Buat Pesanan" dalam satu waktu.
  bool _submitting = false;

  /// Masih memvalidasi stok per item lewat `GET /equipments/{id}/availability`.
  bool _checking = false;

  /// Item yang stoknya kurang (ditampilkan sebelum pesanan dibuat).
  List<String> _shortages = const [];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Alur "Buat Pesanan":
  /// 1. validasi stok per item lewat `GET /equipments/{id}/availability`;
  /// 2. bila ada yang kurang -> tampilkan itemnya, pesanan TIDAK dibuat;
  /// 3. `POST /bookings` (tanpa harga — server yang menghitung);
  /// 4. sukses -> kosongkan keranjang lalu buka layar pembayaran.
  ///
  /// Gagal (400/409/422): pesan server tampil, keranjang TETAP utuh.
  Future<void> _submit(CartState cart) async {
    if (_submitting || _checking) return;

    final pickup = cart.pickupDate;
    final back = cart.returnDate;
    if (pickup == null || back == null) {
      _showMessage('Pilih tanggal sewa terlebih dahulu di tab Keranjang.');
      return;
    }

    setState(() {
      _checking = true;
      _shortages = const [];
    });

    // ---- 1) Validasi stok per tanggal untuk setiap item ----
    final shortages = <String>[];
    try {
      for (final item in cart.items) {
        final availability =
            await ref.read(catalogRepositoryProvider).getAvailability(
                  equipmentId: item.equipmentId,
                  pickupDate: pickup,
                  returnDate: back,
                );
        if (!availability.rentable) {
          shortages.add('${item.name}: tidak tersedia pada tanggal ini.');
        } else if (availability.availableStock < item.quantity) {
          shortages.add(
            '${item.name}: tersedia ${availability.availableStock} unit, '
            'Anda memilih ${item.quantity}.',
          );
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _shortages = const [];
      });
      _showMessage(e.message);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
      _showMessage('Gagal mengecek ketersediaan. Coba lagi.');
      return;
    }

    if (!mounted) return;
    if (shortages.isNotEmpty) {
      // Stok kurang -> tampilkan item mana yang kurang, jangan buat booking.
      setState(() {
        _checking = false;
        _shortages = shortages;
      });
      return;
    }

    // ---- 2) Buat pesanan ----
    setState(() {
      _checking = false;
      _submitting = true;
    });

    try {
      final booking = await ref.read(bookingRepositoryProvider).createBooking(
            pickupDate: pickup,
            returnDate: back,
            notes: _notesController.text,
            items: [
              for (final item in cart.items)
                (equipmentId: item.equipmentId, quantity: item.quantity),
            ],
          );

      // Sukses: keranjang dikosongkan (client + storage) lalu layar
      // pembayaran booking baru dibuka memakai id dari respons.
      await ref.read(cartProvider.notifier).clearCart();
      if (!mounted) return;
      context.go('/payment/${booking.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      // 400/409/422: pesan server ditampilkan, keranjang TIDAK dikosongkan.
      _showMessage(e.message);
      setState(() => _submitting = false);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Gagal membuat pesanan. Coba lagi.');
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(cartProvider);
            try {
              await ref.read(cartProvider.future);
            } catch (_) {
              // Error sudah tersimpan di state provider.
            }
          },
          child: cart.when(
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: false,
            loading: () => const LoadingView(message: 'Memuat keranjang...'),
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
                    message: 'Keranjang kosong — tambahkan alat dulu '
                        'sebelum checkout.',
                    icon: Icons.shopping_cart_outlined,
                    action: FilledButton.icon(
                      onPressed: () => context.go('/catalog'),
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('Jelajahi Katalog'),
                    ),
                  ),
                );
              }
              return _buildContent(state);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(CartState cart) {
    final theme = Theme.of(context);
    final totals = cart.totals;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _sectionTitle(context, 'Item Sewa'),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (var i = 0; i < cart.items.length; i++) ...[
                  if (i > 0) const Divider(height: 16),
                  _itemRow(cart.items[i], totals?.totalDays ?? 0),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---- Tanggal sewa ----
        _sectionTitle(context, 'Tanggal Sewa'),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: Text(
              totals == null
                  ? 'Tanggal belum dipilih'
                  : '${formatDate(cart.pickupDate)} - '
                      '${formatDate(cart.returnDate)}',
            ),
            subtitle: Text(
              totals == null
                  ? 'Pilih tanggal di tab Keranjang.'
                  : '${totals.totalDays} hari',
            ),
            trailing: TextButton(
              onPressed: () => context.go('/cart'),
              child: const Text('Ubah'),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---- Catatan ----
        _sectionTitle(context, 'Catatan (opsional)'),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: 'Contoh: ambil pagi hari, hubungi saya dulu...',
            counterText: '',
          ),
        ),
        const SizedBox(height: 8),

        // ---- Estimasi ----
        Card(
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
        ),
        const SizedBox(height: 16),

        // ---- Stok kurang ----
        if (_shortages.isNotEmpty) ...[
          _shortageBox(context, _shortages),
          const SizedBox(height: 16),
        ],

        // ---- Aksi ----
        AppButton(
          label: 'Buat Pesanan',
          icon: Icons.check_circle_outline,
          loading: _checking || _submitting,
          onPressed:
              (totals == null || _submitting || _checking) ? null : () => _submit(cart),
        ),
        const SizedBox(height: 8),
        Text(
          _submitting
              ? 'Membuat pesanan...'
              : 'Harga dan total final dihitung oleh server saat pesanan dibuat.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _itemRow(CartItem item, int totalDays) {
    final theme = Theme.of(context);
    final subtotal = totalDays > 0
        ? item.pricePerDay * item.quantity * totalDays
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              const SizedBox(height: 2),
              Text(
                '${formatRupiah(item.pricePerDay)}/hari × '
                '${item.quantity} unit'
                '${totalDays > 0 ? ' × $totalDays hari' : ''}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (subtotal != null)
          Text(
            formatRupiah(subtotal),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
      ],
    );
  }

  Widget _shortageBox(BuildContext context, List<String> shortages) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Stok tidak mencukupi',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in shortages)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $line',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          Text(
            'Kurangi jumlah atau ubah tanggal sewa, lalu coba lagi.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onErrorContainer),
          ),
        ],
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
    final style =
        (highlight ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
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
