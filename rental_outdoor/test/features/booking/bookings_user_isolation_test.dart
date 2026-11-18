import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/features/auth/presentation/auth_controller.dart';
import 'package:rental_outdoor/features/booking/data/booking_repository.dart';
import 'package:rental_outdoor/features/booking/domain/booking.dart';
import 'package:rental_outdoor/features/booking/presentation/bookings_provider.dart';
import 'package:rental_outdoor/features/catalog/domain/pagination.dart';

/// Daftar pesanan WAJIB terpisah antar user dan halaman.
///
/// Repository palsu (tanpa jaringan) mengembalikan data per user, sehingga
/// bisa dibuktikan `bookingsListProvider` hanya menampilkan pesanan milik
/// user yang sedang login.
void main() {
  Booking bookingOf(int id, String code, {String? status}) => Booking(
        id: id,
        bookingCode: code,
        status: status ?? BookingStatus.pendingPayment,
        totalDays: 2,
        grandTotal: 900000,
      );

  group('isolasi daftar pesanan per user', () {
    test('user A hanya melihat pesanannya, user B hanya miliknya', () async {
      final fakeA = _FakeBookingRepository(
        bookingsFor: (_) async => [
          bookingOf(1, 'OR-A-1'),
        ],
      );
      final fakeB = _FakeBookingRepository(
        bookingsFor: (_) async => [
          bookingOf(2, 'OR-B-1'),
        ],
      );

      final containerA = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue(1),
          bookingRepositoryProvider.overrideWithValue(fakeA),
        ],
      );
      addTearDown(containerA.dispose);
      final subA = containerA.listen(bookingsListProvider, (_, __) {});
      addTearDown(subA.close);

      final stateA = await containerA.read(bookingsListProvider.future);
      expect(stateA.items, hasLength(1));
      expect(stateA.items.single.bookingCode, 'OR-A-1');

      final containerB = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue(2),
          bookingRepositoryProvider.overrideWithValue(fakeB),
        ],
      );
      addTearDown(containerB.dispose);
      final subB = containerB.listen(bookingsListProvider, (_, __) {});
      addTearDown(subB.close);

      final stateB = await containerB.read(bookingsListProvider.future);
      expect(stateB.items, hasLength(1));
      expect(stateB.items.single.bookingCode, 'OR-B-1');
      expect(stateB.items.single.bookingCode, isNot('OR-A-1'));
    });

    test('belum login (userId null) -> daftar kosong tanpa panggilan API',
        () async {
      final fake = _FakeBookingRepository(
        bookingsFor: (_) async => throw StateError('tidak boleh dipanggil'),
      );

      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          bookingRepositoryProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(bookingsListProvider, (_, __) {});
      addTearDown(sub.close);

      final state = await container.read(bookingsListProvider.future);
      expect(state.items, isEmpty);
      expect(fake.calls, 0);
    });
  });

  group('filter status + paginasi', () {
    test('ganti chip status -> muat ulang halaman 1 dengan status itu',
        () async {
      final fake = _FakeBookingRepository(
        bookingsFor: (_) async => [bookingOf(1, 'OR-1')],
      );

      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue(1),
          bookingRepositoryProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(bookingsListProvider, (_, __) {});
      addTearDown(sub.close);

      await container.read(bookingsListProvider.future);
      expect(fake.lastStatus, isNull, reason: 'chip "Semua" tanpa status');
      expect(fake.lastPage, 1);

      container.read(bookingsFilterProvider.notifier).setStatus(
            BookingStatus.completed,
          );
      await container.read(bookingsListProvider.future);

      expect(fake.lastStatus, BookingStatus.completed);
      expect(fake.lastPage, 1);
    });

    test('loadMore menggabungkan halaman berikutnya + menghentikan di akhir',
        () async {
      final fake = _FakeBookingRepository(
        bookingsFor: (page) async => page == 1
            ? [bookingOf(1, 'OR-1')]
            : [bookingOf(2, 'OR-2')],
        totalPages: 2,
      );

      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue(1),
          bookingRepositoryProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(bookingsListProvider, (_, __) {});
      addTearDown(sub.close);

      final first = await container.read(bookingsListProvider.future);
      expect(first.hasMore, isTrue);
      expect(first.items.map((b) => b.bookingCode), ['OR-1']);

      await container.read(bookingsListProvider.notifier).loadMore();
      final second = container.read(bookingsListProvider).value!;

      expect(second.items.map((b) => b.bookingCode), ['OR-1', 'OR-2']);
      expect(second.hasMore, isFalse);
      expect(second.loadingMore, isFalse);

      // Sudah di halaman terakhir -> tidak ada panggilan lagi.
      final callsBefore = fake.calls;
      await container.read(bookingsListProvider.notifier).loadMore();
      expect(fake.calls, callsBefore);
    });
  });
}

/// Repository palsu: tanpa jaringan, hasil diatur lewat callback.
class _FakeBookingRepository implements BookingRepository {
  _FakeBookingRepository({
    required this.bookingsFor,
    this.totalPages = 1,
  });

  final Future<List<Booking>> Function(int page) bookingsFor;
  final int totalPages;

  int calls = 0;
  String? lastStatus;
  int? lastPage;

  @override
  Future<BookingsPage> getBookings({
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    calls++;
    lastStatus = status;
    lastPage = page;

    final items = await bookingsFor(page);

    return BookingsPage(
      items: items,
      pagination: Pagination(
        total: items.length * totalPages,
        page: page,
        limit: limit,
        totalPages: totalPages,
      ),
    );
  }

  @override
  Future<Booking> getBooking(int id) => throw UnimplementedError();

  @override
  Future<Booking> createBooking({
    required DateTime pickupDate,
    required DateTime returnDate,
    String? notes,
    required List<({int equipmentId, int quantity})> items,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> cancelBooking(int id, {String? reason}) =>
      throw UnimplementedError();
}
