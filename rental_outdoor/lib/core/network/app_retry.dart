import 'api_exception.dart';

/// Kebijakan retry provider Riverpod — DIPAKAI BERSAMA oleh aplikasi
/// (`ProviderScope` di `main.dart`) dan seluruh test, supaya perilaku
/// loading -> ErrorView identik di keduanya.
///
/// Tanpa kebijakan ini, default Riverpod (`ProviderContainer.defaultRetry`)
/// mengulang SEMUA error ber-tipe `Exception` sampai 10 kali dengan backoff
/// eksponensial (200 ms, 400 ms, ..., 6400 ms) -> layar loading ±38 detik
/// sebelum ErrorView + tombol "Coba Lagi" muncul.
///
/// Aturan:
/// - **Error jaringan / timeout** ([ApiException.isNetworkError],
///   `statusCode == 0`): maksimal **1 kali** retry dengan jeda **1 detik**
///   (mis. Apache mati sesaat lalu hidup lagi).
/// - **Error lain** (400, 401, 403, 404, 409, 422, 500, ...) dan tipe error
///   selain [ApiException]: **tidak pernah di-retry** — ErrorView muncul
///   seketika (mis. 404 / 422 dari server).
///
/// Dipanggil Riverpod dengan `retryCount` mulai dari 0; hasil `null` berarti
/// berhenti (state langsung `AsyncError`).
Duration? appRetry(int retryCount, Object error) {
  // Satu-satunya kasus yang di-retry: error jaringan, sekali saja, 1 detik.
  if (error is ApiException && error.isNetworkError && retryCount == 0) {
    return const Duration(seconds: 1);
  }
  return null;
}
