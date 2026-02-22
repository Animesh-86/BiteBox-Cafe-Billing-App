import 'package:flutter/material.dart';

/// Premium Dark Theme for Analytics
class AnalyticsTheme {
  // Background Colors (matching AppTheme)
  static const Color mainBackground = Color(
    0xFF141110,
  ); // Deep Roasted Coffee Black
  static const Color cardBackground = Color(
    0xFF1F1B1A,
  ); // Warm Dark Espresso Card

  // Accent Colors (matching AppTheme)
  static const Color primaryGold = Color(0xFFD4A574); // Gold / Latte
  static const Color secondaryBeige = Color(0xFF8D6E63); // Mocha

  // Chart Colors
  static const Color chartBlue = Color(0xFF6BB6FF);
  static const Color chartPurple = Color(0xFFB889FF);
  static const Color chartGreen = Color(0xFF7BD88F);
  static const Color chartAmber = Color(0xFFFFA726);
  static const Color chartRed = Color(0xFFEF5350);

  // Additional Chart Colors for variety
  static const List<Color> chartColors = [
    primaryGold,
    chartBlue,
    chartPurple,
    chartGreen,
    secondaryBeige,
    chartAmber,
  ];

  // Border and Glow (matching AppTheme)
  static Color borderColor = const Color(0xFF3E312B); // Coffee bean border
  static Color glowColor = primaryGold.withOpacity(0.2);

  // Text Colors (matching AppTheme)
  static const Color primaryText = Color(0xFFEAE0D5); // Creamy off-white text
  static Color secondaryText = const Color(
    0xFFDCC8B8,
  ).withOpacity(0.7); // Muted latte text

  // Card Styling
  static const double cardRadius = 20.0;
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);

  // Glassmorphism Card Decoration
  static BoxDecoration glassCard({bool selected = false}) {
    return BoxDecoration(
      color: cardBackground,
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(
        color: selected ? primaryGold : borderColor,
        width: selected ? 1.5 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: selected ? glowColor : Colors.black.withOpacity(0.3),
          blurRadius: selected ? 12 : 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Icon Container Decoration
  static BoxDecoration iconContainer({Color? color}) {
    return BoxDecoration(
      color: (color ?? primaryGold).withOpacity(0.15),
      shape: BoxShape.circle,
    );
  }

  // Drawer Item Decoration
  static BoxDecoration selectedDrawerItem() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: primaryGold, width: 1.5),
      color: primaryGold.withOpacity(0.1),
    );
  }
}
