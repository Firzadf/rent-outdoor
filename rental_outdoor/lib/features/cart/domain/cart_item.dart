import 'package:flutter/foundation.dart' show immutable;

import '../../../core/utils/formatters.dart';
import '../../../core/utils/parsers.dart';
import '../../../core/utils/rental.dart';
import '../../catalog/domain/equipment.dart';

/// Satu baris keranjang — data CLIENT-SIDE (API_DOCS.md: tidak ada
/// endpoint keranjang di server).
///
/// Angka yang datang dari server (`price_per_day`, `deposit`) dikirim
/// sebagai STRING DECIMAL (API_DOCS.md bagian "Tipe Angka"), jadi parsing
/// selalu lewat parser aman — tidak pernah cast langsung.
@immutable
class CartItem {
  const CartItem({
    required this.equipmentId,
    required this.name,
    required this.quantity,
    required this.pricePerDay,
    this.deposit = 0,
    this.imageUrl,
    this.stock = 0,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        equipmentId: parseInt(json['equipment_id']),
        name: parseString(json['name']) ?? '',
        quantity: parseInt(json['quantity'], fallback: 1),
        pricePerDay: parseDouble(json['price_per_day']),
        deposit: parseDouble(json['deposit']),
        imageUrl: parseString(json['image_url']),
        stock: parseInt(json['stock']),
      );

  /// Bangun baris keranjang dari data alat (halaman detail).
  ///
  /// Foto utama diprioritaskan; bila tidak ada, pakai gambar galeri
  /// pertama (masih URL lengkap dari server).
  factory CartItem.fromEquipment(Equipment equipment, int quantity) =>
      CartItem(
        equipmentId: equipment.id,
        name: equipment.name,
        quantity: quantity,
        pricePerDay: equipment.pricePerDay,
        deposit: equipment.deposit,
        imageUrl: equipment.primaryImageUrl ?? equipment.galleryCover,
        stock: equipment.stock,
      );

  final int equipmentId;
  final String name;

  /// `primary_image_url` (URL lengkap) — bisa `null` bila alat belum
  /// punya gambar.
  final String? imageUrl;

  /// Sewa per hari (DECIMAL string dari server sudah diparse).
  final double pricePerDay;

  /// Deposit per unit (DECIMAL string dari server sudah diparse).
  final double deposit;

  final int quantity;

  /// Stok alat saat ditambahkan — batas maksimum pemilih jumlah.
  final int stock;

  static const Object _unset = Object();

  CartItem copyWith({
    int? quantity,
    int? stock,
    Object? pricePerDay = _unset,
    Object? deposit = _unset,
    Object? imageUrl = _unset,
  }) =>
      CartItem(
        equipmentId: equipmentId,
        name: name,
        quantity: quantity ?? this.quantity,
        pricePerDay: identical(pricePerDay, _unset)
            ? this.pricePerDay
            : parseDouble(pricePerDay),
        deposit: identical(deposit, _unset) ? this.deposit : parseDouble(deposit),
        imageUrl: identical(imageUrl, _unset)
            ? this.imageUrl
            : parseString(imageUrl),
        stock: stock ?? this.stock,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'equipment_id': equipmentId,
        'name': name,
        'image_url': imageUrl,
        'price_per_day': pricePerDay,
        'deposit': deposit,
        'quantity': quantity,
        'stock': stock,
      };

  @override
  bool operator ==(Object other) =>
      other is CartItem &&
      other.equipmentId == equipmentId &&
      other.name == name &&
      other.imageUrl == imageUrl &&
      other.pricePerDay == pricePerDay &&
      other.deposit == deposit &&
      other.quantity == quantity &&
      other.stock == stock;

  @override
  int get hashCode => Object.hash(
        equipmentId,
        name,
        imageUrl,
        pricePerDay,
        deposit,
        quantity,
        stock,
      );
}

/// Isi penyimpanan keranjang satu user: daftar item + SATU rentang tanggal
/// sewa untuk seluruh keranjang.
@immutable
class CartRecord {
  const CartRecord({
    this.items = const [],
    this.pickupDate,
    this.returnDate,
  });

  factory CartRecord.fromJson(Map<String, dynamic> json) => CartRecord(
        items: _items(json['items']),
        pickupDate: DateTime.tryParse(parseString(json['pickup_date']) ?? ''),
        returnDate: DateTime.tryParse(parseString(json['return_date']) ?? ''),
      );

  final List<CartItem> items;
  final DateTime? pickupDate;
  final DateTime? returnDate;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'items': items.map((item) => item.toJson()).toList(),
        'pickup_date':
            pickupDate == null ? null : formatIsoDate(pickupDate!),
        'return_date': returnDate == null ? null : formatIsoDate(returnDate!),
      };

  static List<CartItem> _items(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CartItem.fromJson)
        .toList();
  }
}

/// Estimasi biaya sewa (semua angka dihitung ulang oleh server saat
/// `POST /bookings` — API_DOCS.md bagian "Aturan Hitung").
class CartTotals {
  const CartTotals({
    required this.totalDays,
    required this.subtotal,
    required this.depositTotal,
  });

  /// `return_date - pickup_date`, tanpa +1 (minimal 1 saat valid).
  final int totalDays;

  /// Σ (`price_per_day × quantity × total_days`).
  final double subtotal;

  /// Σ (`deposit × quantity`).
  final double depositTotal;

  /// `subtotal + deposit_total`.
  double get grandTotal => subtotal + depositTotal;
}

/// Hitung estimasi keranjang mengikuti aturan server:
/// `total_days = return - pickup` (TANPA +1), `subtotal` per item =
/// `harga × jumlah × hari`, `deposit_total` = `deposit × jumlah`.
CartTotals computeCartTotals(
  List<CartItem> items,
  DateTime pickupDate,
  DateTime returnDate,
) {
  final totalDays = calculateTotalDays(pickupDate, returnDate);
  var subtotal = 0.0;
  var depositTotal = 0.0;
  for (final item in items) {
    subtotal += item.pricePerDay * item.quantity * totalDays;
    depositTotal += item.deposit * item.quantity;
  }
  return CartTotals(
    totalDays: totalDays,
    subtotal: subtotal,
    depositTotal: depositTotal,
  );
}
