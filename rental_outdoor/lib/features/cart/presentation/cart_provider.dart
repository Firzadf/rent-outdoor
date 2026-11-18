import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/rental.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../catalog/domain/equipment.dart';
import '../data/cart_storage.dart';
import '../domain/cart_item.dart';

/// Keranjang belanja user yang sedang login (client-side).
///
/// - **autoDispose** + `ref.watch(currentUserIdProvider)`: saat user
///   berganti, provider dibangun ulang dan isi keranjang user baru
///   dibaca dari kunci `cart_v1_{userId}`.
/// - Invalidasi sesi dilakukan di pengamat sesi `routerProvider`
///   (BUKAN dari dalam `AuthController`).
final cartProvider = AsyncNotifierProvider.autoDispose<CartController,
    CartState>(CartController.new);

/// Isi keranjang: item + satu rentang tanggal sewa untuk semua item.
class CartState {
  const CartState({
    this.items = const [],
    this.pickupDate,
    this.returnDate,
  });

  /// Keranjang kosong (belum login / belum ada item).
  static const CartState empty = CartState();

  final List<CartItem> items;

  /// Satu tanggal ambil untuk seluruh keranjang.
  final DateTime? pickupDate;

  /// Satu tanggal kembali untuk seluruh keranjang.
  final DateTime? returnDate;

  bool get isEmpty => items.isEmpty;

  int get totalQuantity =>
      items.fold<int>(0, (sum, item) => sum + item.quantity);

  bool get hasValidRange =>
      pickupDate != null &&
      returnDate != null &&
      isValidRentalRange(pickupDate!, returnDate!);

  /// `null` bila tanggal belum dipilih / belum valid.
  int? get totalDays => hasValidRange
      ? calculateTotalDays(pickupDate!, returnDate!)
      : null;

  /// Estimasi biaya; `null` bila tanggal belum valid.
  CartTotals? get totals =>
      hasValidRange ? computeCartTotals(items, pickupDate!, returnDate!) : null;

  CartItem? itemOf(int equipmentId) {
    for (final item in items) {
      if (item.equipmentId == equipmentId) return item;
    }
    return null;
  }

  CartState copyWith({
    List<CartItem>? items,
    DateTime? pickupDate,
    DateTime? returnDate,
    bool clearRange = false,
  }) =>
      CartState(
        items: items ?? this.items,
        pickupDate: clearRange ? null : pickupDate ?? this.pickupDate,
        returnDate: clearRange ? null : returnDate ?? this.returnDate,
      );
}

class CartController extends AsyncNotifier<CartState> {
  @override
  Future<CartState> build() async {
    // Kunci pengikatan ke sesi: isi keranjang mengikuti user yang login.
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return CartState.empty;

    final record = await ref.read(cartStorageProvider).read(userId);
    return CartState(
      items: record.items,
      pickupDate: record.pickupDate,
      returnDate: record.returnDate,
    );
  }

  /// Tambah alat ke keranjang.
  ///
  /// - Alat nonaktif / stok 0 -> `null` (tidak ditambahkan).
  /// - Sudah ada di keranjang -> jumlahnya DIJUMLAHKAN lalu dibatasi stok.
  ///
  /// Hasil = jumlah baris setelah ditambahkan, atau `null` bila gagal.
  Future<int?> addEquipment(Equipment equipment, int quantity) async {
    final current = state.value;
    if (current == null) return null;
    if (!equipment.isActive || equipment.stock <= 0) return null;

    final existing = current.itemOf(equipment.id);
    final wanted = (existing?.quantity ?? 0) + (quantity < 1 ? 1 : quantity);
    final capped = wanted > equipment.stock ? equipment.stock : wanted;

    final items = [...current.items];
    final index = items.indexWhere((item) => item.equipmentId == equipment.id);
    if (index >= 0) {
      // Tambah jumlah item yang sudah ada + perbarui info harga/stok terbaru.
      items[index] = CartItem.fromEquipment(equipment, capped);
    } else {
      items.add(CartItem.fromEquipment(equipment, capped));
    }

    await _commit(current.copyWith(items: items));
    return capped;
  }

  /// Ubah jumlah satu item — dibatasi 1..stok; di bawah 1 = hapus item.
  Future<void> setQuantity(int equipmentId, int quantity) async {
    final current = state.value;
    if (current == null) return;
    final item = current.itemOf(equipmentId);
    if (item == null) return;

    if (quantity < 1) {
      await removeItem(equipmentId);
      return;
    }

    final capped = quantity > item.stock ? item.stock : quantity;
    final items = [...current.items];
    final index = items.indexWhere((entry) => entry.equipmentId == equipmentId);
    items[index] = item.copyWith(quantity: capped);
    await _commit(current.copyWith(items: items));
  }

  Future<void> removeItem(int equipmentId) async {
    final current = state.value;
    if (current == null) return;
    final items = current.items
        .where((item) => item.equipmentId != equipmentId)
        .toList();
    await _commit(current.copyWith(items: items));
  }

  /// Kosongkan keranjang (kunci storage ikut dihapus).
  Future<void> clearCart() async {
    final userId = ref.read(currentUserIdProvider);
    state = AsyncData(CartState.empty);
    if (userId == null) return;
    try {
      await ref.read(cartStorageProvider).clear(userId);
    } catch (_) {
      // Penyimpanan lokal jarang gagal; state sudah kosong.
    }
  }

  /// Set SATU rentang tanggal untuk seluruh keranjang.
  ///
  /// Aturan server: tanggal lampau ditolak, `return_date` harus setelah
  /// `pickup_date` (minimal 1 malam). Hasil `false` bila tidak valid
  /// (state tidak berubah).
  Future<bool> setRange(DateTime pickupDate, DateTime returnDate) async {
    final current = state.value;
    if (current == null) return false;
    if (!isValidRentalRange(pickupDate, returnDate)) return false;

    await _commit(
      current.copyWith(pickupDate: pickupDate, returnDate: returnDate),
    );
    return true;
  }

  /// Update state lalu simpan ke storage per-user.
  Future<void> _commit(CartState next) async {
    state = AsyncData(next);

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      await ref.read(cartStorageProvider).write(
            userId,
            CartRecord(
              items: next.items,
              pickupDate: next.pickupDate,
              returnDate: next.returnDate,
            ),
          );
    } catch (_) {
      // Penyimpanan lokal jarang gagal; isi layar tetap tampil.
    }
  }
}
