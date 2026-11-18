import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cart_provider.dart';

/// Jumlah item di keranjang user yang sedang login — dipakai badge tab
/// Keranjang pada `NavigationBar` (lib/core/widgets/app_shell.dart).
///
/// Turunan dari [cartProvider] (per-user, autoDispose). Bila belum login
/// atau keranjang kosong -> `0` -> badge disembunyikan.
final cartCountProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(cartProvider).value?.totalQuantity ?? 0,
);
