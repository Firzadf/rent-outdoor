import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'route_guard.dart';
import '../../core/widgets/app_shell.dart';
import '../../features/admin/presentation/admin_booking_detail_page.dart';
import '../../features/admin/presentation/admin_bookings_page.dart';
import '../../features/admin/presentation/admin_catalog_page.dart';
import '../../features/admin/presentation/admin_dashboard_page.dart';
import '../../features/admin/presentation/admin_more_page.dart';
import '../../features/admin/presentation/admin_providers.dart';
import '../../features/admin/presentation/admin_shell_page.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/booking/presentation/booking_detail_page.dart';
import '../../features/booking/presentation/bookings_provider.dart';
import '../../features/booking/presentation/checkout_page.dart';
import '../../features/cart/presentation/cart_page.dart';
import '../../features/cart/presentation/cart_provider.dart';
import '../../features/catalog/presentation/catalog_page.dart';
import '../../features/catalog/presentation/equipment_detail_page.dart';
import '../../features/catalog/presentation/equipment_reviews_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/order/presentation/orders_page.dart';
import '../../features/payment/presentation/payment_page.dart';
import '../../features/payment/presentation/payment_providers.dart';
import '../../features/profile/presentation/profile_controller.dart';
import '../../features/profile/presentation/profile_page.dart';

/// Router utama dengan redirect berdasarkan status login & role
/// (aturan proteksi di [appRedirect], `core/router/route_guard.dart`):
///
/// - belum login -> `/login`
/// - customer    -> shell 5 tab (`/home`, `/catalog`, `/cart`, `/orders`,
///   `/profile`) + halaman detail alat (`/equipment/:id`,
///   `/equipment/:id/reviews`) + checkout (`/checkout`) + pembayaran
///   (`/payment/:id`) + detail pesanan (`/booking/:id`)
/// - admin       -> shell 4 tab (`/admin`, `/admin/bookings`,
///   `/admin/catalog`, `/admin/more`) + detail pesanan admin
///   (`/admin/bookings/:id`) + profil (`/admin/profile`)
final routerProvider = Provider<GoRouter>((ref) {
  // Memberi tahu go_router bahwa auth state berubah -> redirect dijalankan ulang.
  final refresh = ValueNotifier<int>(0);

  // PENGAMAT SESI: setiap perubahan sesi (login, register, logout, 401)
  // -> refresh redirect + BUANG semua data per-user.
  //
  // Invalidation HARUS di sini, bukan di dalam `AuthController`:
  // provider per-user me-watch sesi, jadi mereka adalah DEPENDEN dari
  // `authControllerProvider`. `ref.invalidate` dari dalam `AuthController`
  // melempar `CircularDependencyError` sehingga invalidasi tidak pernah
  // terjalan. Dari `routerProvider` invalidate sah dan selalu terpicu
  // sesudah token ditulis/dihapus + sesi di-set.
  ref.listen(authControllerProvider, (_, __) {
    refresh.value++;
    ref.invalidate(profileProvider);
    // Keranjang adalah data per-user (client-side, kunci `cart_v1_{userId}`)
    // -> dibaca ulang untuk user yang baru login.
    ref.invalidate(cartProvider);
    // Daftar pesanan + filter status juga per-user.
    ref.invalidate(bookingsFilterProvider);
    ref.invalidate(bookingsListProvider);
    // Detail pesanan (dipakai halaman detail + pembayaran) per-user.
    ref.invalidate(bookingDetailProvider);
    // Area admin: dashboard, daftar (filter + pencarian), dan detail
    // pesanan admin juga per-user -> dibuang saat sesi berganti sehingga
    // logout / ganti akun tidak meninggalkan state akun lama.
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(adminBookingsFilterProvider);
    ref.invalidate(adminBookingsSearchProvider);
    ref.invalidate(adminBookingsListProvider);
    ref.invalidate(adminBookingDetailProvider);
    // Area admin Tahap 8B: katalog & kategori admin
    ref.invalidate(adminEquipmentsListProvider);
    ref.invalidate(adminCategoriesListProvider);
    ref.invalidate(adminEquipmentDetailProvider);
  });

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    // Proteksi peran (admin/customer) ada di `appRedirect` — fungsi murni
    // yang diuji oleh test/core/router/route_guard_test.dart.
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      return appRedirect(
        isLoading: auth.isLoading,
        isRefreshing: auth.isRefreshing,
        hasError: auth.hasError,
        user: auth.value,
        location: state.matchedLocation,
      );
    },
    errorBuilder: (context, state) => const _NotFoundPage(),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),

      // -------------------------------------------------------------
      // Shell customer: 5 tab dengan state masing-masing
      // (StatefulShellRoute.indexedStack mempertahankan State per tab).
      // -------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(shell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (context, state) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/catalog',
              builder: (context, state) => const CatalogPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/cart',
              // Key per user id: keranjang tab tidak pernah mempertahankan
              // isi milik akun sebelumnya.
              builder: (context, state) {
                final userId = ref.read(authControllerProvider).value?.id;
                return CartPage(key: ValueKey<String>('cart-$userId'));
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/orders',
              // Key per user id: daftar pesanan tidak pernah
              // mempertahankan data akun sebelumnya.
              builder: (context, state) {
                final userId = ref.read(authControllerProvider).value?.id;
                return OrdersPage(key: ValueKey<String>('orders-$userId'));
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              // Key per user id: tab Profil TIDAK PERNAH mempertahankan
              // State milik akun sebelumnya — ganti akun -> State dibuat
              // ulang.
              builder: (context, state) {
                final userId = ref.read(authControllerProvider).value?.id;
                return ProfilePage(key: ValueKey<String>('profile-$userId'));
              },
            ),
          ]),
        ],
      ),

      // -------------------------------------------------------------
      // Halaman full-screen di atas shell (push/pop).
      // -------------------------------------------------------------
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutPage(),
      ),
      GoRoute(
        path: '/payment/:id',
        // Key per user id + booking id: layar pembayaran tidak pernah
        // mempertahankan data milik akun sebelumnya.
        builder: (context, state) {
          final userId = ref.read(authControllerProvider).value?.id;
          final bookingId =
              int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return PaymentPage(
            key: ValueKey<String>('payment-$userId-$bookingId'),
            bookingId: bookingId,
          );
        },
      ),
      GoRoute(
        path: '/booking/:id',
        // Key per user id + booking id: detail pesanan tidak pernah
        // mempertahankan data milik akun sebelumnya.
        builder: (context, state) {
          final userId = ref.read(authControllerProvider).value?.id;
          final bookingId =
              int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return BookingDetailPage(
            key: ValueKey<String>('booking-$userId-$bookingId'),
            bookingId: bookingId,
          );
        },
      ),
      GoRoute(
        path: '/equipment/:id/reviews',
        builder: (context, state) => EquipmentReviewsPage(
          equipmentId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/equipment/:id',
        builder: (context, state) => EquipmentDetailPage(
          equipmentId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),

      // -------------------------------------------------------------
      // Area admin: shell 4 tab dengan state masing-masing
      // (Dashboard, Pesanan, Katalog, Lainnya).
      // Key per user id: tiap tab tidak pernah mempertahankan state
      // milik akun sebelumnya.
      // -------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdminShell(shell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin',
              builder: (context, state) {
                final userId = ref.read(authControllerProvider).value?.id;
                return AdminDashboardPage(
                  key: ValueKey<String>('admin-dashboard-$userId'),
                );
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/bookings',
              builder: (context, state) {
                final userId = ref.read(authControllerProvider).value?.id;
                return AdminBookingsPage(
                  key: ValueKey<String>('admin-bookings-$userId'),
                );
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/catalog',
              builder: (context, state) {
                final userId = ref.read(authControllerProvider).value?.id;
                return AdminCatalogPage(
                  key: ValueKey<String>('admin-catalog-$userId'),
                );
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/more',
              builder: (context, state) {
                final userId = ref.read(authControllerProvider).value?.id;
                return AdminMorePage(
                  key: ValueKey<String>('admin-more-$userId'),
                );
              },
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/admin/bookings/:id',
        // Key per user id + booking id: detail tidak pernah mempertahankan
        // data milik akun sebelumnya.
        builder: (context, state) {
          final userId = ref.read(authControllerProvider).value?.id;
          final bookingId =
              int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return AdminBookingDetailPage(
            key: ValueKey<String>('admin-booking-$userId-$bookingId'),
            bookingId: bookingId,
          );
        },
      ),
      GoRoute(
        path: '/admin/profile',
        builder: (context, state) {
          final userId = ref.read(authControllerProvider).value?.id;
          return ProfilePage(key: ValueKey<String>('profile-$userId'));
        },
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });

  return router;
});

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tidak ditemukan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_outlined, size: 64),
              const SizedBox(height: 16),
              const Text('Halaman tidak ditemukan.'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Ke Beranda'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
