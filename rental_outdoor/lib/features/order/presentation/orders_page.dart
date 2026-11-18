import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../booking/domain/booking.dart';
import '../../booking/presentation/booking_status_style.dart';
import '../../booking/presentation/bookings_provider.dart';

/// Filter chip daftar pesanan: nilai `status` untuk `GET /bookings`
/// (`null` = Semua).
const List<({String? value, String label})> _statusFilters = [
  (value: null, label: 'Semua'),
  (value: BookingStatus.pendingPayment, label: 'Menunggu Pembayaran'),
  (value: BookingStatus.pendingVerification, label: 'Menunggu Verifikasi'),
  (value: BookingStatus.confirmed, label: 'Dikonfirmasi'),
  (value: BookingStatus.inUse, label: 'Disewa'),
  (value: BookingStatus.completed, label: 'Selesai'),
  (value: BookingStatus.cancelled, label: 'Dibatalkan'),
];

/// Tab Pesanan: daftar booking milik user dengan filter status,
/// infinite scroll (`data.pagination`), dan pull-to-refresh.
class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      ref.read(bookingsListProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(bookingsListProvider);
    try {
      await ref.read(bookingsListProvider.future);
    } catch (_) {
      // Error sudah tersimpan di state provider.
    }
  }

  void _retry() => ref.invalidate(bookingsListProvider);

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(bookingsFilterProvider);
    final list = ref.watch(bookingsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterChips(filter),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: list.when(
                  // Daftar lama tetap tampil saat pull-to-refresh.
                  skipLoadingOnRefresh: true,
                  // Ganti filter -> tampilkan skeleton.
                  skipLoadingOnReload: false,
                  loading: () => const LoadingView.list(),
                  error: (error, _) => _fullMessage(
                    ErrorView(
                      message: friendlyErrorMessage(error),
                      onRetry: _retry,
                    ),
                  ),
                  data: (data) {
                    if (data.items.isEmpty) {
                      return _fullMessage(
                        EmptyView(
                          message: filter == null
                              ? 'Belum ada pesanan. Sewa alat dulu di Katalog.'
                              : 'Tidak ada pesanan dengan status ini.',
                          icon: Icons.receipt_long_outlined,
                        ),
                      );
                    }
                    return _buildList(data);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chip filter status (horizontal).
  Widget _buildFilterChips(String? active) {
    final notifier = ref.read(bookingsFilterProvider.notifier);

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final filter in _statusFilters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter.label),
                selected: active == filter.value,
                onSelected: (_) => notifier.setStatus(filter.value),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(BookingsListState data) {
    final showFooter = data.loadingMore || data.loadMoreError != null;

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverList.separated(
            itemCount: data.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _bookingCard(data.items[index]),
          ),
        ),
        if (showFooter)
          SliverToBoxAdapter(
            child: data.loadMoreError == null
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            data.loadMoreError!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                          TextButton(
                            onPressed: () =>
                                ref.read(bookingsListProvider.notifier).loadMore(),
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _bookingCard(Booking booking) {
    final theme = Theme.of(context);
    final style = bookingStatusStyle(context, booking.status);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/booking/${booking.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      booking.bookingCode.isEmpty
                          ? 'Pesanan #${booking.id}'
                          : booking.bookingCode,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _statusBadge(style),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${formatDate(booking.pickupDate)} - '
                      '${formatDate(booking.returnDate)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                // `GET /bookings` tidak mengirim items[] (API_DOCS.md),
                // jadi jumlah alat hanya tampil bila server menyertakannya;
                // selain itu pakai durasi sewa.
                booking.items.isNotEmpty
                    ? '${booking.items.fold<int>(0, (sum, item) => sum + item.quantity)} alat • ${booking.totalDays} hari'
                    : '${booking.totalDays} hari sewa',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    // grand_total = STRING dari server, sudah lewat parser.
                    formatRupiah(booking.grandTotal),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(BookingStatusStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: style.foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  /// Pesan tengah (empty/error) yang tetap bisa ditarik untuk refresh.
  Widget _fullMessage(Widget child) {
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
