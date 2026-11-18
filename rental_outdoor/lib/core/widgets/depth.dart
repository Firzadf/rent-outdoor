import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Sistem kedalaman 3D OutdoorRent.
///
/// Semua layar utama memakai widget di file ini supaya kesan
/// mengambang konsisten: kartu berlapis bayangan lembut, panel hero
/// gradien hijau hutan, animasi masuk yang naik 16px dalam 250ms,
/// dan efek tekan yang mengecil 3 persen. Animasi memakai
/// transform dan opacity saja, dan dimatikan bila
/// `MediaQuery.disableAnimations` aktif.
///
/// Catatan desain: gradien, kaca, dan bayangan berlapis di sini
/// mengikuti brief user 18 Nov 2026 yang meminta tampilan modern
/// 3D. Itu sengaja menyimpang dari `~/workspace/design.md` bagian 2
/// yang melarang gradien, glass, dan shadow pada benda diam. Brief
/// user menang atas konstitusi untuk proyek ini, dan penyimpangan
/// itu dicatat di laporan.

/// Kartu mengambang: permukaan membulat 20 dengan dua lapis bayangan
/// (ambient lembut + kunci) dan garis tepi tipis, tanpa `Card`
/// bawaan yang datar.
class DepthCard extends StatelessWidget {
  const DepthCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation = 0,
    this.radius = AppRadii.card,
    this.color,
    this.onTap,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// 0 = lembut, 1 = terangkat, 2 = melayang.
  final int elevation;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shadows = switch (elevation) {
      1 => AppShadows.lifted(scheme),
      2 => AppShadows.floating(scheme),
      _ => AppShadows.soft(scheme),
    };
    // Bayangan di wadah luar supaya tidak terpotong oleh klip foto
    // di dalam kartu; warna dan garis tepi di wadah dalam.
    // Material dipakai (bukan Container) supaya InkWell di dalam
    // kartu tetap menampilkan ripple.
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: clipBehavior,
      child: Material(
        color: color ?? scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        clipBehavior: clipBehavior,
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
    final body = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
      ),
      child: card,
    );
    if (onTap == null) return body;
    final VoidCallback tap = onTap!;
    return Pressable(
      onTap: tap,
      child: body,
    );
  }
}

/// Panel kaca: permukaan tembus pandang dengan garis tepi terang.
/// Dipakai untuk chip di atas foto dan overlay hero, bukan untuk
/// seluruh kartu, supaya teks tetap terbaca.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.radius = AppRadii.chip,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: (isLight ? Colors.white : Colors.black)
            .withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
        ),
        boxShadow: AppShadows.soft(Theme.of(context).colorScheme),
      ),
      child: child,
    );
  }
}

/// Panel hero gradien hijau hutan ke pine, dengan dua lingkaran
/// dekoratif tembus pandang di sudut. Isi panel (headline, aksi)
/// diletakkan sebagai [child] supaya teks tidak tertutup dekorasi.
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.sheet),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.forestGreen,
            AppColors.pineDark,
          ],
        ),
        boxShadow: AppShadows.floating(Theme.of(context).colorScheme),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -36,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 48,
            bottom: -52,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orangeAccent.withValues(alpha: 0.22),
              ),
            ),
          ),
          Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Efek tekan: mengecil ke 0.97 saat disentuh, kembali saat dilepas.
/// Durasi 120ms, hanya transform, tanpa mengubah layout.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Animasi masuk: naik 16px + opacity 0 ke 1 dalam 250ms, dengan
/// [delay] untuk stagger antar kartu. Bila animasi dimatikan di
/// sistem, konten langsung tampil tanpa gerakan.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _offset =
        Tween<Offset>(begin: const Offset(0, 16), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: _offset.value,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Chip stok: "Tersedia n" hijau, "Habis" merah, "Sisa n" oranye
/// bila stok menipis (1-2 unit). Dipakai di atas foto kartu produk.
class StockChip extends StatelessWidget {
  const StockChip({super.key, required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = stock <= 0
        ? ('Habis', theme.colorScheme.error)
        : stock <= 2
            ? ('Sisa $stock', AppColors.ember)
            : ('Tersedia $stock', AppColors.forestGreen);
    return GlassPanel(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lencana gradien kecil untuk ikon header (splash, login, register):
/// kotak membulat berisi ikon putih di atas gradien hijau-oranye.
class GradientIconBadge extends StatelessWidget {
  const GradientIconBadge({
    super.key,
    required this.icon,
    this.size = 64,
    this.iconSize = 32,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.moss, AppColors.forestGreenDark],
        ),
        boxShadow: AppShadows.lifted(Theme.of(context).colorScheme),
      ),
      child: Icon(icon, size: iconSize, color: Colors.white),
    );
  }
}
