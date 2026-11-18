import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_service.dart';
import 'api_client.dart';
import '../storage/token_storage.dart';

/// Layanan Supabase tunggal untuk seluruh aplikasi.
final supabaseServiceProvider = Provider<SupabaseService>(
  (ref) => SupabaseService(),
);

/// Token JWT lawas (secure storage). DIPAKAI LAGI HANYA oleh
/// [ApiClient] lawas dan test lama. Aplikasi tidak lagi memakainya,
/// sesi dipegang Supabase Auth.
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Klien HTTP lawas ke backend PHP. DIPAKAI LAGI HANYA oleh test lama.
/// Repository aplikasi sudah memakai [supabaseServiceProvider].
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(tokenStorage: ref.watch(tokenStorageProvider));
  ref.onDispose(client.dispose);
  return client;
});
