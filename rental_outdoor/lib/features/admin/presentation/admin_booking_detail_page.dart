import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../booking/domain/booking.dart';
import '../../booking/presentation/booking_status_style.dart';
import '../../payment/domain/payment.dart';
import '../data/admin_repository.dart';
import '../domain/admin_booking.dart';
import 'admin_complete_input.dart';
import 'admin_providers.dart';
import '../../../core/widgets/depth.dart';

/// Detail pesanan admin (`GET /admin/bookings/{id}`): data pelanggan,
/// alat, rincian biaya, semua pembayaran (bukti bisa diperbesar), dan
/// aksi sesuai status (verifikasi / mulai sewa / selesaikan).
class AdminBookingDetailPage extends ConsumerStatefulWidget {
  const AdminBookingDetailPage({super.key, required this.bookingId});

  final int bookingId;

  @override
  ConsumerState<AdminBookingDetailPage> createState() =>
      _AdminBookingDetailPageState();
}

class _AdminBookingDetailPageState extends ConsumerState<AdminBookingDetailPage> {
  /// Mencegah double tap pada semua aksi tulis.
  bool _acting = false;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refresh() async {
    ref.invalidate(adminBookingDetailProvider(widget.bookingId));
    try {
      await ref.read(adminBookingDetailProvider(widget.bookingId).future);
    } catch (_) {
      // Error sudah tersimpan di state provider.
    }
  }

  // ---------------------------------------------------------------------
  // Aksi
  // ---------------------------------------------------------------------

  /// Jalankan satu aksi tulis dengan guard double tap + pesan ramah
  /// untuk `400`/`404` dari server, lalu refresh detail + daftar +
  /// dashboard.
  Future<void> _run(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await action();
      if (!mounted) return;
      refreshAdminData(ref, bookingId: widget.bookingId);
      _showMessage(successMessage);
    } on ApiException catch (e) {
      // 400 (status/syarat tak terpenuhi) & 404 (data hilang) -> pesan server.
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Gagal memproses pesanan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Verifikasi: `PUT /admin/bookings/{id}/verify` `{action: approve}`.
  Future<void> _approve(AdminBooking booking) async {
    final ok = await _confirm(
      title: 'Setujui pembayaran?',
      message: 'Pembayaran pesanan ${booking.bookingCode} akan disetujui '
          'dan pesanan berstatus Dikonfirmasi.',
      confirmLabel: 'Setujui',
    );
    if (!ok) return;
    await _run(
      () => ref.read(adminRepositoryProvider).verifyBooking(
            booking.id,
            action: 'approve',
          ),
      successMessage: 'Pembayaran disetujui. Pesanan dikonfirmasi.',
    );
  }

  /// Verifikasi: `{action: reject, rejection_reason}` — alasan wajib.
  Future<void> _reject(AdminBooking booking) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectReasonDialog(bookingCode: booking.bookingCode),
    );
    if (reason == null) return; // dibatalkan
    await _run(
      () => ref.read(adminRepositoryProvider).verifyBooking(
            booking.id,
            action: 'reject',
            rejectionReason: reason,
          ),
      successMessage: 'Pembayaran ditolak. Pelanggan bisa mengunggah ulang '
          'bukti pembayaran.',
    );
  }

  /// `PUT /admin/bookings/{id}/start` — `confirmed` -> `in_use`.
  Future<void> _start(AdminBooking booking) async {
    final ok = await _confirm(
      title: 'Mulai sewa?',
      message: 'Pesanan ${booking.bookingCode} akan berstatus Sedang Disewa.',
      confirmLabel: 'Mulai Sewa',
    );
    if (!ok) return;
    await _run(
      () => ref.read(adminRepositoryProvider).startBooking(booking.id),
      successMessage: 'Sewa dimulai. Pesanan sedang berjalan.',
    );
  }

  /// Buka form complete; hasil dari server (angka NUMBER) ditampilkan
  /// setelah sukses, lalu detail + daftar + dashboard di-refresh.
  Future<void> _complete(AdminBooking booking) async {
    final result = await showDialog<BookingCompleteResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: _CompleteForm(booking: booking),
        ),
      ),
    );
    if (result == null || !mounted) return;

    refreshAdminData(ref, bookingId: widget.bookingId);
    await _showCompleteResult(result);
  }

  /// Tampilkan hasil hitungan SERVER (`late_days`, `late_fee`,
  /// `damage_fee`, `deposit_refund` — semua NUMBER di level atas respons).
  Future<void> _showCompleteResult(BookingCompleteResult result) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pesanan Selesai'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Biaya berikut dihitung oleh server:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _resultRow('Hari terlambat', '${result.lateDays} hari'),
            const SizedBox(height: 6),
            _resultRow('Denda keterlambatan', formatRupiah(result.lateFee)),
            const SizedBox(height: 6),
            _resultRow('Biaya kerusakan', formatRupiah(result.damageFee)),
            const Divider(height: 20),
            _resultRow(
              'Deposit dikembalikan',
              formatRupiah(result.depositRefund),
              bold: true,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, {bool bold = false}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: bold ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Gambar bukti (diperbesar)
  // ---------------------------------------------------------------------

  void _openProof(String url) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: url,
                  placeholder: (_, __) => const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Gambar tidak bisa dimuat.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(adminBookingDetailProvider(widget.bookingId));

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
                    ref.invalidate(adminBookingDetailProvider(widget.bookingId)),
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

  Widget _content(AdminBooking booking) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _headerCard(booking),
        const SizedBox(height: 16),
        _customerCard(booking),
        if (booking.items.isNotEmpty) ...[
          const SizedBox(height: 16),
          _itemsCard(booking),
        ],
        const SizedBox(height: 16),
        _costCard(booking),
        const SizedBox(height: 16),
        _paymentsCard(booking),
        const SizedBox(height: 20),
        _actionsCard(booking),
      ],
    );
  }

  /// Kode, status, tanggal, catatan, info batas verifikasi.
  Widget _headerCard(AdminBooking booking) {
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
            if (booking.createdAt != null) ...[
              const SizedBox(height: 8),
              _infoRow(
                Icons.schedule_outlined,
                'Dibuat',
                formatDateTime(booking.createdAt),
              ),
            ],
            if (booking.notes != null && booking.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Catatan pelanggan',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(booking.notes!, style: theme.textTheme.bodyMedium),
            ],
            if (booking.status == BookingStatus.cancelled &&
                (booking.cancellationReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              _banner(
                icon: Icons.cancel_outlined,
                background: theme.colorScheme.errorContainer,
                foreground: theme.colorScheme.onErrorContainer,
                title: 'Pesanan dibatalkan',
                message: booking.cancellationReason!,
              ),
            ],
            // Status SELALU ditentukan server; di sini hanya informasi batas.
            if (booking.autoCancelAt != null &&
                (booking.status == BookingStatus.pendingPayment ||
                    booking.status == BookingStatus.pendingVerification)) ...[
              const SizedBox(height: 12),
              _banner(
                icon: Icons.timer_outlined,
                background: theme.colorScheme.surfaceContainerHighest,
                foreground: theme.colorScheme.onSurfaceVariant,
                title: 'Batas waktu pembayaran',
                message: 'Lewat ${formatDateTime(booking.autoCancelAt)}, '
                    'pesanan dibatalkan otomatis oleh server.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _customerCard(AdminBooking booking) {
    final theme = Theme.of(context);

    return DepthCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Pelanggan',
              style:
                  theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.person_outline, 'Nama', booking.userName ?? '-'),
            const SizedBox(height: 8),
            _infoRow(Icons.mail_outline, 'Email', booking.userEmail ?? '-'),
            const SizedBox(height: 8),
            _infoRow(Icons.phone_outlined, 'Telepon', booking.userPhone ?? '-'),
            const SizedBox(height: 8),
            _infoRow(
              Icons.home_outlined,
              'Alamat',
              (booking.userAddress ?? '-'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemsCard(AdminBooking booking) {
    final theme = Theme.of(context);

    return DepthCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alat yang Disewa',
              style:
                  theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            for (final item in booking.items) ...[
              _itemRow(item),
              if (item != booking.items.last) const Divider(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemRow(BookingItem item) {
    final theme = Theme.of(context);
    final imageUrl = resolveImageUrl(item.primaryImageUrl);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 60,
            height: 60,
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
                    placeholder: (_, __) => const ShimmerBox(width: 60, height: 60),
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
    );
  }

  /// Rincian biaya; `late_fee` / `damage_fee` / `deposit_refund` hanya
  /// tampil setelah `completed` (sebelumnya masih 0 / belum dihitung).
  Widget _costCard(AdminBooking booking) {
    final theme = Theme.of(context);
    final completed = booking.isCompleted;

    return DepthCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rincian Biaya',
              style:
                  theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
              _costRow(
                'Deposit dikembalikan',
                formatRupiah(booking.depositRefund),
              ),
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
                // grand_total = STRING dari server (parser aman).
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
              const SizedBox(height: 12),
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
                      'Pengembalian deposit',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dihitung server: baik = deposit − denda; rusak = deposit '
                      '− biaya kerusakan − denda; hilang = Rp 0.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.fact_check_outlined,
                      'Kondisi alat',
                      booking.returnCondition == null
                          ? '-'
                          : returnConditionLabel(booking.returnCondition!),
                    ),
                    if ((booking.returnNotes ?? '').isNotEmpty) ...[
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

  /// Semua pembayaran: status, tanggal, rekening, bukti (ketuk = zoom),
  /// dan alasan penolakan.
  Widget _paymentsCard(AdminBooking booking) {
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
              style:
                  theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
            _paymentBadge(payment),
          ],
        ),
        const SizedBox(height: 6),
        _infoRow(Icons.payments_outlined, 'Jumlah', formatRupiah(payment.amount)),
        const SizedBox(height: 6),
        _infoRow(
          Icons.schedule_outlined,
          'Tanggal',
          formatDateTime(payment.createdAt ?? payment.paymentDate),
        ),
        if ((payment.bankName ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          _infoRow(
            Icons.account_balance_outlined,
            'Rekening',
            '${payment.bankName} • ${payment.accountNumber ?? '-'}',
          ),
        ],
        if ((payment.accountName ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          _infoRow(Icons.badge_outlined, 'Atas nama', payment.accountName!),
        ],
        if (proofUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _openProof(proofUrl),
            borderRadius: BorderRadius.circular(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: proofUrl,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ShimmerBox(
                  width: 96,
                  height: 96,
                  radius: 10,
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 96,
                  height: 96,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ketuk gambar untuk memperbesar',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
        if (payment.isRejected &&
            (payment.rejectionReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          _banner(
            icon: Icons.report_gmailerrorred_outlined,
            background: theme.colorScheme.errorContainer,
            foreground: theme.colorScheme.onErrorContainer,
            title: 'Alasan penolakan',
            message: payment.rejectionReason!,
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Aksi
  // ---------------------------------------------------------------------

  Widget _actionsCard(AdminBooking booking) {
    final theme = Theme.of(context);
    final hasAction =
        booking.canVerify || booking.canStart || booking.canComplete;

    if (!hasAction) {
      return Text(
        'Tidak ada tindakan untuk status ini. Tombol muncul otomatis '
        'saat status pesanan berubah.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (booking.canVerify) ...[
          AppButton(
            label: 'Setujui Pembayaran',
            icon: Icons.check_circle_outline,
            loading: false,
            onPressed: _acting ? null : () => _approve(booking),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Tolak Pembayaran',
            icon: Icons.cancel_outlined,
            danger: true,
            onPressed: _acting ? null : () => _reject(booking),
          ),
        ],
        if (booking.canVerify && (booking.canStart || booking.canComplete))
          const SizedBox(height: 10),
        if (booking.canStart) ...[
          AppButton(
            label: 'Mulai Sewa',
            icon: Icons.play_arrow_outlined,
            onPressed: _acting ? null : () => _start(booking),
          ),
          const SizedBox(height: 10),
        ],
        if (booking.canComplete)
          AppButton(
            label: 'Selesaikan Sewa',
            icon: Icons.flag_outlined,
            onPressed: _acting ? null : () => _complete(booking),
          ),
        if (_acting) ...[
          const SizedBox(height: 12),
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Widget kecil
  // ---------------------------------------------------------------------

  Widget _infoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium,
          ),
        ),
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

  Widget _paymentBadge(Payment payment) {
    final scheme = Theme.of(context).colorScheme;
    final background = payment.isRejected
        ? scheme.errorContainer
        : payment.isApproved
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest;
    final foreground = payment.isRejected
        ? scheme.onErrorContainer
        : payment.isApproved
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        PaymentStatus.label(payment.status ?? ''),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
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
}

// =====================================================================
// Dialog: alasan penolakan (wajib diisi)
// =====================================================================

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog({required this.bookingCode});

  final String bookingCode;

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Alasan penolakan wajib diisi.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Tolak pembayaran?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pesanan ${widget.bookingCode} tetap menunggu verifikasi dan '
            'pelanggan bisa mengunggah ulang bukti pembayaran.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Alasan penolakan (wajib)',
              hintText: 'Contoh: foto bukti buram',
              errorText: _error,
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Tolak'),
        ),
      ],
    );
  }
}

// =====================================================================
// Dialog: form Selesaikan Sewa (PUT /admin/bookings/{id}/complete)
// =====================================================================

class _CompleteForm extends ConsumerStatefulWidget {
  const _CompleteForm({required this.booking});

  final AdminBooking booking;

  @override
  ConsumerState<_CompleteForm> createState() => _CompleteFormState();
}

class _CompleteFormState extends ConsumerState<_CompleteForm> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _damageController = TextEditingController();

  /// `good` | `damaged` | `lost` (default `good`).
  String _condition = 'good';

  late DateTime _returnDate;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _returnDate = _initialReturnDate();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _damageController.dispose();
    super.dispose();
  }

  /// Default hari ini, tapi TIDAK pernah sebelum tanggal ambil.
  DateTime _initialReturnDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pickup = DateTime.tryParse(widget.booking.pickupDate ?? '');
    if (pickup == null) return today;
    return today.isBefore(pickup) ? pickup : today;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickup = DateTime.tryParse(widget.booking.pickupDate ?? '');
    final firstDate = pickup ?? DateTime(now.year - 1, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _returnDate.isBefore(firstDate) ? firstDate : _returnDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (picked == null || !mounted) return;
    setState(() => _returnDate = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final error = validateCompleteInput(
      returnCondition: _condition,
      actualReturnDate: _returnDate,
      pickupDate: DateTime.tryParse(widget.booking.pickupDate ?? '') ??
          _returnDate,
      damageFeeText: _damageController.text,
      returnNotes: _notesController.text,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(adminRepositoryProvider).completeBooking(
            id: widget.booking.id,
            returnCondition: _condition,
            returnNotes: _notesController.text,
            // damage_fee hanya untuk kondisi "rusak" (server memaksa 0
            // untuk kondisi lain).
            damageFee: _condition == 'damaged'
                ? parseDamageFee(_damageController.text)
                : null,
            actualReturnDate: _returnDate,
            // late_days TIDAK pernah dihitung/dikirim dari client.
          );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Gagal menyelesaikan pesanan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Selesaikan Sewa',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              widget.booking.bookingCode,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              'Kondisi alat saat kembali',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                for (final condition in returnConditions)
                  ButtonSegment(
                    value: condition,
                    label: Text(returnConditionLabel(condition)),
                  ),
              ],
              selected: {_condition},
              onSelectionChanged: _submitting
                  ? null
                  : (selection) => setState(() => _condition = selection.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              enabled: !_submitting,
              maxLines: 3,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Catatan kondisi (opsional)',
                hintText: 'Contoh: tenda sobek di sisi kanan',
                alignLabelWithHint: true,
              ),
            ),
            // damage_fee hanya relevan (dan wajib) saat kondisi "Rusak".
            if (_condition == 'damaged') ...[
              TextField(
                controller: _damageController,
                enabled: !_submitting,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Biaya kerusakan (wajib)',
                  hintText: 'Contoh: 150000',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 12),
            ],
            InkWell(
              onTap: _submitting ? null : _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Tanggal kembali sebenarnya',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today_outlined),
                    onPressed: _submitting ? null : _pickDate,
                  ),
                ),
                child: Text(formatDate(_returnDate)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Denda keterlambatan, biaya kerusakan, dan pengembalian '
              'deposit dihitung oleh server.',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: 'Selesaikan',
              icon: Icons.flag_outlined,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );
  }
}
