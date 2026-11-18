import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../booking/domain/booking.dart';
import '../../booking/presentation/booking_status_style.dart';
import '../domain/admin_booking.dart';
import 'admin_providers.dart';
import '../../../core/widgets/depth.dart';

/// Chip filter status daftar pesanan admin (`null` = Semua).
///
/// `rejected` tidak dipakai alur server sehingga tidak ada chip-nya;
/// label cadangan untuk status tak dikenal tetap tersedia di badge.
const List<({String? value, String label})> _statusFilters = [
  (value: null, label: 'Semua'),
  (value: BookingStatus.pendingPayment, label: 'Menunggu Pembayaran'),
  (value: BookingStatus.pendingVerification, label: 'Menunggu Verifikasi'),
  (value: BookingStatus.confirmed, label: 'Dikonfirmasi'),
  (value: BookingStatus.inUse, label: 'Disewa'),
  (value: BookingStatus.completed, label: 'Selesai'),
  (value: BookingStatus.cancelled, label: 'Dibatalkan'),
];

/// Daftar pesanan admin (`GET /admin/bookings`): chip filter status,
/// pencarian debounce 500 ms, infinite scroll, pull-to-refresh.
class AdminBookingsPage extends ConsumerStatefulWidget {
  const AdminBookingsPage({super.key});

  @override
  ConsumerState<AdminBookingsPage> createState() => _AdminBookingsPageState();
}

class _AdminBookingsPageState extends ConsumerState<AdminBookingsPage> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _searchController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Isi awal dari state provider (dipertahankan selama tab hidup).
    _searchController =
        TextEditingController(text: ref.read(adminBookingsSearchProvider));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      ref.read(adminBookingsListProvider.notifier).loadMore();
    }
  }

  /// Debounce pencarian 500 ms sebelum memicu pemuatan ulang.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      ref.read(adminBookingsSearchProvider.notifier).setSearch(value);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(adminBookingsListProvider);
    try {
      await ref.read(adminBookingsListProvider.future);
    } catch (_) {
      // Error sudah tersimpan di state provider.
    }
  }

  void _retry() => ref.invalidate(adminBookingsListProvider);

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(adminBookingsFilterProvider);
    final search = ref.watch(adminBookingsSearchProvider);
    final list = ref.watch(adminBookingsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Pesanan')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari kode booking atau nama pelanggan',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, _) {
                      if (value.text.isEmpty) return const SizedBox.shrink();
                      return IconButton(
                        tooltip: 'Hapus pencarian',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _debounce?.cancel();
                          ref
                              .read(adminBookingsSearchProvider.notifier)
                              .setSearch('');
                        },
                      );
                    },
                  ),
                  isDense: true,
                ),
              ),
            ),
            _buildFilterChips(filter),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: list.when(
                  skipLoadingOnRefresh: true,
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
                          message: _emptyMessage(filter, search),
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

  String _emptyMessage(String? filter, String search) {
    if (search.trim().isNotEmpty) {
      return 'Tidak ada pesanan untuk pencarian "${search.trim()}".';
    }
    if (filter != null) {
      return 'Tidak ada pesanan dengan status ini.';
    }
    return 'Belum ada pesanan masuk.';
  }

  // ---------------------------------------------------------------------
  // Filter & daftar
  // ---------------------------------------------------------------------

  Widget _buildFilterChips(String? active) {
    final notifier = ref.read(adminBookingsFilterProvider.notifier);

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

  Widget _buildList(AdminBookingsListState data) {
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
                            onPressed: () => ref
                                .read(adminBookingsListProvider.notifier)
                                .loadMore(),
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

  Widget _bookingCard(AdminBooking booking) {
    final theme = Theme.of(context);
    final style = bookingStatusStyle(context, booking.status);

    return DepthCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/admin/bookings/${booking.id}'),
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
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      booking.userName ?? 'Pelanggan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
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
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // item_count = STRING dari server (sudah lewat parser).
                  Text(
                    '${booking.itemCount} alat • ${booking.totalDays} hari',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  // grand_total = STRING dari server (sudah lewat parser).
                  Text(
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
