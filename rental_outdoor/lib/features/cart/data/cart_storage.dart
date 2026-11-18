import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/cart_item.dart';

final cartStorageProvider = Provider<CartStorage>((_) => CartStorage());

/// Penyimpanan keranjang di `shared_preferences` — kunci per user
/// `cart_v1_{userId}` sehingga keranjang akun A tidak pernah terlihat
/// oleh akun B.
///
/// Tidak ada endpoint server untuk keranjang (lihat API_DOCS.md), jadi
/// seluruh isi keranjang hidup di perangkat.
class CartStorage {
  /// Kunci penyimpanan milik satu user.
  static String keyFor(int userId) => 'cart_v1_$userId';

  /// Baca keranjang user; data rusak/kosong -> [CartRecord] kosong
  /// (tidak pernah melempar).
  Future<CartRecord> read(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyFor(userId));
    if (raw == null || raw.trim().isEmpty) return const CartRecord();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const CartRecord();
      return CartRecord.fromJson(decoded);
    } catch (_) {
      // Isi tidak valid JSON -> anggap keranjang kosong.
      return const CartRecord();
    }
  }

  Future<void> write(int userId, CartRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFor(userId), jsonEncode(record.toJson()));
  }

  /// Hapus seluruh isi keranjang user (kunci ikut dibuang).
  Future<void> clear(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyFor(userId));
  }
}
