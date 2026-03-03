import 'dart:math';
import 'package:flutter/material.dart';

/// Central responsive utility used across the entire application.
///
/// Follows the same strategy as Instagram / WhatsApp:
///  • Respect the user's OS font-size preference (accessibility).
///  • Clamp it to a sensible maximum so layouts never overflow.
///  • Apply a small device-class boost for readability on tablets.
///  • Provide helpers for adaptive padding, icon sizes, etc.
class ResponsiveLayout {
  // ── Viewport breakpoints ────────────────────────────────────────
  static const double mobileLimit = 600.0;
  static const double tabletLimit = 900.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileLimit;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= mobileLimit && w < tabletLimit;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletLimit;

  // ── Text Scale ──────────────────────────────────────────────────
  // Max scale factor we allow regardless of OS accessibility setting.
  // Instagram/WhatsApp cap at ~1.3; we use the same.
  static const double _maxTextScale = 1.3;

  // Small bump added on larger screens so POS text isn't tiny at arm's length.
  static const double _tabletBoost = 1.05;
  static const double _desktopBoost = 1.10;

  /// Computes the effective text-scale factor for the current device.
  ///
  /// Formula:
  ///   clamp(osScale, 0.8, _maxTextScale) × deviceBoost
  ///
  /// This means:
  ///  • A user who sets "Small font" (0.85) keeps their preference.
  ///  • A user who goes to "Largest" (1.5 on some Samsung phones) gets
  ///    capped at 1.3 so nothing overflows.
  ///  • On tablets, a small 5 % boost is added for POS readability.
  static double clampedTextScale(BuildContext context) {
    final osScale = MediaQuery.of(context).textScaler.scale(1.0);
    final clamped = osScale.clamp(0.8, _maxTextScale);

    final width = MediaQuery.of(context).size.width;
    double boost = 1.0;
    if (width >= tabletLimit) {
      boost = _desktopBoost;
    } else if (width >= mobileLimit) {
      boost = _tabletBoost;
    }

    // Final value is still capped at _maxTextScale so the boost never
    // pushes past the ceiling.
    return min(clamped * boost, _maxTextScale);
  }

  // ── Adaptive helpers ────────────────────────────────────────────

  /// Horizontal page padding that tightens on small phones.
  static double pagePadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 12; // very small phones (Galaxy A01, etc.)
    if (w < mobileLimit) return 16;
    if (w < tabletLimit) return 20;
    return 24;
  }

  /// Icon size that respects screen density without going too large.
  static double iconSize(BuildContext context, {double base = 24}) {
    final scale = MediaQuery.of(context).devicePixelRatio;
    // Normalize: most devices are 2–3× density.  We only nudge up
    // a bit on very-high-density or tablet screens.
    if (scale > 3.5) return base * 1.1;
    return base;
  }

  // ── Legacy shim (used in existing code) ─────────────────────────
  /// @deprecated — use [clampedTextScale] instead.
  static double textScaleFactor(BuildContext context) =>
      clampedTextScale(context);
}
