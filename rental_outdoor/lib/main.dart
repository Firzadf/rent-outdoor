import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/constants.dart';
import 'core/network/app_retry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Data tanggal Indonesia (untuk "8 Okt 2026").
  await initializeDateFormatting('id_ID');

  // Supabase: Auth + PostgREST + Storage project rent-outdoor.
  // Anon key diisi lewat --dart-define=SUPABASE_ANON_KEY=... .
  // Bila kosong, inisialisasi tetap jalan dengan kunci placeholder
  // supaya aplikasi bisa dibuka; pemanggilan Supabase akan gagal
  // dengan pesan yang jelas dari SupabaseService. Jangan pakai
  // service_role key di aplikasi client.
  final anonKey = AppConstants.supabaseAnonKey.isNotEmpty
      ? AppConstants.supabaseAnonKey
      : 'SUPABASE_ANON_KEY_BELUM_DIISI';
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: anonKey,
  );

  // Kebijakan retry bersama (lihat appRetry): hanya error jaringan yang
  // di-retry 1x1 detik; error lain (404/422/500/...) langsung menampilkan
  // ErrorView tanpa menunggu retry bawaan Riverpod (±38 detik).
  runApp(
    ProviderScope(
      retry: appRetry,
      child: const RentalOutdoorApp(),
    ),
  );
}
