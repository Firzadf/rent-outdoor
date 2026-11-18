import 'package:flutter/material.dart';

/// Tombol utama dengan state loading (otomatis nonaktif + spinner).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.expanded = true,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  /// `true` (default) = tombol melebar penuh.
  final bool expanded;

  /// Variansi merah untuk aksi berisiko (mis. hapus/logout).
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !loading;

    final style = danger
        ? FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          )
        : null;

    final Widget button;
    if (loading) {
      button = FilledButton(
        onPressed: null,
        style: style,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: danger ? scheme.onError : scheme.onPrimary,
          ),
        ),
      );
    } else if (icon != null) {
      button = FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style: style,
        icon: Icon(icon),
        label: Text(label),
      );
    } else {
      button = FilledButton(
        onPressed: enabled ? onPressed : null,
        style: style,
        child: Text(label),
      );
    }

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
