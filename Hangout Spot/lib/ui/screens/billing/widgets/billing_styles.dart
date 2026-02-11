import 'package:flutter/material.dart';

Color billingSurface(BuildContext context, {double darkOpacity = 0.08}) {
  final theme = Theme.of(context);
  // Premium Dark Coffee Surface (Matches AppTheme._surface 0xFF1F1B1A but slightly lighter)
  return theme.brightness == Brightness.dark
      ? const Color(0xFF2A2422).withOpacity(darkOpacity + 0.15)
      : theme.colorScheme.surface;
}

Color billingSurfaceVariant(BuildContext context, {double darkOpacity = 0.12}) {
  final theme = Theme.of(context);
  // Premium Lighter Coffee Surface
  return theme.brightness == Brightness.dark
      ? const Color(0xFF352D2B).withOpacity(darkOpacity + 0.2)
      : theme.colorScheme.surfaceVariant;
}

Color billingOutline(BuildContext context, {double darkOpacity = 0.2}) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? const Color(0xFF5D4037).withOpacity(0.3) // Warm coffee outline
      : theme.colorScheme.outline.withOpacity(0.6);
}

Color billingText(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

Color billingMutedText(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

Widget billingPricePill(BuildContext context, String text) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final caramel = isDark
      ? const Color(0xFFEDAD4C) // Golden Caramel
      : const Color(0xFFEDAD4C);
  final coffeeDark = isDark
      ? const Color(0xFF2C1A1D) // Contrast text
      : const Color(0xFF98664D);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [caramel.withOpacity(0.4), caramel.withOpacity(0.2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: caramel.withOpacity(0.3), width: 0.5),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: isDark ? const Color(0xFFFFE0B2) : coffeeDark,
      ),
    ),
  );
}

List<BoxShadow> billingShadow(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return [
    BoxShadow(
      color: isDark
          ? Colors.black.withOpacity(0.4)
          : Colors.black.withOpacity(0.08),
      blurRadius: isDark ? 24 : 18,
      offset: const Offset(0, 12),
    ),
  ];
}
