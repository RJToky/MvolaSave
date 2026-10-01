import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/material.dart';

/// Couleurs de l'application, reprises de la version web.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.text,
    required this.muted,
    required this.border,
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.shadow,
  });

  final Color bg;
  final Color surface;
  final Color text;
  final Color muted;
  final Color border;
  final Color accent;
  final Color accentSoft;
  final Color danger;
  final double shadow;

  static const light = Palette(
    bg: Color(0xFFF5F6F8),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF15181E),
    muted: Color(0xFF6B7280),
    border: Color(0xFFE3E6EB),
    accent: Color(0xFF0F7A4A),
    accentSoft: Color(0xFFE8F5EE),
    danger: Color(0xFFB42318),
    shadow: 0.08,
  );

  static const dark = Palette(
    bg: Color(0xFF0F1115),
    surface: Color(0xFF181B21),
    text: Color(0xFFEEF0F3),
    muted: Color(0xFF9AA1AC),
    border: Color(0xFF2A2F38),
    accent: Color(0xFF3CCF8E),
    accentSoft: Color(0xFF15291F),
    danger: Color(0xFFFF8A80),
    shadow: 0.3,
  );

  static Palette of(BuildContext context) => Theme.of(context).extension<Palette>()!;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    return Palette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: lerpDouble(shadow, other.shadow, t)!,
    );
  }
}

/// Chiffres à chasse fixe pour que les montants s'alignent.
const List<FontFeature> tabular = [FontFeature.tabularFigures()];

const double radius = 16;
const double innerRadius = 12;

ThemeData buildTheme(Palette p) {
  final dark = identical(p, Palette.dark);
  final scheme = ColorScheme.fromSeed(
    seedColor: p.accent,
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(primary: p.accent, surface: p.surface, onSurface: p.text, error: p.danger);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withValues(alpha: 0.25),
      selectionHandleColor: p.accent,
    ),
  );
}
