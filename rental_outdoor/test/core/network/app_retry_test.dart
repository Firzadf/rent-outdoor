import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_outdoor/core/network/api_exception.dart';
import 'package:rental_outdoor/core/network/app_retry.dart';

/// Kebijakan retry aplikasi (`appRetry`) — dipakai sama oleh
/// `ProviderScope` (main.dart) dan test, supaya ErrorView + tombol
/// "Coba Lagi" muncul dalam hitungan detik (server mati / 404),
/// bukan setelah retry bawaan Riverpod (±38 detik).
void main() {
  group('appRetry — error TIDAK di-retry', () {
    for (final status in [400, 401, 403, 404, 409, 422]) {
      test('ApiException $status tidak pernah di-retry', () {
        final error = ApiException(
          statusCode: status,
          message: 'Gagal memproses.',
        );
        expect(appRetry(0, error), isNull);
        expect(appRetry(1, error), isNull);
        expect(appRetry(9, error), isNull);
      });
    }

    test('ApiException 500 (server error) tidak di-retry', () {
      final error = ApiException(statusCode: 500, message: 'Server error.');
      expect(appRetry(0, error), isNull);
      expect(appRetry(1, error), isNull);
    });

    test('error selain ApiException tidak di-retry', () {
      expect(appRetry(0, StateError('rusak')), isNull);
      expect(appRetry(0, const FormatException('buruk')), isNull);
      expect(appRetry(0, Exception('umum')), isNull);
    });
  });

  group('appRetry — error jaringan (statusCode 0)', () {
    test('retry pertama: jeda 1 detik', () {
      expect(
        appRetry(0, ApiException.network('Tidak ada koneksi.')),
        const Duration(seconds: 1),
      );
    });

    test('maksimal 1 kali retry: percobaan berikutnya berhenti', () {
      expect(appRetry(1, ApiException.network('Tidak ada koneksi.')), isNull);
      expect(appRetry(2, ApiException.network('Tidak ada koneksi.')), isNull);
    });

    test('ApiException.isNetworkError = statusCode 0', () {
      final network = ApiException.network('Timeout.');
      expect(network.statusCode, 0);
      expect(network.isNetworkError, isTrue);
      expect(appRetry(0, network), const Duration(seconds: 1));
    });
  });

  group('perilaku runtime (ProviderContainer retry: appRetry)', () {
    test('404 langsung AsyncError + tanpa pengulangan (dalam < 2 detik)',
        () async {
      final holder = _Holder(
        ApiException(statusCode: 404, message: 'Data tidak ditemukan.'),
      );
      final container = ProviderContainer(
        retry: appRetry,
        overrides: [failingHolderProvider.overrideWithValue(holder)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(failingProvider, (_, __) {});
      addTearDown(sub.close);

      final stopwatch = Stopwatch()..start();
      await expectLater(
        container.read(failingProvider.future),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
      stopwatch.stop();

      expect(holder.calls, 1, reason: '404 tidak boleh diulang');
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 2)),
        reason: 'ErrorView muncul seketika, bukan ±38 detik',
      );

      final state = container.read(failingProvider);
      expect(state.hasError, isTrue);
      expect(
        state.isLoading,
        isFalse,
        reason: 'tidak tertahan di AsyncLoading(retrying)',
      );
    });

    test('server mati (jaringan): diulang tepat 1 kali setelah 1 detik',
        () async {
      final holder = _Holder(ApiException.network('Server tidak dihubungi.'));
      final container = ProviderContainer(
        retry: appRetry,
        overrides: [failingHolderProvider.overrideWithValue(holder)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(failingProvider, (_, __) {});
      addTearDown(sub.close);

      final stopwatch = Stopwatch()..start();
      await expectLater(
        container.read(failingProvider.future),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 0)),
      );
      stopwatch.stop();

      expect(holder.calls, 2, reason: 'persis 1 retry (total 2 percobaan)');
      expect(
        stopwatch.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 900)),
        reason: 'retry menunggu jeda 1 detik',
      );
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 5)),
        reason: 'berhenti, bukan lanjut backoff bawaan (±38 detik)',
      );
    });
  });
}

/// Error + hitungan pemanggilan `build` untuk satu test.
class _Holder {
  _Holder(this.error);

  final ApiException error;
  int calls = 0;
}

final failingHolderProvider = Provider<_Holder>(
  (ref) => _Holder(ApiException(statusCode: 500, message: 'Gagal.')),
);

final failingProvider =
    AsyncNotifierProvider.autoDispose<_FailingController, int>(
  _FailingController.new,
);

class _FailingController extends AsyncNotifier<int> {
  @override
  Future<int> build() {
    final holder = ref.read(failingHolderProvider);
    holder.calls++;
    throw holder.error;
  }
}
