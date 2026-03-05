import 'package:flutter/material.dart';

/// Theme-aware Analytics styling — adapts to light/dark mode.
class AnalyticsTheme {
  // ── Helper ──────────────────────────────────────────────────────────
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // ── Background Colors ──────────────────────────────────────────────
  static Color mainBackground(BuildContext context) =>
      _isDark(context) ? const Color(0xFF141110) : const Color(0xFFFEF9F5);

  static Color cardBackground(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1F1B1A) : const Color(0xFFFFF3E8);

  // ── Accent Colors ──────────────────────────────────────────────────
  static Color primaryGold(BuildContext context) =>
      _isDark(context) ? const Color(0xFFD4A574) : const Color(0xFF95674D);

  static Color secondaryBeige(BuildContext context) =>
      _isDark(context) ? const Color(0xFF8D6E63) : const Color(0xFFEDAD4C);

  // ── Chart Colors (work on both backgrounds) ────────────────────────
  static const Color chartBlue = Color(0xFF6BB6FF);
  static const Color chartPurple = Color(0xFFB889FF);
  static const Color chartGreen = Color(0xFF7BD88F);
  static const Color chartAmber = Color(0xFFFFA726);
  static const Color chartRed = Color(0xFFEF5350);

  static List<Color> chartColors(BuildContext context) => [
        primaryGold(context),
        chartBlue,
        chartPurple,
        chartGreen,
        secondaryBeige(context),
        chartAmber,
      ];

  // ── Border & Glow ──────────────────────────────────────────────────
  static Color borderColor(BuildContext context) =>
      _isDark(context) ? const Color(0xFF3E312B) : const Color(0xFFE7D6C9);

  static Color glowColor(BuildContext context) =>
      primaryGold(context).withOpacity(0.2);

  // ── Text Colors ────────────────────────────────────────────────────
  static Color primaryText(BuildContext context) =>
      _isDark(context) ? const Color(0xFFEAE0D5) : const Color(0xFF3B2A22);

  static Color secondaryText(BuildContext context) => _isDark(context)
      ? const Color(0xFFDCC8B8).withOpacity(0.7)
      : const Color(0xFF5A3F32);

  // ── Adaptive helpers for inline hardcoded colors ───────────────────
  /// Replaces `Colors.white` / `Colors.white10` / `Colors.white12` used
  /// as dividers, grid lines, or faint overlays.
  static Color dividerColor(BuildContext context) =>
      _isDark(context) ? Colors.white10 : const Color(0xFFE7D6C9);

  /// For text that was hardcoded `Colors.white` (e.g. chart tooltips, pie labels).
  static Color onAccentText(BuildContext context) =>
      _isDark(context) ? Colors.white : const Color(0xFF3B2A22);

  // ── Card Styling ───────────────────────────────────────────────────
  static const double cardRadius = 20.0;
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);

  // ── Glassmorphism Card Decoration ──────────────────────────────────
  static BoxDecoration glassCard(BuildContext context, {bool selected = false}) {
    final dark = _isDark(context);
    return BoxDecoration(
      color: cardBackground(context),
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(
        color: selected ? primaryGold(context) : borderColor(context),
        width: selected ? 1.5 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: selected
              ? glowColor(context)
              : Colors.black.withOpacity(dark ? 0.3 : 0.08),
          blurRadius: selected ? 12 : 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ── Icon Container Decoration ──────────────────────────────────────
  static BoxDecoration iconContainer(BuildContext context, {Color? color}) {
    return BoxDecoration(
      color: (color ?? primaryGold(context)).withOpacity(0.15),
      shape: BoxShape.circle,
    );
  }

  // ── Drawer Item Decoration ─────────────────────────────────────────
  static BoxDecoration selectedDrawerItem(BuildContext context) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: primaryGold(context), width: 1.5),
      color: primaryGold(context).withOpacity(0.1),
    );
  }
}
