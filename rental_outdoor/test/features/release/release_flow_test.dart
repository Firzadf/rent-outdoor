import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rental_outdoor/app.dart';
import 'package:rental_outdoor/core/network/api_client.dart';
import 'package:rental_outdoor/core/network/api_providers.dart';
import 'package:rental_outdoor/core/network/app_retry.dart';
import 'package:rental_outdoor/core/router/app_router.dart';
import 'package:rental_outdoor/core/storage/token_storage.dart';
import 'package:rental_outdoor/core/widgets/error_view.dart';
import 'package:rental_outdoor/core/widgets/loading_view.dart';
import 'package:rental_outdoor/features/cart/presentation/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tes alur utama rilis - TANPA jaringan:
/// adapter dio palsu menjawab semua endpoint, token dipegang memori.
///
/// Semua alur dijalankan di 360x800, 620x800, dan 1200x800 dengan harapan
/// `tester.takeException()` null (tidak ada overflow / constraint error).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  const sizes = <String, Size>{
    '360x800': Size(360, 800),
    '620x800': Size(620, 800),
    '1200x800': Size(1200, 800),
  };

  sizes.forEach((label, size) {
    testWidgets('login customer -> beranda [$label]', (tester) async {
      final api = await _pumpApp(tester, size);

      await _login(tester, email: 'customer@test.com');

      expect(find.text('Beranda'), findsWidgets);
      expect(find.textContaining('Hai,'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'overflow di $label');
      expect(api.hasRequest('/auth/login'), isTrue);
    });

    testWidgets('tambah keranjang -> checkout [$label]', (tester) async {
      final api = await _pumpApp(tester, size);

      await _login(tester, email: 'customer@test.com');

      // Buka Katalog lalu detail alat.
      await tester.tap(find.text('Katalog'));
      await tester.pumpAndSettle();
      expect(find.text('Tenda Kapasitas 4 Orang'), findsOneWidget);

      await tester.tap(find.text('Tenda Kapasitas 4 Orang'));
      await tester.pumpAndSettle();
      // Galeri 16:10 di 1200x800 menutupi layar; gulir agar detail terbangun.
      if (size.width >= 1000) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      expect(find.text('Detail Alat'), findsOneWidget);
      expect(
        api.hasRequest('/equipments/1'),
        isTrue,
        reason: 'request detail: ${api.requests.map((r) => r.path).toList()}',
      );
      expect(find.byType(LoadingView), findsNothing, reason: 'masih loading');
      expect(find.byType(ErrorView), findsNothing, reason: 'body error');
      expect(find.text('Tenda Kapasitas 4 Orang'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsNothing);
      expect(tester.takeException(), isNull, reason: 'overflow detail alat');

      // Tambah ke keranjang (tombol ada di bawah - pastikan terlihat).
      await _scrollTo(tester, find.text('Tambah ke Keranjang'));
      await tester.tap(find.text('Tambah ke Keranjang'));
      await tester.pumpAndSettle();
      expect(find.text('Ditambahkan ke keranjang.'), findsOneWidget);
      // Tunggu SnackBar hilang supaya tidak menutupi tombol di layar kecil.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Kembali ke shell lalu buka tab Keranjang.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keranjang'));
      await tester.pumpAndSettle();
      expect(find.text('Tenda Kapasitas 4 Orang'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'overflow keranjang');

      // Pilih rentang tanggal sewa lewat notifier (state client-side).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      final today = DateTime.now();
      final ok = await container.read(cartProvider.notifier).setRange(
            DateTime(today.year, today.month, today.day + 1),
            DateTime(today.year, today.month, today.day + 3),
          );
      expect(ok, isTrue);
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Lanjut ke Checkout'));
      await tester.tap(find.text('Lanjut ke Checkout'));
      await tester.pumpAndSettle();
      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Item Sewa'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'overflow checkout');

      // Buat pesanan (stok dicek dulu ke server palsu).
      await _scrollTo(tester, find.text('Buat Pesanan'));
      await tester.tap(find.text('Buat Pesanan'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(api.posted('/bookings'), isTrue);
      // Berhasil -> halaman pembayaran terbuka (ada Timer 1 dtk, jadi
      // jangan pakai pumpAndSettle).
      expect(find.text('Pembayaran'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'overflow pembayaran');
    });

    testWidgets('login admin -> dashboard [$label]', (tester) async {
      final api = await _pumpApp(tester, size);

      await _login(tester, email: 'admin@test.com');

      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Total Pesanan'), findsOneWidget);
      expect(find.text('Ringkasan'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'overflow dashboard admin');
      expect(api.hasRequest('/admin/dashboard'), isTrue);
    });

    testWidgets('customer ditolak masuk /admin [$label]', (tester) async {
      await _pumpApp(tester, size);
      await _login(tester, email: 'customer@test.com');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      container.read(routerProvider).go('/admin');
      await tester.pumpAndSettle();

      final location =
          container.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();
      expect(location, '/home', reason: 'customer harus dibuang ke /home');
      expect(find.text('Beranda'), findsWidgets);
      expect(find.text('Ringkasan'), findsNothing);
      expect(tester.takeException(), isNull, reason: 'overflow di $label');
    });
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Pump aplikasi penuh (MaterialApp.router + go_router) dengan adapter
/// dio palsu + token storage memori. Mengembalikan adapter-nya.
Future<_FakeApi> _pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final tokenStorage = _MemoryTokenStorage();
  final api = _FakeApi();
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost/outdoorrent/api',
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
  dio.httpClientAdapter = api;

  final client = ApiClient(tokenStorage: tokenStorage, client: dio);
  addTearDown(client.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: appRetry,
      overrides: [
        tokenStorageProvider.overrideWithValue(tokenStorage),
        apiClientProvider.overrideWithValue(client),
      ],
      child: const RentalOutdoorApp(),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Future<void> _login(WidgetTester tester, {required String email}) async {
  expect(find.byType(TextFormField), findsNWidgets(2));
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), 'password123');
  await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
  await tester.pumpAndSettle();
}

/// Gulir daftar utama sampai target (dibangun) terlihat.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.dragUntilVisible(
    target,
    find.byType(ListView).first,
    const Offset(0, -300),
  );
  await tester.pumpAndSettle();
}

/// Token storage memori (menggantikan flutter_secure_storage di tes).
class _MemoryTokenStorage extends TokenStorage {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> delete() async => token = null;
}

/// Adapter dio palsu: semua endpoint dibalas dari fixture in-memory,
/// tanpa jaringan sama sekali.
class _FakeApi implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  bool hasRequest(String path) => requests.any((r) => r.path == path);

  bool posted(String path) =>
      requests.any((r) => r.path == path && r.method == 'POST');

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.path;
    final method = options.method;

    if (path == '/auth/login' && method == 'POST') {
      final body = options.data is Map<String, dynamic>
          ? options.data as Map<String, dynamic>
          : const <String, dynamic>{};
      final email = '${body['email']}';
      final admin = email.startsWith('admin');
      return _ok({
        'token': 'fake-token-${admin ? 'admin' : 'customer'}',
        'user': _userJson(
          id: admin ? 1 : 2,
          name: admin ? 'Admin Outdoor' : 'Budi Customer',
          email: email,
          role: admin ? 'admin' : 'customer',
        ),
      });
    }

    if (path == '/categories') {
      return _ok([
        {'id': 1, 'name': 'Tenda', 'description': 'Alat naik gunung'},
        {'id': 2, 'name': 'Peralatan Masak', 'description': 'Kompor dkk.'},
      ]);
    }

    if (path == '/equipments/popular') {
      return _ok([_equipmentJson()]);
    }

    if (path == '/equipments' && method == 'GET') {
      return _ok({
        'equipments': [_equipmentJson()],
        'pagination': {'total': 1, 'page': 1, 'limit': 20, 'total_pages': 1},
      });
    }

    if (path == '/equipments/1') {
      return _ok(_equipmentJson(detail: true));
    }

    if (path == '/equipments/1/availability') {
      return _ok({
        'equipment_id': 1,
        'stock': 10,
        'booked': 0,
        'available_stock': 10,
        'is_available': true,
      });
    }

    if (path == '/equipments/1/reviews') {
      return _ok({
        'reviews': const [],
        'pagination': {'total': 0, 'page': 1, 'limit': 10, 'total_pages': 0},
      });
    }

    if (path == '/bookings' && method == 'GET') {
      return _ok({
        'bookings': const [],
        'pagination': {'total': 0, 'page': 1, 'limit': 10, 'total_pages': 0},
      });
    }

    if (path == '/bookings' && method == 'POST') {
      return _ok(_bookingJson(), status: 201);
    }

    if (path == '/bookings/5') {
      return _ok(_bookingJson());
    }

    if (path == '/payments/info') {
      return _ok([
        {
          'bank_name': 'Bank BRI',
          'account_number': '1234567890',
          'account_name': 'OutdoorRent',
        },
      ]);
    }

    if (path == '/admin/dashboard') {
      return _ok({
        'total_orders': 12,
        'total_revenue': 1500000,
        'pending_verification_count': 3,
        'active_rentals_count': 2,
        'top_equipments': [
          {
            'id': 1,
            'name': 'Tenda Kapasitas 4 Orang',
            'total_rentals': '10',
            'category_name': 'Tenda',
          },
        ],
      });
    }

    return _error(404, 'Resource not found');
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _ok(Object? data, {int status = 200}) => _json(
        status: status,
        body: <String, dynamic>{
          'success': true,
          'message': 'OK',
          'data': data,
        },
      );

  ResponseBody _error(int status, String message) => _json(
        status: status,
        body: <String, dynamic>{'success': false, 'message': message},
      );

  ResponseBody _json({required int status, required Map<String, dynamic> body}) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
        },
      );

  Map<String, dynamic> _userJson({
    required int id,
    required String name,
    required String email,
    required String role,
  }) =>
      <String, dynamic>{
        'id': id,
        'name': name,
        'email': email,
        'phone': '081234567890',
        'role': role,
        'is_active': true,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      };

  Map<String, dynamic> _equipmentJson({bool detail = false}) =>
      <String, dynamic>{
        'id': 1,
        'category_id': 1,
        'name': 'Tenda Kapasitas 4 Orang',
        'description': 'Tenda dome ringan untuk 4 orang.',
        'price_per_day': '75000.00',
        'stock': 10,
        'deposit': '300000.00',
        'rating_avg': '4.80',
        'total_reviews': 12,
        'total_bookings': 30,
        'is_active': true,
        'category_name': 'Tenda',
        // Sengaja TANPA URL gambar: tes tidak boleh mengunduh gambar.
        'primary_image_url': null,
        'images': detail
            ? <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 9,
                  'equipment_id': 1,
                  'image_url': '',
                  'is_primary': true,
                  'sort_order': 0,
                },
              ]
            : const [],
        'reviews': const [],
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      };

  Map<String, dynamic> _bookingJson() => <String, dynamic>{
        'id': 5,
        'user_id': 2,
        'booking_code': 'OR-20261030-0001',
        'status': 'pending_payment',
        'pickup_date': '2026-11-01',
        'return_date': '2026-11-03',
        'total_days': 2,
        'subtotal': '300000.00',
        'deposit_total': '600000.00',
        'late_fee': '0.00',
        'damage_fee': '0.00',
        'deposit_refund': '0.00',
        'grand_total': '900000.00',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'equipment_id': 1,
            'equipment_name': 'Tenda Kapasitas 4 Orang',
            'quantity': 1,
            'price_per_day': '75000.00',
            'subtotal': '150000.00',
          },
        ],
        'payments': const [],
        'created_at': '2026-10-30T00:00:00Z',
        'updated_at': '2026-10-30T00:00:00Z',
      };
}
