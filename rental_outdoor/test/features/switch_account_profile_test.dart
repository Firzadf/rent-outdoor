import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/app.dart';
import 'package:rental_outdoor/core/network/api_client.dart';
import 'package:rental_outdoor/core/network/api_providers.dart';
import 'package:rental_outdoor/core/storage/token_storage.dart';
import 'package:rental_outdoor/core/widgets/app_button.dart';
import 'package:rental_outdoor/features/auth/presentation/auth_controller.dart';
import 'package:rental_outdoor/features/auth/presentation/login_page.dart';
import 'package:rental_outdoor/features/profile/presentation/profile_page.dart';

/// Reproduksi bug: login A -> tab Profil -> logout -> login B -> tab Profil.
///
/// Memakai alur NYATA (go_router + StatefulShellRoute 5 tab, AuthController,
/// profileProvider, ProfilePage, interceptor dio, token storage) dengan
/// server palsu yang MENJAWAB SESUAI TOKEN yang dibawa request — sama
/// seperti backend asli, di mana token lama yang masih valid tetap
/// membalas profil akun lama.
void main() {
  testWidgets('ganti akun: halaman Profil harus mengikuti akun baru',
      (tester) async {
    final storage = _MemTokenStorage();
    final server = _FakeServer();
    final api = ApiClient(tokenStorage: storage)
      ..dio.httpClientAdapter = server;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(storage),
          apiClientProvider.overrideWithValue(api),
        ],
        child: const RentalOutdoorApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget, reason: 'token kosong');

    // ---- login akun A ----
    await tester.enterText(find.byType(TextFormField).at(0), 'a@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.widgetWithText(AppButton, 'Masuk'));
    await tester.pumpAndSettle();

    // Sapaan Beranda memakai nama sesi akun A.
    expect(find.text('Hai, Akun A'), findsOneWidget);

    // ---- buka tab Profil ----
    await _openTab(tester, 'Profil');
    expect(
      find.widgetWithText(TextFormField, 'a@test.com'),
      findsOneWidget,
      reason: 'profil awal = akun A',
    );

    // ---- logout dari tab Profil ----
    await _logout(tester);
    expect(find.byType(LoginPage), findsOneWidget);

    // ---- login akun B ----
    await tester.enterText(find.byType(TextFormField).at(0), 'b@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.widgetWithText(AppButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Hai, sijhondoee'), findsOneWidget);

    // ---- buka tab Profil lagi ----
    await _openTab(tester, 'Profil');
    expect(
      find.widgetWithText(TextFormField, 'b@test.com'),
      findsOneWidget,
      reason: 'profil harus ikut akun B (bukan akun A)',
    );
    expect(find.text('Akun A'), findsNothing);
    expect(find.text('sijhondoee'), findsWidgets);

    // GET /user/profile terakhir harus membawa token B.
    expect(
      server.requests.where((r) => r.contains('GET /user/profile')).last,
      contains('token=tokenB-bbbbbb'),
    );
  });

  testWidgets(
      'respons lambat: profil akun lama tidak boleh menimpa akun baru',
      (tester) async {
    final storage = _MemTokenStorage();
    final server = _FakeServer()
      ..profileDelays = <String, Duration>{
        'tokenA-aaaaaa': const Duration(milliseconds: 4000),
        'tokenB-bbbbbb': const Duration(milliseconds: 250),
      };
    final api = ApiClient(tokenStorage: storage)
      ..dio.httpClientAdapter = server;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(storage),
          apiClientProvider.overrideWithValue(api),
        ],
        child: const RentalOutdoorApp(),
      ),
    );
    await tester.pumpAndSettle();

    // ---- login akun A ----
    await tester.enterText(find.byType(TextFormField).at(0), 'a@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.widgetWithText(AppButton, 'Masuk'));
    await tester.pumpAndSettle();

    // ---- buka tab Profil: respons A ditahan 4000ms ----
    await tester.tap(_tabButton('Profil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Memuat profil...'), findsOneWidget);

    // ---- logout SEBELUM respons A datang (tanpa settle: spinner profil
    //      masih berjalan di belakang dialog) ----
    await tester.tap(find.byTooltip('Keluar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Keluar'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LoginPage), findsOneWidget);

    // ---- login akun B ----
    await tester.enterText(find.byType(TextFormField).at(0), 'b@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.widgetWithText(AppButton, 'Masuk'));
    await tester.pumpAndSettle();

    // ---- buka tab Profil: respons B (250ms) ----
    await tester.tap(_tabButton('Profil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Beri waktu: respons A yang masih lambat (4000ms) seharusnya mendarat
    // pada rentang ini — kalau respons lama masih bisa menimpa state,
    // halaman akan menampilkan akun A lagi.
    await tester.pump(const Duration(milliseconds: 5000));

    expect(
      find.widgetWithText(TextFormField, 'b@test.com'),
      findsOneWidget,
      reason: 'respons lambat milik akun A tidak boleh menimpa profil B',
    );
    expect(find.text('Akun A'), findsNothing);
  });

  testWidgets(
      'sesi berubah saat halaman Profil terbuka: tanpa error + State dibuang',
      (tester) async {
    final storage = _MemTokenStorage();
    final server = _FakeServer();
    final api = ApiClient(tokenStorage: storage)
      ..dio.httpClientAdapter = server;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(storage),
          apiClientProvider.overrideWithValue(api),
        ],
        child: const RentalOutdoorApp(),
      ),
    );
    await tester.pumpAndSettle();

    // ---- login akun A ----
    await tester.enterText(find.byType(TextFormField).at(0), 'a@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.widgetWithText(AppButton, 'Masuk'));
    await tester.pumpAndSettle();

    // ---- buka tab Profil A ----
    await _openTab(tester, 'Profil');
    expect(find.widgetWithText(TextFormField, 'a@test.com'), findsOneWidget);

    // ---- sesi berubah DENGAN tab Profil masih terbuka ----
    // Kasus asli: token kedaluwarsa (401) saat melihat profil. Dulu
    // `ref.invalidate(profileProvider)` dari AuthController melempar
    // CircularDependencyError DI SINI (profil = dependen sesi).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProfilePage)),
    );
    await container.read(authControllerProvider.notifier).logout();

    // Transisi ke /login (jangan pumpAndSettle: halaman profil sempat
    // menampilkan spinner tanpa animasi berhenti).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byType(LoginPage),
      findsOneWidget,
      reason: 'redirect ke /login setelah sesi berakhir',
    );

    // ---- login akun B ----
    await tester.enterText(find.byType(TextFormField).at(0), 'b@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.widgetWithText(AppButton, 'Masuk'));
    await tester.pumpAndSettle();

    // ---- buka tab Profil B: State lama tidak dipakai lagi ----
    await _openTab(tester, 'Profil');

    expect(
      find.widgetWithText(TextFormField, 'b@test.com'),
      findsOneWidget,
      reason: 'State akun A tidak boleh bertahan ke akun B',
    );
    expect(find.text('Akun A'), findsNothing);
    expect(
      server.requests.where((r) => r.contains('GET /user/profile')).last,
      contains('token=tokenB-bbbbbb'),
    );
  });
}

/// Locator label tab pada `NavigationBar` shell (unik — teks yang sama
/// di halaman tidak ikut tercakup karena dibatasi bar navigasi).
Finder _tabButton(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

/// Ketuk tab lalu tunggu sampai benar-benar diam (hanya untuk kondisi
/// tanpa animasi spinner berjalan).
Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(_tabButton(label));
  await tester.pumpAndSettle();
}

/// Logout lewat aksi "Keluar" di tab Profil (ikon AppBar) + konfirmasi.
Future<void> _logout(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Keluar'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Keluar'),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Token storage dalam memori (pengganti flutter_secure_storage di test)
// ---------------------------------------------------------------------------
class _MemTokenStorage extends TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async {
    _token = token;
  }

  @override
  Future<void> delete() async {
    _token = null;
  }
}

// ---------------------------------------------------------------------------
// Server palsu: profil dijawab SESUAI token yang dibawa request.
// ---------------------------------------------------------------------------
class _FakeServer implements HttpClientAdapter {
  /// Jeda respons `GET /user/profile` per token (meniru jaringan lambat).
  Map<String, Duration> profileDelays = <String, Duration>{};

  static const Map<String, Map<String, dynamic>> _accounts = {
    'a@test.com': {
      'id': 1,
      'email': 'a@test.com',
      'name': 'Akun A',
      'phone': '0811111111',
      'address': 'Jalan A No. 1',
      'role': 'customer',
      'is_active': 1,
    },
    'b@test.com': {
      'id': 2,
      'email': 'b@test.com',
      'name': 'sijhondoee',
      'phone': '0822222222',
      'address': 'Jalan B No. 2',
      'role': 'customer',
      'is_active': 1,
    },
  };

  static const Map<String, String> _tokenToEmail = {
    'tokenA-aaaaaa': 'a@test.com',
    'tokenB-bbbbbb': 'b@test.com',
  };

  /// `METHOD /path token=xxx` untuk setiap request yang masuk.
  final List<String> requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    var raw = '';
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        raw += utf8.decode(chunk);
      }
    }
    final payload = raw.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;

    final header = options.headers['Authorization'];
    final token =
        header is String ? header.replaceFirst('Bearer ', '') : null;
    requests.add('${options.method} ${options.path} token=${token ?? '-'}');

    final path = options.path;

    if (options.method == 'POST' && path == '/auth/login') {
      final email = payload['email'];
      final password = payload['password'];
      final emailToToken = _tokenToEmail.map((k, v) => MapEntry(v, k));
      if (_accounts[email] == null || password != 'password') {
        return _json(
          401,
          {'success': false, 'message': 'Email atau password salah.'},
        );
      }
      return _json(200, {
        'success': true,
        'message': 'OK',
        'data': {
          'token': emailToToken[email],
          'user': _accounts[email],
        },
      });
    }

    final email = token == null ? null : _tokenToEmail[token];
    final account = email == null ? null : _accounts[email];

    if (account == null) {
      return _json(
        401,
        {'success': false, 'message': 'Token tidak valid.'},
      );
    }

    if (path == '/auth/me') {
      return _json(200, {'success': true, 'message': 'OK', 'data': account});
    }
    if (path == '/user/profile' && options.method == 'GET') {
      final delay = profileDelays[token];
      if (delay != null) {
        await Future<void>.delayed(delay);
      }
      return _json(200, {'success': true, 'message': 'OK', 'data': account});
    }

    return _json(404, {'success': false, 'message': 'Tidak ditemukan: $path'});
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json; charset=utf-8'],
        },
      );

  @override
  void close({bool force = false}) {}
}
