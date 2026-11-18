import 'package:flutter/material.dart';

/// Warna aplikasi: hijau hutan (utama) + oranye (aksen).
///
/// Identitas template dipertahankan, nadanya dinaikkan ke modern:
/// hijau pine yang lebih dalam untuk permukaan hero, oranye summit
/// hanya untuk aksi utama, dan mist/sand sebagai latar berlapis
/// supaya kartu terasa mengambang, bukan datar.
class AppColors {
  AppColors._();

  static const Color forestGreen = Color(0xFF1F6B3B);
  static const Color forestGreenDark = Color(0xFF0E3D22);
  static const Color pineDark = Color(0xFF0B2E1B);
  static const Color moss = Color(0xFF2E7D4F);
  static const Color mist = Color(0xFFE8F3EC);
  static const Color sand = Color(0xFFF7F3EA);
  static const Color orangeAccent = Color(0xFFF57C00);
  static const Color ember = Color(0xFFE65100);
}

/// Bayangan berlapis untuk kesan kedalaman 3D.
///
/// Dipakai lewat [DepthCard]: satu bayangan ambient yang lembut
/// ditambah satu bayangan kunci yang lebih tegas, supaya kartu
/// terangkat dari latar tanpa glow yang berlebihan.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft(ColorScheme scheme) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: scheme.shadow.withValues(alpha: 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> lifted(ColorScheme scheme) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> floating(ColorScheme scheme) => [
        BoxShadow(
          color: AppColors.pineDark.withValues(alpha: 0.28),
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ];
}

/// Radius konsisten: kartu 20, input dan tombol 14, panel bawah 24.
class AppRadii {
  AppRadii._();

  static const double card = 20;
  static const double input = 14;
  static const double button = 14;
  static const double sheet = 24;
  static const double chip = 999;
}

/// Tema Material 3 — mode terang & gelap mengikuti sistem.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.forestGreen,
      brightness: brightness,
    ).copyWith(
      secondary: AppColors.orangeAccent,
      tertiary: AppColors.moss,
      surface: brightness == Brightness.light
          ? const Color(0xFFF7FAF7)
          : null,
    );

    final isLight = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isLight ? const Color(0xFFF2F6F2) : null,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sheet),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          elevation: 2,
          shadowColor: AppColors.pineDark.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
