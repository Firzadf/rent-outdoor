import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:rental_outdoor/features/cart/domain/cart_item.dart';
import 'package:rental_outdoor/features/cart/presentation/cart_page.dart';
import 'package:rental_outdoor/features/cart/presentation/cart_provider.dart';

/// Widget test halaman Keranjang — TANPA jaringan: provider keranjang
/// di-override dengan state tetap.
class _FakeCartController extends CartController {
  _FakeCartController(this._initial);

  final CartState _initial;

  @override
  Future<CartState> build() async => _initial;
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  const item = CartItem(
    equipmentId: 1,
    name: 'Tenda Kapasitas 4 Orang',
    pricePerDay: 75000,
    deposit: 300000,
    quantity: 2,
    stock: 10,
  );

  Future<void> pumpCart(WidgetTester tester, CartState state) async {
    // Viewport tinggi supaya semua bagian ListView (termasuk tombol
    // checkout di bawah) benar-benar dibangun.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartProvider.overrideWith(() => _FakeCartController(state)),
        ],
        child: const MaterialApp(home: CartPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Tombol utama (AppButton memakai `FilledButton.icon`, jadi dicari
  /// lewat predikat — bukan `byType`).
  FilledButton checkoutButton(WidgetTester tester) => tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Lanjut ke Checkout'),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        ),
      );

  testWidgets('keranjang kosong -> pesan kosong + tombol ke katalog',
      (tester) async {
    await pumpCart(tester, const CartState());

    expect(find.textContaining('Keranjang masih kosong'), findsOneWidget);
    expect(find.text('Jelajahi Katalog'), findsOneWidget);
    // Tanpa item, aksi kosongkan keranjang tidak tampil.
    expect(find.byTooltip('Kosongkan keranjang'), findsNothing);
  });

  testWidgets('ada item tanpa tanggal -> tombol checkout nonaktif',
      (tester) async {
    await pumpCart(tester, const CartState(items: [item]));

    expect(find.text('Tenda Kapasitas 4 Orang'), findsOneWidget);
    expect(find.text('Rp 75.000/hari'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // jumlah item
    expect(
      find.textContaining('Pilih tanggal sewa untuk melihat estimasi biaya'),
      findsOneWidget,
    );

    final button = checkoutButton(tester);
    expect(button.onPressed, isNull);
  });

  testWidgets('tanggal valid -> estimasi tampil + checkout aktif',
      (tester) async {
    // Tanggal relatif terhadap hari ini: tanggal tetap (1-3 Nov 2026)
    // sudah lewat saat test dijalankan 18 Nov 2026, sehingga
    // hasValidRange false dan estimasi tidak tampil.
    final today = DateTime.now();
    final pickup = DateTime(today.year, today.month, today.day)
        .add(const Duration(days: 7));
    await pumpCart(
      tester,
      CartState(
        items: const [item],
        pickupDate: pickup,
        returnDate: pickup.add(const Duration(days: 2)),
      ),
    );

    // 75000 × 2 × 2 hari = 300000 ; deposit 300000 × 2 = 600000.
    expect(find.textContaining('Estimasi Biaya'), findsOneWidget);
    expect(find.text('Rp 300.000'), findsWidgets);
    expect(find.text('Rp 600.000'), findsWidgets);
    expect(find.text('Rp 900.000'), findsOneWidget);
    expect(
      find.textContaining('Estimasi, total final dihitung server'),
      findsOneWidget,
    );

    final button = checkoutButton(tester);
    expect(button.onPressed, isNotNull);
  });
}
