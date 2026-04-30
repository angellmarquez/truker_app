import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primaryCyan = Color(0xFF38BDF8);
  static const deepNavy = Color(0xFF0F172A);
  static const surfaceSlate = Color(0xFF1E293B);
  static const borderSlate = Color(0xFF334155);
  static const textWhite = Colors.white;
  static const textMuted = Color(0xFF94A3B8);

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryCyan,
    scaffoldBackgroundColor: deepNavy,
    colorScheme: const ColorScheme.dark(
      primary: primaryCyan,
      surface: surfaceSlate,
      background: deepNavy,
      onSurface: textWhite,
    ),
    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        headlineLarge: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textWhite, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textWhite),
        bodyMedium: TextStyle(color: textMuted),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: deepNavy,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textWhite,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceSlate,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: borderSlate, width: 0.5),
      ),
      elevation: 4,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: deepNavy,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderSlate),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryCyan),
      ),
      labelStyle: const TextStyle(color: textMuted),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceSlate,
      selectedItemColor: primaryCyan,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
