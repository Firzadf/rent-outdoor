import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_upload.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/utils/rental.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/rating_stars.dart';
import '../data/catalog_repository.dart';
import '../../cart/presentation/cart_provider.dart';
import '../domain/availability.dart';
import '../domain/equipment.dart';
import '../domain/review.dart';
import 'equipment_detail_provider.dart';

/// Detail alat `GET /equipments/{id}`: galeri, info, cek ketersediaan,
/// dan ulasan terbaru.
class EquipmentDetailPage extends ConsumerStatefulWidget {
  const EquipmentDetailPage({super.key, required this.equipmentId});

  final int equipmentId;

  @override
  ConsumerState<EquipmentDetailPage> createState() =>
      _EquipmentDetailPageState();
}

class _EquipmentDetailPageState extends ConsumerState<EquipmentDetailPage> {
  final PageController _pageController = PageController();
  int _currentImage = 0;

  // Cek ketersediaan (state lokal halaman, bukan data per-user).
  DateTimeRange? _range;
  bool _checking = false;
  AvailabilityResult? _availability;
  String? _availabilityError;
  int _quantity = 1;

  // Mencegah double tap pada "Tambah ke Keranjang".
  bool _addingToCart = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Galeri
  // ---------------------------------------------------------------------

  /// URL gambar galeri; bila `images[]` kosong, pakai foto utama.
  ///
  /// `updated_at` dipakai sebagai versi cache supaya gambar baru langsung
  /// tampil setelah admin upload/hapus foto.
  List<String> _galleryUrls(Equipment detail) {
    final version = detail.updatedAt;
    final urls = detail.images
        .map((image) => image.imageUrl)
        .where((url) => url.isNotEmpty)
        .map((url) => bustCache(url, version: version))
        .toList();
    if (urls.isNotEmpty) return urls;
    final cover = detail.primaryImageUrl;
    if (cover == null || cover.isEmpty) return const [];
    return [bustCache(cover, version: version)];
  }

  // ---------------------------------------------------------------------
  // Cek ketersediaan
  // ---------------------------------------------------------------------

  /// Pilih tanggal (showDateRangePicker) lalu langsung cek ke server.
  Future<void> _pickDatesAndCheck() async {
    if (_checking) return;

    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      // Maksimal setahun ke depan (batas wajar pemesanan).
      lastDate: firstDate.add(const Duration(days: 365)),
      initialDateRange: _range,
      helpText: 'PILIH TANGGAL SEWA',
      confirmText: 'PILIH',
      cancelText: 'BATAL',
    );
    if (picked == null || !mounted) return;

    // Aturan server: total_days = return - pickup, tanpa +1, minimal 1.
    if (!isValidRentalRange(picked.start, picked.end)) {
      _showMessage(
        'Tanggal sewa minimal 1 malam — tanggal kembali harus setelah '
        'tanggal ambil.',
      );
      return;
    }

    setState(() => _range = picked);
    await _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final range = _range;
    if (range == null || _checking) return;

    setState(() {
      _checking = true;
      _availabilityError = null;
    });

    try {
      final result = await ref.read(catalogRepositoryProvider).getAvailability(
            equipmentId: widget.equipmentId,
            pickupDate: range.start,
            returnDate: range.end,
          );
      if (!mounted) return;
      setState(() {
        _availability = result;
        _quantity = 1; // batas jumlah mengikuti hasil terbaru
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _availability = null;
        _availabilityError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _availability = null;
        _availabilityError = friendlyErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(equipmentDetailProvider(widget.equipmentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Alat')),
      body: detail.when(
        // Saat refresh, data lama tetap tampil agar RefreshIndicator
        // tidak kehilangan child-nya.
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(message: 'Memuat detail alat...'),
        error: (error, _) => ErrorView(
          message: friendlyErrorMessage(error),
          onRetry: () =>
              ref.invalidate(equipmentDetailProvider(widget.equipmentId)),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: _refreshDetail,
          child: _buildDetail(data),
        ),
      ),
    );
  }

  Future<void> _refreshDetail() async {
    ref.invalidate(equipmentDetailProvider(widget.equipmentId));
    try {
      await ref.read(equipmentDetailProvider(widget.equipmentId).future);
    } catch (_) {
      // Error sudah tampil di state provider.
    }
  }

  Widget _buildDetail(Equipment detail) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _buildGallery(detail),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Nama, kategori, rating ----
              Text(
                detail.name,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (detail.categoryName != null)
                    Chip(
                      label: Text(detail.categoryName!),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                      backgroundColor:
                          theme.colorScheme.secondaryContainer,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  RatingStars(
                    rating: detail.ratingAvg,
                    size: 18,
                    showValue: detail.totalReviews > 0,
                    totalReviews:
                        detail.totalReviews > 0 ? detail.totalReviews : null,
                  ),
                  if (detail.totalReviews == 0)
                    Text(
                      'Belum ada ulasan',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // ---- Harga / deposit / stok ----
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _infoRow(
                        icon: Icons.payments_outlined,
                        label: 'Harga sewa',
                        value: '${formatRupiah(detail.pricePerDay)}/hari',
                        highlight: true,
                      ),
                      const Divider(height: 24),
                      _infoRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Deposit',
                        value: formatRupiah(detail.deposit),
                      ),
                      const Divider(height: 24),
                      _infoRow(
                        icon: Icons.inventory_2_outlined,
                        label: 'Stok',
                        value: '${detail.stock} unit',
                      ),
                    ],
                  ),
                ),
              ),

              // ---- Deskripsi ----
              if (detail.description != null &&
                  detail.description!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Deskripsi',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  detail.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],

              const SizedBox(height: 20),
              _buildAvailabilitySection(),

              const SizedBox(height: 20),
              _buildAddToCart(detail),

              const SizedBox(height: 24),
              _buildReviewsSection(detail),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGallery(Equipment detail) {
    final theme = Theme.of(context);
    final urls = _galleryUrls(detail);

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: urls.isEmpty
          ? ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: urls.length,
                  onPageChanged: (index) =>
                      setState(() => _currentImage = index),
                  itemBuilder: (_, index) => CachedNetworkImage(
                    imageUrl: resolveImageUrl(urls[index]),
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                    errorWidget: (_, __, ___) => ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ),
                if (urls.length > 1)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_currentImage + 1}/${urls.length}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: highlight
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (highlight
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleSmall)
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: highlight ? theme.colorScheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Bagian "Cek Ketersediaan": pilih tanggal -> GET availability ->
  /// tampilkan `available_stock` + `is_available` -> pemilih jumlah.
  Widget _buildAvailabilitySection() {
    final theme = Theme.of(context);
    final range = _range;
    final available = _availability;

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
                  'Cek Ketersediaan',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (range != null) ...[
              Text(
                '${formatDate(range.start)} - ${formatDate(range.end)}'
                '  •  ${calculateTotalDays(range.start, range.end)} hari',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
            ],
            AppButton(
              label: range == null ? 'Pilih Tanggal Sewa' : 'Ganti Tanggal',
              icon: Icons.calendar_month,
              loading: _checking,
              onPressed: _pickDatesAndCheck,
            ),
            const SizedBox(height: 12),

            if (range == null)
              Text(
                'Pilih tanggal sewa untuk melihat stok yang tersedia.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),

            if (_checking)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Mengecek ketersediaan...',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),

            if (!_checking && _availabilityError != null) ...[
              Text(
                _availabilityError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: _checkAvailability,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Coba Lagi'),
                ),
              ),
            ],

            if (!_checking && available != null) ...[
              _availabilityBox(available),
              const SizedBox(height: 16),
              _quantityPicker(available),
            ],
          ],
        ),
      ),
    );
  }

  /// Hasil `available_stock` + `is_available`.
  Widget _availabilityBox(AvailabilityResult available) {
    final theme = Theme.of(context);
    final rentable = available.rentable;

    final Color background;
    final Color foreground;
    if (rentable) {
      background = theme.colorScheme.tertiaryContainer;
      foreground = theme.colorScheme.onTertiaryContainer;
    } else {
      background = theme.colorScheme.errorContainer;
      foreground = theme.colorScheme.onErrorContainer;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            rentable ? Icons.check_circle : Icons.cancel,
            color: foreground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rentable
                      ? 'Tersedia — ${available.availableStock} unit bisa disewa'
                      : 'Tidak tersedia pada tanggal ini',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stok: ${available.stock} • Dipesan: ${available.booked} • '
                  'Tersedia: ${available.availableStock}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pemilih jumlah — dibatasi `available_stock` setelah dicek.
  Widget _quantityPicker(AvailabilityResult available) {
    final theme = Theme.of(context);
    final canOrder = available.rentable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jumlah',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              tooltip: 'Kurangi',
              onPressed:
                  canOrder && _quantity > 1 ? () => setState(() => _quantity--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_quantity',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Tambah',
              onPressed: canOrder && _quantity < available.availableStock
                  ? () => setState(() => _quantity++)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                canOrder
                    ? 'Maksimal ${available.availableStock} unit untuk '
                        'tanggal ini.'
                    : 'Jumlah bisa dipilih setelah tersedia.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Tombol "Tambah ke Keranjang" — menyimpan alat ke keranjang lokal
  /// (client-side). Jumlah yang dipilih di atas ikut ditambahkan bila
  /// alat sudah ada di keranjang, dibatasi stok.
  Widget _buildAddToCart(Equipment detail) {
    final theme = Theme.of(context);
    final outOfStock = detail.stock <= 0 || !detail.isActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: _quantity > 1
              ? 'Tambah $_quantity ke Keranjang'
              : 'Tambah ke Keranjang',
          icon: Icons.add_shopping_cart_outlined,
          loading: _addingToCart,
          onPressed: outOfStock ? null : () => _addToCart(detail),
        ),
        const SizedBox(height: 8),
        Text(
          outOfStock
              ? 'Alat sedang tidak tersedia.'
              : 'Tanggal sewa dan pembayaran dipilih di tab Keranjang.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// Simpan ke keranjang: bila alat sudah ada, jumlahnya dijumlahkan lalu
  /// dibatasi stok.
  Future<void> _addToCart(Equipment detail) async {
    if (_addingToCart) return;
    setState(() => _addingToCart = true);

    try {
      final added = await ref
          .read(cartProvider.notifier)
          .addEquipment(detail, _quantity);
      if (!mounted) return;

      if (added == null) {
        _showMessage('Alat tidak bisa ditambahkan ke keranjang.');
        return;
      }
      _showMessage(
        added < _quantity
            ? 'Ditambahkan ke keranjang (maksimal $added unit sesuai stok).'
            : 'Ditambahkan ke keranjang.',
      );
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  /// Ulasan terbaru (maks. 5 dari `GET /equipments/{id}`) + tombol
  /// "Lihat semua ulasan" (halaman terpisah dengan paginasi).
  Widget _buildReviewsSection(Equipment detail) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Ulasan Terbaru',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (detail.totalReviews > 0)
              TextButton(
                onPressed: () => context
                    .push('/equipment/${widget.equipmentId}/reviews'),
                child: const Text('Lihat semua ulasan'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (detail.reviews.isEmpty)
          Text(
            'Belum ada ulasan untuk alat ini.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          for (final review in detail.reviews) _reviewCard(review),
      ],
    );
  }

  Widget _reviewCard(Review review) {
    final theme = Theme.of(context);
    final url = resolveImageUrl(review.profileImage);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: url.isEmpty
                  ? Text(
                      review.initials,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        // Gambar gagal -> inisial.
                        errorWidget: (_, __, ___) => SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: Text(
                              review.initials,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          review.userName ?? 'Pengguna',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      RatingStars(rating: review.rating.toDouble(), size: 15),
                    ],
                  ),
                  if (review.comment != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      review.comment!,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    formatDate(review.createdAt),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
