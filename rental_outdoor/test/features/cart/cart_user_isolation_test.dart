import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rental_outdoor/features/auth/presentation/auth_controller.dart';
import 'package:rental_outdoor/features/cart/data/cart_storage.dart';
import 'package:rental_outdoor/features/cart/domain/cart_item.dart';
import 'package:rental_outdoor/features/cart/presentation/cart_provider.dart';
import 'package:rental_outdoor/features/catalog/domain/equipment.dart';

/// Keranjang adalah data CLIENT-SIDE per user (kunci `cart_v1_{userId}`):
/// keranjang user A tidak boleh pernah terlihat oleh user B.
///
/// Semua test memakai `SharedPreferences.setMockInitialValues` — tanpa
/// jaringan dan tanpa server.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  const tenda = Equipment(
    id: 1,
    categoryId: 1,
    name: 'Tenda Kapasitas 4 Orang',
    pricePerDay: 75000,
    deposit: 300000,
    stock: 10,
  );

  test('kunci penyimpanan per user: cart_v1_{userId}', () {
    expect(CartStorage.keyFor(1), 'cart_v1_1');
    expect(CartStorage.keyFor(42), 'cart_v1_42');
  });

  test('keranjang user A tidak terlihat oleh user B', () async {
    final containerA = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWithValue(1)],
    );
    addTearDown(containerA.dispose);
    // Listener menjaga provider autoDispose tetap hidup selama test.
    final subA = containerA.listen(cartProvider, (_, __) {});
    addTearDown(subA.close);

    await containerA.read(cartProvider.future);
    await containerA.read(cartProvider.notifier).addEquipment(tenda, 2);
    expect(containerA.read(cartProvider).value!.totalQuantity, 2);

    final containerB = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWithValue(2)],
    );
    addTearDown(containerB.dispose);
    final subB = containerB.listen(cartProvider, (_, __) {});
    addTearDown(subB.close);

    final stateB = await containerB.read(cartProvider.future);
    expect(stateB.items, isEmpty);
    expect(stateB.totalQuantity, 0);
  });

  test('storage terpisah per user (termasuk tanggal sewa)', () async {
    final storage = CartStorage();
    await storage.write(
      1,
      CartRecord(
        items: [CartItem.fromEquipment(tenda, 3)],
        pickupDate: DateTime(2026, 11, 1),
        returnDate: DateTime(2026, 11, 3),
      ),
    );

    final milikA = await storage.read(1);
    expect(milikA.items, hasLength(1));
    expect(milikA.items.first.quantity, 3);
    expect(milikA.pickupDate, DateTime(2026, 11, 1));
    expect(milikA.returnDate, DateTime(2026, 11, 3));

    final milikB = await storage.read(2);
    expect(milikB.items, isEmpty);
    expect(milikB.pickupDate, isNull);
    expect(milikB.returnDate, isNull);
  });

  test('clearCart hanya mengosongkan keranjang user terkait', () async {
    final containerA = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWithValue(1)],
    );
    addTearDown(containerA.dispose);
    final subA = containerA.listen(cartProvider, (_, __) {});
    addTearDown(subA.close);

    final containerB = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWithValue(2)],
    );
    addTearDown(containerB.dispose);
    final subB = containerB.listen(cartProvider, (_, __) {});
    addTearDown(subB.close);

    await containerA.read(cartProvider.future);
    await containerB.read(cartProvider.future);
    await containerA.read(cartProvider.notifier).addEquipment(tenda, 1);
    await containerB.read(cartProvider.notifier).addEquipment(tenda, 4);

    // Keranjang user A dikosongkan (mis. setelah checkout sukses).
    await containerA.read(cartProvider.notifier).clearCart();
    expect(containerA.read(cartProvider).value!.isEmpty, isTrue);

    // Keranjang user B tidak boleh ikut terhapus.
    final stateB = await CartStorage().read(2);
    expect(stateB.items, hasLength(1));
    expect(stateB.items.first.quantity, 4);
  });
}
