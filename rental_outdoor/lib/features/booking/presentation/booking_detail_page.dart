import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../payment/domain/payment.dart';
import '../../payment/presentation/payment_providers.dart';
import '../../review/presentation/review_form.dart';
import '../../review/presentation/review_provider.dart';
import '../data/booking_repository.dart';
import '../domain/booking.dart';
import 'booking_status_style.dart';
import 'bookings_provider.dart';
import '../../../core/widgets/depth.dart';

/// Detail satu pesanan `GET /bookings/{id}`: rincian biaya, riwayat
/// pembayaran, tombol aksi sesuai status, dan (untuk `completed`) form
/// ulasan per alat.
class BookingDetailPage extends ConsumerStatefulWidget {
  const BookingDetailPage({super.key, required this.bookingId});

  final int bookingId;

  @override
  ConsumerState<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends ConsumerState<BookingDetailPage> {
  /// Mencegah double tap saat membatalkan pesanan.
  bool _cancelling = false;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refresh() async {
    ref.invalidate(bookingDetailProvider(widget.bookingId));
    try {
      await ref.read(bookingDetailProvider(widget.bookingId).future);
    } catch (_) {
      // Error sudah tersimpan di state provider.
    }
  }

  // ---------------------------------------------------------------------
  // Aksi
  // ---------------------------------------------------------------------

  /// Buka halaman pembayaran yang sudah ada (`/payment/:id`) — dipakai
  /// tombol "Bayar" dan "Upload Ulang".
  void _openPayment(Booking booking) =>
      context.push('/payment/${booking.id}');

  /// Dialog konfirmasi + input alasan, lalu `PUT /bookings/{id}/cancel`.
  Future<void> _confirmCancel(Booking booking) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan pesanan ini?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pesanan ${booking.bookingCode} akan dibatalkan. Tindakan ini '
              'tidak bisa dibatalkan.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Alasan pembatalan (opsional)',
                hintText: 'Contoh: salah tanggal sewa',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    // Dibaca SEBELUM controller dibuang.
    final reason = reasonController.text;
    reasonController.dispose();

    if (confirmed != true) return;
    await _cancel(booking, reason);
  }

  Future<void> _cancel(Booking booking, String reason) async {
    setState(() => _cancelling = true);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .cancelBooking(booking.id, reason: reason);
      if (!mounted) return;
      // Daftar + detail diperbarui otomatis setelah pembatalan sukses.
      ref.invalidate(bookingsListProvider);
      ref.invalidate(bookingDetailProvider(booking.id));
      _showMessage('Pesanan ${booking.bookingCode} dibatalkan.');
    } on ApiException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Gagal membatalkan pesanan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  /// Bottom sheet ulasan (hanya untuk pesanan `completed`).
  Future<void> _openReview(Booking booking, BookingItem item) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ReviewForm(
          bookingId: booking.id,
          equipmentId: item.equipmentId,
          equipmentName: item.equipmentName ?? 'Alat',
        ),
      ),
    );
    if (sent == true) {
      _showMessage('Ulasan terkirim. Terima kasih!');
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: bookingAsync.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: false,
          loading: () => const LoadingView(message: 'Memuat detail pesanan...'),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorView(
                message: friendlyErrorMessage(error),
                onRetry: () =>
                    ref.invalidate(bookingDetailProvider(widget.bookingId)),
              ),
            ),
          ),
          data: (booking) => RefreshIndicator(
            onRefresh: _refresh,
            child: _content(booking),
          ),
        ),
      ),
    );
  }

  Widget _content(Booking booking) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _headerCard(booking),
        const SizedBox(height: 16),
        if (booking.items.isNotEmpty) ...[
          _itemsCard(booking),
          const SizedBox(height: 16),
        ],
        _costCard(booking),
        const SizedBox(height: 16),
        _paymentsCard(booking),
        const SizedBox(height: 20),
        _actions(booking),
      ],
    );
  }

  /// Kode, status, tanggal, catatan, dan info batas bayar.
  Widget _headerCard(Booking booking) {
    final theme = Theme.of(context);
    final style = bookingStatusStyle(context, booking.status);

    return DepthCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: style.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    style.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: style.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _infoRow(
              Icons.login_outlined,
              'Tanggal ambil',
              formatDate(booking.pickupDate),
            ),
            const SizedBox(height: 8),
            _infoRow(
              Icons.logout_outlined,
              'Tanggal kembali',
              formatDate(booking.returnDate),
            ),
            const SizedBox(height: 8),
            _infoRow(
              Icons.calendar_month_outlined,
              'Lama sewa',
              '${booking.totalDays} hari',
            ),
            if (booking.actualReturnDate != null) ...[
              const SizedBox(height: 8),
              _infoRow(
                Icons.event_available_outlined,
                'Kembali sebenarnya',
                formatDate(booking.actualReturnDate),
              ),
            ],
            if (booking.notes != null && booking.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Catatan Anda',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(booking.notes!, style: theme.textTheme.bodyMedium),
            ],
            if (booking.status == BookingStatus.cancelled &&
                booking.cancellationReason != null &&
                booking.cancellationReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _banner(
                icon: Icons.cancel_outlined,
                background: theme.colorScheme.errorContainer,
                foreground: theme.colorScheme.onErrorContainer,
                title: 'Pesanan dibatalkan',
                message: booking.cancellationReason!,
              ),
            ],
            // Batas bayar: status tetap ditentukan SERVER (bukan dihitung
            // di client), jadi di sini hanya informasi.
            if (booking.isAwaitingPayment && booking.autoCancelAt != null) ...[
              const SizedBox(height: 12),
              _banner(
                icon: Icons.timer_outlined,
                background: theme.colorScheme.surfaceContainerHighest,
                foreground: theme.colorScheme.onSurfaceVariant,
                title: 'Batas waktu pembayaran',
                message: 'Bayar sebelum ${formatDateTime(booking.autoCancelAt)}. '
                    'Bila lewat batas tersebut, pesanan dibatalkan otomatis '
                    'oleh server.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Daftar alat + tombol ulasan per alat (hanya `completed`).
  Widget _itemsCard(Booking booking) {
    final theme = Theme.of(context);
    final reviewState = ref.watch(bookingReviewProvider(booking.id));

    return DepthCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alat yang Disewa',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            for (final item in booking.items) ...[
              _itemRow(booking, item, reviewState),
              if (item != booking.items.last) const Divider(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemRow(Booking booking, BookingItem item, ReviewSubmitState reviewState) {
    final theme = Theme.of(context);
    final imageUrl = resolveImageUrl(item.primaryImageUrl);
    final reviewed = reviewState.isReviewed(item.equipmentId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: imageUrl.isEmpty
                    ? Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: theme.colorScheme.outline,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const ShimmerBox(height: 64),
                        errorWidget: (_, __, ___) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: theme.colorScheme.outline,
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
                    item.equipmentName ?? 'Alat #${item.equipmentId}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.quantity} unit'
                    '${item.pricePerDay != null ? ' × ${formatRupiah(item.pricePerDay)}/hari' : ''}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (item.subtotal != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Subtotal: ${formatRupiah(item.subtotal)}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (booking.canReview) ...[
          const SizedBox(height: 8),
          if (reviewed)
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Sudah diulas',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: () => _openReview(booking, item),
              icon: const Icon(Icons.star_border, size: 18),
              label: const Text('Beri Ulasan'),
            ),
        ],
      ],
    );
  }

  /// Rincian biaya; `late_fee` / `damage_fee` / `deposit_refund` hanya
  /// tampil saat `completed`.
  Widget _costCard(Booking booking) {
    final theme = Theme.of(context);
    final completed = booking.status == BookingStatus.completed;

    return DepthCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rincian Biaya',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _costRow('Subtotal sewa', formatRupiah(booking.subtotal)),
            const SizedBox(height: 8),
            _costRow('Deposit', formatRupiah(booking.depositTotal)),
            if (completed) ...[
              const SizedBox(height: 8),
              _costRow('Denda keterlambatan', formatRupiah(booking.lateFee)),
              const SizedBox(height: 8),
              _costRow('Biaya kerusakan', formatRupiah(booking.damageFee)),
              const SizedBox(height: 8),
              _costRow('Deposit dikembalikan', formatRupiah(booking.depositRefund)),
            ],
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total pesanan',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  formatRupiah(booking.grandTotal),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (completed) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deposit dikembalikan',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Besarnya deposit yang kembali ke Anda setelah pesanan '
                      'selesai, dihitung server dari kondisi alat:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _bullet('Baik (good): deposit − denda keterlambatan'),
                    _bullet('Rusak (damaged): deposit − biaya kerusakan − denda'),
                    _bullet('Hilang (lost): deposit hangus (Rp 0)'),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.fact_check_outlined,
                      'Kondisi alat',
                      _returnConditionLabel(booking.returnCondition),
                    ),
                    if (booking.returnNotes != null &&
                        booking.returnNotes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Catatan kondisi: ${booking.returnNotes}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Riwayat pembayaran (status, tanggal, bukti, alasan penolakan).
  Widget _paymentsCard(Booking booking) {
    final theme = Theme.of(context);
    final payments = [...booking.payments]
      ..sort((a, b) => b.id.compareTo(a.id));

    return DepthCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Riwayat Pembayaran',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (payments.isEmpty)
              Text(
                'Belum ada pembayaran untuk pesanan ini.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              for (final payment in payments) ...[
                _paymentRow(payment),
                if (payment != payments.last) const Divider(height: 20),
              ],
          ],
        ),
      ),
    );
  }

  Widget _paymentRow(Payment payment) {
    final theme = Theme.of(context);
    final proofUrl = resolveImageUrl(payment.paymentProof);
    final rejected = payment.isRejected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Pembayaran #${payment.id}',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            _miniBadge(
              label: PaymentStatus.label(payment.status ?? ''),
              rejected: rejected,
              approved: payment.isApproved,
            ),
          ],
        ),
        const SizedBox(height: 6),
        _infoRow(
          Icons.payments_outlined,
          'Jumlah',
          formatRupiah(payment.amount),
        ),
        const SizedBox(height: 6),
        _infoRow(
          Icons.schedule_outlined,
          'Tanggal',
          formatDateTime(payment.createdAt ?? payment.paymentDate),
        ),
        if (proofUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: proofUrl,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              placeholder: (_, __) => const ShimmerBox(
                width: 120,
                height: 120,
                radius: 10,
              ),
              errorWidget: (_, __, ___) => Container(
                width: 120,
                height: 120,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ),
        ],
        if (rejected && payment.rejectionReason != null) ...[
          const SizedBox(height: 10),
          _banner(
            icon: Icons.report_gmailerrorred_outlined,
            background: theme.colorScheme.errorContainer,
            foreground: theme.colorScheme.onErrorContainer,
            title: 'Bukti pembayaran ditolak',
            message: payment.rejectionReason!,
          ),
        ],
      ],
    );
  }

  /// Tombol aksi sesuai status (Bayar / Upload Ulang, Batalkan).
  Widget _actions(Booking booking) {
    final theme = Theme.of(context);
    final canPay = booking.canPay;
    final rejected = booking.lastPayment?.isRejected ?? false;

    if (!canPay && !booking.canCancel) {
      return Text(
        booking.canReview
            ? 'Pesanan sudah selesai. Anda bisa memberi ulasan pada '
                'masing-masing alat di atas.'
            : 'Tidak ada tindakan yang tersedia untuk status pesanan ini.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return Column(
      children: [
        if (canPay)
          AppButton(
            label: rejected ? 'Upload Ulang Bukti' : 'Bayar Sekarang',
            icon: rejected ? Icons.upload_file_outlined : Icons.payment_outlined,
            onPressed: () => _openPayment(booking),
          ),
        if (canPay && booking.canCancel) const SizedBox(height: 10),
        if (booking.canCancel)
          AppButton(
            label: 'Batalkan Pesanan',
            icon: Icons.cancel_outlined,
            danger: true,
            loading: _cancelling,
            onPressed: _cancelling ? null : () => _confirmCancel(booking),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Widget kecil
  // ---------------------------------------------------------------------

  Widget _infoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _costRow(String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _bullet(String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: theme.textTheme.bodySmall),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner({
    required IconData icon,
    required Color background,
    required Color foreground,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700, color: foreground),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBadge({
    required String label,
    required bool rejected,
    required bool approved,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final background = rejected
        ? scheme.errorContainer
        : approved
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest;
    final foreground = rejected
        ? scheme.onErrorContainer
        : approved
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  String _returnConditionLabel(String? condition) => switch (condition) {
        'good' => 'Baik',
        'damaged' => 'Rusak',
        'lost' => 'Hilang',
        null => '-',
        _ => condition,
      };
}
