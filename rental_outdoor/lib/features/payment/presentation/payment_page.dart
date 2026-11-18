import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../booking/domain/booking.dart';
import '../../booking/presentation/bookings_provider.dart';
import '../data/payment_repository.dart';
import '../domain/payment.dart';
import '../domain/payment_info.dart';
import 'payment_providers.dart';

/// Layar pembayaran satu booking: kode booking, total dari server
/// (`grand_total`), batas bayar (`auto_cancel_at`) dengan hitung mundur,
/// rekening tujuan (`GET /payments/info`), dan form unggah bukti
/// (`POST /payments`).
class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key, required this.bookingId});

  final int bookingId;

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _bankController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();

  XFile? _proofFile;

  /// Mencegah double tap saat mengirim bukti.
  bool _submitting = false;

  /// Sisa waktu bayar — diperbarui tiap detik TANPA membangun ulang
  /// seluruh halaman (hanya [ValueListenableBuilder]).
  final ValueNotifier<Duration?> _remaining = ValueNotifier<Duration?>(null);
  Timer? _timer;

  /// Booking terakhir yang tampil (dipakai penghitung mundur).
  Booking? _booking;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remaining.dispose();
    _bankController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  void _tick() {
    final deadline = _booking?.autoCancelAtDate;
    if (deadline == null) {
      if (_remaining.value != null) _remaining.value = null;
      return;
    }
    final diff = deadline.difference(DateTime.now());
    final remaining = diff.isNegative ? Duration.zero : diff;
    final crossedZero = remaining == Duration.zero &&
        (_remaining.value == null || _remaining.value! > Duration.zero);
    _remaining.value = remaining;
    // Tepat saat waktu habis: bangun ulang supaya form dinonaktifkan dan
    // pesan "batas waktu lewat" muncul tanpa perlu refresh manual.
    if (crossedZero && mounted) setState(() {});
  }

  bool _isExpired(Booking booking) {
    final deadline = booking.autoCancelAtDate;
    return deadline != null && DateTime.now().isAfter(deadline);
  }

  String _formatCountdown(Duration value) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _copyAccountNumber(String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (!mounted) return;
    _showMessage('Nomor rekening $number disalin.');
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(bookingDetailProvider(widget.bookingId));
    ref.invalidate(paymentInfoProvider);
    try {
      await ref.read(bookingDetailProvider(widget.bookingId).future);
    } catch (_) {
      // Error sudah tersimpan di state provider.
    }
  }

  // ---------------------------------------------------------------------
  // Bukti bayar
  // ---------------------------------------------------------------------

  Future<void> _pickProof() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    // Validasi MIME + ukuran dilakukan helper saat submit.
    if (!mounted) return;
    setState(() {
      _proofFile = file;
    });
  }

  void _removeProof() {
    setState(() {
      _proofFile = null;
    });
  }

  Future<void> _submit(Booking booking) async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final file = _proofFile;
    if (file == null) {
      _showMessage('Pilih foto bukti pembayaran terlebih dahulu.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(paymentRepositoryProvider).submitPayment(
            bookingId: booking.id,
            bankName: _bankController.text,
            accountName: _accountNameController.text,
            accountNumber: _accountNumberController.text,
            proofFile: file,
          );
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pembayaran Terkirim'),
          content: const Text(
            'Bukti pembayaran terkirim, menunggu verifikasi admin.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      // Daftar pesanan harus ter-refresh otomatis setelah pembayaran
      // berhasil (tab Pesanan bisa saja masih hidup di dalam shell).
      ref.invalidate(bookingsListProvider);
      // Arahkan customer ke tab Pesanan.
      context.go('/orders');
    } on ApiException catch (e) {
      // 400/404: pesan server (stok status salah, lewat batas, file invalid).
      _showMessage(e.message);
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
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
        title: const Text('Pembayaran'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(ref),
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
          data: (booking) {
            _booking = booking; // sumber hitung mundur
            final infoAsync = ref.watch(paymentInfoProvider);

            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: infoAsync.when(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: false,
                loading: () => const LoadingView(
                  message: 'Memuat rekening tujuan...',
                ),
                error: (error, _) => _scrollable(
                  ErrorView(
                    message: friendlyErrorMessage(error),
                    onRetry: () => ref.invalidate(paymentInfoProvider),
                  ),
                ),
                data: (accounts) => _buildContent(booking, accounts),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(Booking booking, List<PaymentBankAccount> accounts) {
    final expired = _isExpired(booking);
    final rejected = booking.lastPayment?.isRejected ?? false;
    // Form aktif hanya: pending_payment, atau pending_verification dengan
    // pembayaran terakhir ditolak (boleh unggah ulang) — dan belum lewat
    // batas waktu.
    final canPay = booking.canSubmitPayment && !expired;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _statusCard(context, booking, expired),
        const SizedBox(height: 16),
        _bankCard(context, accounts),
        const SizedBox(height: 16),
        if (rejected && booking.lastPayment != null) ...[
          _rejectionBox(context, booking.lastPayment!),
          const SizedBox(height: 16),
        ],
        if (canPay)
          _formCard(context, booking)
        else
          _statusOnlyCard(context, booking, expired),
      ],
    );
  }

  /// Kode booking + status + total dari server + batas bayar.
  Widget _statusCard(BuildContext context, Booking booking, bool expired) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.bookingCode.isEmpty
                        ? 'Kode booking'
                        : booking.bookingCode,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      BookingStatus.label(booking.status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Total yang harus dibayar',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(
              // SUMBER SERVER (grand_total) — bukan hasil hitungan client.
              formatRupiah(booking.grandTotal),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  expired ? Icons.timer_off_outlined : Icons.timer_outlined,
                  size: 20,
                  color: expired
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    booking.autoCancelAt == null
                        ? 'Batas bayar tidak diketahui.'
                        : 'Batas bayar: '
                            '${formatDateTime(booking.autoCancelAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: expired
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (!expired && booking.autoCancelAt != null) ...[
              const SizedBox(height: 6),
              ValueListenableBuilder<Duration?>(
                valueListenable: _remaining,
                builder: (context, remaining, _) => Text(
                  remaining == null
                      ? 'Menghitung sisa waktu...'
                      : 'Sisa waktu: ${_formatCountdown(remaining)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (expired) ...[
              const SizedBox(height: 6),
              Text(
                'Batas waktu pembayaran sudah lewat. Pesanan ini akan '
                'dibatalkan otomatis oleh server.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Rekening tujuan + tombol salin nomor rekening.
  Widget _bankCard(BuildContext context, List<PaymentBankAccount> accounts) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rekening Tujuan',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Transfer sesuai total di atas, lalu unggah bukti transfer.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (accounts.isEmpty)
              Text(
                'Daftar rekening belum tersedia. Muat ulang halaman.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final account in accounts) ...[
                _bankRow(context, account),
                if (account != accounts.last) const Divider(height: 16),
              ],
          ],
        ),
      ),
    );
  }

  Widget _bankRow(BuildContext context, PaymentBankAccount account) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.bankName,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                account.accountNumber,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                account.accountName,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Salin nomor rekening',
          icon: const Icon(Icons.copy_rounded),
          onPressed: () => _copyAccountNumber(account.accountNumber),
        ),
      ],
    );
  }

  /// Alasan penolakan verifikasi terakhir + bukti yang ditolak.
  Widget _rejectionBox(BuildContext context, Payment payment) {
    final theme = Theme.of(context);
    final proofUrl = resolveImageUrl(payment.paymentProof);

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
              Icon(Icons.cancel_outlined, color: theme.colorScheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bukti pembayaran ditolak',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            payment.rejectionReason ?? 'Tidak ada keterangan.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onErrorContainer),
          ),
          if (proofUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: proofUrl,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox(
                  width: 96,
                  height: 96,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => const SizedBox(
                  width: 96,
                  height: 96,
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Silakan unggah bukti transfer yang baru di bawah ini.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onErrorContainer),
          ),
        ],
      ),
    );
  }

  /// Hanya status (tanpa form) bila booking tidak bisa dibayar lagi.
  Widget _statusOnlyCard(BuildContext context, Booking booking, bool expired) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status Pesanan',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              expired
                  ? 'Batas waktu pembayaran sudah lewat — tunggu pembaruan '
                      'status dari server.'
                  : 'Pembayaran untuk pesanan ini tidak perlu diunggah '
                      'lagi. Status saat ini: '
                      '${BookingStatus.label(booking.status)}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _refresh(ref),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Perbarui Status'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formCard(BuildContext context, Booking booking) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bukti Pembayaran',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bankController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Bank yang Anda pakai',
                  hintText: 'Contoh: BCA',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Nama bank wajib diisi.';
                  if (text.length < 3) return 'Nama bank minimal 3 huruf.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accountNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama pemilik rekening',
                  hintText: 'Contoh: Budi Santoso',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Nama pemilik rekening wajib diisi.';
                  if (text.length < 3) return 'Minimal 3 huruf.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nomor rekening Anda',
                  hintText: 'Contoh: 1234567890',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Nomor rekening wajib diisi.';
                  if (text.length < 5) return 'Nomor rekening minimal 5 digit.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _proofPicker(context),
              const SizedBox(height: 16),
              AppButton(
                label: 'Kirim Bukti Pembayaran',
                icon: Icons.upload_file_outlined,
                loading: _submitting,
                onPressed: _submitting ? null : () => _submit(booking),
              ),
              const SizedBox(height: 8),
              Text(
                'Format JPG/PNG/WEBP, maksimal 5 MB.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pemilih foto bukti + pratinjau.
  Widget _proofPicker(BuildContext context) {
    final theme = Theme.of(context);
    final file = _proofFile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto bukti transfer',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (file == null)
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pickProof,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Pilih Foto'),
          )
        else
          _ProofPreview(
            file: file,
            onPick: _pickProof,
            onRemove: _removeProof,
            enabled: !_submitting,
          ),
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

/// Pratinjau foto bukti.
class _ProofPreview extends StatelessWidget {
  const _ProofPreview({
    required this.file,
    required this.onPick,
    required this.onRemove,
    required this.enabled,
  });

  final XFile file;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return OutlinedButton.icon(
            onPressed: enabled ? onPick : null,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Memuat...'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                bytes,
                width: 160,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: enabled ? onPick : null,
                  child: const Text('Ganti'),
                ),
                IconButton(
                  tooltip: 'Hapus foto',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: enabled ? onRemove : null,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
