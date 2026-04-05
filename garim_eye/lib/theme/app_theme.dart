import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF0B1221); // Deep almost-black blue
  static const Color surface = Color(0xFF151E32); // Lighter blue-gray
  static const Color primary = Color(0xFF00F0FF); // Cyan
  static const Color onPrimary = Colors.black;
  static const Color textPrimary = Color(0xFFE0E6ED);
  static const Color textSecondary = Color(0xFFA0AAB5);

  // Risk Colors
  static const Color riskLow = Color(0xFF00FF94); // Green
  static const Color riskMedium = Color(0xFFFF9900); // Orange
  static const Color riskHigh = Color(0xFFFF0055); // Red/Pink

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      ),
      iconTheme: const IconThemeData(color: textPrimary),
    );
  }
}
