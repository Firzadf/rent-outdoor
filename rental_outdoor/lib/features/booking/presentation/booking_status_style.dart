import 'package:flutter/material.dart';

import '../domain/booking.dart';

/// Gaya badge status booking: label Indonesia + warna latar/teks.
@immutable
class BookingStatusStyle {
  const BookingStatusStyle({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

/// Pemetaan status -> label + warna memakai warna tema.
///
/// Status yang tidak dikenal — termasuk `rejected` yang ada di ENUM tapi
/// TIDAK dipakai alur server — tetap mendapat gaya cadangan supaya UI
/// tidak pernah crash.
BookingStatusStyle bookingStatusStyle(BuildContext context, String status) =>
    bookingStatusStyleFor(Theme.of(context).colorScheme, status);

/// Versi murni (hanya butuh [ColorScheme]) supaya mudah diuji tanpa widget.
BookingStatusStyle bookingStatusStyleFor(ColorScheme scheme, String status) =>
    switch (status) {
      BookingStatus.pendingPayment => BookingStatusStyle(
          label: BookingStatus.label(status),
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
        ),
      BookingStatus.pendingVerification => BookingStatusStyle(
          label: BookingStatus.label(status),
          background: scheme.tertiaryContainer,
          foreground: scheme.onTertiaryContainer,
        ),
      BookingStatus.confirmed => BookingStatusStyle(
          label: BookingStatus.label(status),
          background: scheme.primaryContainer,
          foreground: scheme.onPrimaryContainer,
        ),
      BookingStatus.inUse => BookingStatusStyle(
          label: BookingStatus.label(status),
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
        ),
      BookingStatus.completed => BookingStatusStyle(
          label: BookingStatus.label(status),
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurface,
        ),
      BookingStatus.cancelled => BookingStatusStyle(
          label: BookingStatus.label(status),
          background: scheme.outlineVariant,
          foreground: scheme.onSurfaceVariant,
        ),
      // Ada di ENUM schema, tidak dipakai alur: tetap diberi label + warna.
      BookingStatus.rejected => BookingStatusStyle(
          label: BookingStatus.label(status),
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
        ),
      _ => BookingStatusStyle(
          label: BookingStatus.label(status),
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurfaceVariant,
        ),
    };
