/// Konfigurasi aplikasi.
///
/// Backend sekarang Supabase, bukan PHP lama.
///
/// Project: rent-outdoor
///   URL: https://mdpmdjmorihsjsdhvsbn.supabase.co
///   Region: Singapore (ap-southeast-1), plan Free
///   Tabel sudah dimigrasi dan live sejak 18 Nov 2026.
///
/// Kunci anon diisi lewat `--dart-define=SUPABASE_ANON_KEY=...`
/// saat build. Jangan pernah menulis anon key, apalagi service_role
/// key, di file ini atau di commit. Bila kosong, aplikasi tetap
/// ter-build tapi memanggil Supabase akan gagal dengan pesan yang jelas.
class AppConstants {
  AppConstants._();

  /// URL project Supabase rent-outdoor.
  static const String supabaseUrl =
      'https://mdpmdjmorihsjsdhvsbn.supabase.co';

  /// Anon key dari `--dart-define=SUPABASE_ANON_KEY=...`.
  /// Kosong bila tidak diisi saat build.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Base URL storage publik project ini.
  static String get storageBaseUrl => '$supabaseUrl/storage/v1/object/public';

  /// URL API PHP lama. DIPAKAI LAGI HANYA oleh [ApiClient] lawas yang
  /// dipertahankan untuk test lama; aplikasi tidak lagi memakainya.
  static const String _apiBaseUrlFromEnv =
      String.fromEnvironment('API_BASE_URL');

  @Deprecated('Backend PHP sudah diganti Supabase. Jangan dipakai untuk fitur baru.')
  static String get apiBaseUrl {
    final override = _apiBaseUrlFromEnv.trim();
    if (override.isNotEmpty) return _stripTrailingSlash(override);
    return 'http://10.0.2.2/outdoorrent/api';
  }

  @Deprecated('Backend PHP sudah diganti Supabase. Jangan dipakai untuk fitur baru.')
  static String get uploadsOrigin => apiBaseUrl.endsWith('/api')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - '/api'.length)
      : apiBaseUrl;

  static String _stripTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Batas upload foto profil (dicek juga di client).
  static const int maxUploadBytes = 2 * 1024 * 1024; // 2 MB

  static const String appName = 'OutdoorRent';

  /// Rekening tujuan transfer, sama dengan PAYMENT_BANKS di backend
  /// PHP lama. Tidak ada tabelnya di Supabase, jadi ditulis di sini.
  static const List<({String bankName, String accountNumber, String accountName})>
      paymentBanks = [
    (
      bankName: 'BCA',
      accountNumber: '1234567890',
      accountName: 'PT OutdoorRent Indonesia',
    ),
    (
      bankName: 'Mandiri',
      accountNumber: '0987654321',
      accountName: 'PT OutdoorRent Indonesia',
    ),
    (
      bankName: 'BRI',
      accountNumber: '5555666677778888',
      accountName: 'PT OutdoorRent Indonesia',
    ),
  ];
}
