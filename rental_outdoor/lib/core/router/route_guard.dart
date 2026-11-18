import '../../features/auth/domain/user.dart';

/// Lokasi tab pada `StatefulShellRoute` area customer.
const Set<String> customerShellPaths = {
  '/home',
  '/catalog',
  '/cart',
  '/orders',
  '/profile',
};

/// Halaman yang boleh dibuka tanpa login.
const Set<String> authPages = {'/', '/login', '/register'};

/// Menentukan redirect router dari sesi + lokasi yang diminta.
///
/// Fungsi MURNI (tanpa GoRouter) supaya aturan proteksi peran bisa diuji
/// tanpa jaringan. Aturan:
/// - masih memulihkan sesi / gagal memulihkan -> tahan di splash (`/`),
/// - belum login -> hanya halaman auth (`/`, `/login`, `/register`),
/// - admin -> hanya area `/admin/*` (customer area ditolak),
/// - customer -> area `/admin/*` diarahkan ke `/home`,
/// - selain itu ikut daftar rute customer yang diizinkan.
String? appRedirect({
  required bool isLoading,
  required bool isRefreshing,
  required bool hasError,
  required User? user,
  required String location,
}) {
  // Masih memulihkan sesi dari token -> tahan di splash.
  if (isLoading || isRefreshing) {
    return location == '/' ? null : '/';
  }
  // Gagal memulihkan sesi (mis. server mati) -> splash menampilkan
  // error + tombol coba lagi.
  if (hasError) {
    return location == '/' ? null : '/';
  }

  // Belum login: hanya halaman auth yang boleh.
  if (user == null) {
    if (!authPages.contains(location)) return '/login';
    return location == '/' ? '/login' : null;
  }

  // Sudah login: halaman auth diarahkan ke halaman utama role-nya.
  if (authPages.contains(location)) {
    return user.isAdmin ? '/admin' : '/home';
  }

  // Admin: hanya area /admin (shell 4 tab + detail pesanan + profil admin).
  if (user.isAdmin) {
    return location.startsWith('/admin') ? null : '/admin';
  }

  // Customer: jangan masuk area admin.
  if (location.startsWith('/admin')) return '/home';

  // Tab shell + detail/ulasan alat + checkout + pembayaran + detail
  // pesanan diizinkan; selain itu ke Beranda.
  if (customerShellPaths.contains(location) ||
      location.startsWith('/equipment/') ||
      location == '/checkout' ||
      location.startsWith('/payment/') ||
      location.startsWith('/booking/')) {
    return null;
  }
  return '/home';
}
