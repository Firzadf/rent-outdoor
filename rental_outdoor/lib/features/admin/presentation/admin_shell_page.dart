import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Kerangka area admin: isi tab + [NavigationBar] 4 tab
/// (Dashboard, Pesanan, Katalog, Lainnya).
///
/// Dipakai oleh `StatefulShellRoute.indexedStack` di
/// `core/router/app_router.dart` — tiap tab punya navigator sendiri
/// sehingga state per tab (posisi scroll, hasil pencarian, filter)
/// tetap hidup saat berpindah tab.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.shell});

  /// Navigasi cabang go_router (ganti tab lewat `goBranch`).
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pesanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Katalog',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_outlined),
            selectedIcon: Icon(Icons.menu),
            label: 'Lainnya',
          ),
        ],
      ),
    );
  }
}
