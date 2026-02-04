import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Typography - Outfit for a modern, clean look
  static final TextTheme _textTheme = GoogleFonts.outfitTextTheme();

  // Midnight Coffee Palette
  static const Color _background = Color(0xFF0F0F0F); // Deepest Black
  static const Color _surface = Color(0xFF1E1E1E); // Dark Grey Card
  static const Color _primary = Color(0xFFD4A574); // Gold / Latte
  static const Color _secondary = Color(0xFF8D6E63); // Mocha
  static const Color _onBackground = Color(0xFFEDEDED); // Off-white text
  static const Color _onSurface = Color(0xFFE0E0E0); // Light grey text
  static const Color _borderColor = Color(0xFF333333); // Subtle borders

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _background,
    colorScheme: const ColorScheme.dark(
      primary: _primary,
      secondary: _secondary,
      surface: _surface,
      background: _background,
      onPrimary: Colors.black, // Text on Gold should be black
      onSecondary: Colors.white,
      onSurface: _onSurface,
      onBackground: _onBackground,
    ),
    textTheme: _textTheme.apply(
      bodyColor: _onBackground,
      displayColor: _onBackground,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _background,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: _textTheme.headlineSmall?.copyWith(
        color: _primary, // Gold titles
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
      iconTheme: const IconThemeData(color: _primary),
    ),
    cardTheme: CardThemeData(
      color: _surface,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _borderColor, width: 1),
      ),
      margin: const EdgeInsets.all(8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.black, // Dark text on gold button
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        side: const BorderSide(color: _primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2C), // Slightly lighter input bg
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: Color(0xFF9E9E9E)),
      hintStyle: const TextStyle(color: Color(0xFF757575)),
      prefixIconColor: _primary,
    ),
    iconTheme: const IconThemeData(color: _primary),
    dividerTheme: const DividerThemeData(color: _borderColor, thickness: 1),
    listTileTheme: ListTileThemeData(
      iconColor: _primary,
      textColor: _onSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _primary;
        return Colors.grey.shade400;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected))
          return _primary.withOpacity(0.5);
        return Colors.grey.shade800;
      }),
      overlayColor: WidgetStateProperty.all(_primary.withOpacity(0.1)),
    ),
  );
  // Light Coffee Palette (Premium)
  static const Color _lightBackground = Color(0xFFFEF9F5); // Cream
  static const Color _lightSurface = Color(0xFFFFF3E8); // Soft card surface
  static const Color _lightOnBackground = Color(0xFF3B2A22); // Coffee text
  static const Color _lightOnSurface = Color(0xFF5A3F32); // Muted coffee
  static const Color _lightBorderColor = Color(0xFFE7D6C9); // Warm border

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _lightBackground,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF95674D), // Coffee
      secondary: Color(0xFFEDAD4C), // Caramel
      surface: _lightSurface,
      background: _lightBackground,
      onPrimary: Colors.white,
      onSecondary: Color(0xFF3B2A22),
      onSurface: _lightOnSurface,
      onBackground: _lightOnBackground,
    ),
    textTheme: _textTheme.apply(
      bodyColor: _lightOnBackground,
      displayColor: _lightOnBackground,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _lightBackground,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: _textTheme.headlineSmall?.copyWith(
        color: const Color(0xFF95674D),
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
      iconTheme: const IconThemeData(color: Color(0xFF95674D)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _lightSurface,
      selectedItemColor: const Color(0xFF95674D),
      unselectedItemColor: const Color(0xFF98664D),
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    cardTheme: CardThemeData(
      color: _lightSurface,
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _lightBorderColor, width: 1),
      ),
      margin: const EdgeInsets.all(8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF95674D),
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF95674D),
        side: const BorderSide(color: Color(0xFF95674D), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFF3E8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _lightBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _lightBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF95674D), width: 1.5),
      ),
      labelStyle: const TextStyle(color: Color(0xFF7A5A4A)),
      hintStyle: const TextStyle(color: Color(0xFF9A7B6B)),
      prefixIconColor: const Color(0xFF95674D),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF95674D)),
    dividerTheme: const DividerThemeData(
      color: _lightBorderColor,
      thickness: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: const Color(0xFF95674D),
      textColor: _lightOnSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected))
          return const Color(0xFF95674D);
        return Colors.grey.shade400;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected))
          return const Color(0xFF95674D).withOpacity(0.4);
        return Colors.grey.shade300;
      }),
      overlayColor: WidgetStateProperty.all(
        const Color(0xFF95674D).withOpacity(0.1),
      ),
    ),
  );
}
