import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/core/router/route_guard.dart';
import 'package:rental_outdoor/features/auth/domain/user.dart';

/// Proteksi peran pada router (`appRedirect` — fungsi murni yang dipakai
/// `routerProvider.redirect`).
///
/// - admin hanya boleh masuk `/admin/*`,
/// - customer yang membuka URL admin diarahkan ke `/home`,
/// - admin tidak bisa masuk rute customer,
/// - belum login -> halaman auth.
void main() {
  const admin = User(
    id: 1,
    email: 'admin@test.com',
    name: 'Admin',
    role: 'admin',
  );
  const customer = User(
    id: 2,
    email: 'customer@test.com',
    name: 'Pelanggan',
    role: 'customer',
  );

  String? redirect({
    User? user,
    bool isLoading = false,
    bool isRefreshing = false,
    bool hasError = false,
    required String location,
  }) =>
      appRedirect(
        isLoading: isLoading,
        isRefreshing: isRefreshing,
        hasError: hasError,
        user: user,
        location: location,
      );

  group('sedang memulihkan sesi / gagal memulihkan', () {
    test('masih loading -> tahan di splash', () {
      expect(redirect(isLoading: true, location: '/home'), '/');
      expect(redirect(isLoading: true, location: '/admin'), '/');
      expect(redirect(isLoading: true, user: admin, location: '/login'), '/');
      expect(redirect(isLoading: true, location: '/'), isNull);
    });

    test('isRefreshing dihitung seperti loading', () {
      expect(redirect(isRefreshing: true, user: admin, location: '/admin'), '/');
      expect(redirect(isRefreshing: true, location: '/'), isNull);
    });

    test('gagal memulihkan sesi -> tahan di splash', () {
      expect(redirect(hasError: true, location: '/login'), '/');
      expect(redirect(hasError: true, location: '/'), isNull);
    });
  });

  group('belum login', () {
    test('rute selain halaman auth -> /login', () {
      expect(redirect(location: '/home'), '/login');
      expect(redirect(location: '/admin'), '/login');
      expect(redirect(location: '/admin/bookings/1'), '/login');
      expect(redirect(location: '/booking/1'), '/login');
    });

    test('halaman auth dibiarkan (kecuali splash -> /login)', () {
      expect(redirect(location: '/login'), isNull);
      expect(redirect(location: '/register'), isNull);
      expect(redirect(location: '/'), '/login');
    });
  });

  group('admin', () {
    test('area /admin dibiarkan (shell + detail + profil)', () {
      expect(redirect(user: admin, location: '/admin'), isNull);
      expect(redirect(user: admin, location: '/admin/bookings'), isNull);
      expect(redirect(user: admin, location: '/admin/bookings/5'), isNull);
      expect(redirect(user: admin, location: '/admin/catalog'), isNull);
      expect(redirect(user: admin, location: '/admin/more'), isNull);
      expect(redirect(user: admin, location: '/admin/profile'), isNull);
    });

    test('rute customer -> dipaksa ke /admin', () {
      expect(redirect(user: admin, location: '/home'), '/admin');
      expect(redirect(user: admin, location: '/catalog'), '/admin');
      expect(redirect(user: admin, location: '/cart'), '/admin');
      expect(redirect(user: admin, location: '/orders'), '/admin');
      expect(redirect(user: admin, location: '/profile'), '/admin');
      expect(redirect(user: admin, location: '/equipment/1'), '/admin');
      expect(redirect(user: admin, location: '/payment/1'), '/admin');
      expect(redirect(user: admin, location: '/booking/1'), '/admin');
    });

    test('halaman login/register -> langsung ke /admin', () {
      expect(redirect(user: admin, location: '/login'), '/admin');
      expect(redirect(user: admin, location: '/register'), '/admin');
      expect(redirect(user: admin, location: '/'), '/admin');
    });
  });

  group('customer', () {
    test('URL admin -> diarahkan ke /home', () {
      expect(redirect(user: customer, location: '/admin'), '/home');
      expect(redirect(user: customer, location: '/admin/bookings'), '/home');
      expect(redirect(user: customer, location: '/admin/bookings/5'), '/home');
      expect(redirect(user: customer, location: '/admin/profile'), '/home');
    });

    test('rute customer dibiarkan', () {
      expect(redirect(user: customer, location: '/home'), isNull);
      expect(redirect(user: customer, location: '/catalog'), isNull);
      expect(redirect(user: customer, location: '/cart'), isNull);
      expect(redirect(user: customer, location: '/orders'), isNull);
      expect(redirect(user: customer, location: '/profile'), isNull);
      expect(redirect(user: customer, location: '/equipment/3'), isNull);
      expect(redirect(user: customer, location: '/equipment/3/reviews'), isNull);
      expect(redirect(user: customer, location: '/checkout'), isNull);
      expect(redirect(user: customer, location: '/payment/4'), isNull);
      expect(redirect(user: customer, location: '/booking/4'), isNull);
    });

    test('rute tidak dikenal -> /home', () {
      expect(redirect(user: customer, location: '/halaman-tidak-ada'), '/home');
    });

    test('halaman login/register -> /home', () {
      expect(redirect(user: customer, location: '/login'), '/home');
      expect(redirect(user: customer, location: '/'), '/home');
    });
  });

  group('daftar rute', () {
    test('customerShellPaths berisi 5 tab customer', () {
      expect(
        customerShellPaths,
        {'/home', '/catalog', '/cart', '/orders', '/profile'},
      );
    });

    test('authPages berisi halaman tanpa login', () {
      expect(authPages, {'/', '/login', '/register'});
    });
  });
}
