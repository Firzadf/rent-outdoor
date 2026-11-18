import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/presentation/cart_count_provider.dart';

/// Kerangka utama customer: isi tab + [NavigationBar] 5 tab
/// (beranda, katalog, keranjang, pesanan, profil).
///
/// Dipakai oleh `StatefulShellRoute.indexedStack` di
/// `core/router/app_router.dart` — tiap tab punya navigator sendiri
/// sehingga state per tab (posisi scroll, isi form, hasil pencarian)
/// tetap hidup saat berpindah tab.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  /// Navigasi cabang dari go_router (ganti tab lewat `goBranch`).
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront),
            label: 'Katalog',
          ),
          NavigationDestination(
            icon: _badged(Icons.shopping_cart_outlined, cartCount),
            selectedIcon: _badged(Icons.shopping_cart, cartCount),
            label: 'Keranjang',
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: 'Pesanan',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  /// Ikon dengan badge jumlah item (badge disembunyikan bila `0`).
  Widget _badged(IconData icon, int count) {
    if (count <= 0) return Icon(icon);
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(icon),
    );
  }
}
