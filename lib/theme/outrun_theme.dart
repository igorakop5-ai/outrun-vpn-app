import 'package:flutter/material.dart';

class OutrunTheme {
  // Brand Palette (Synthwave / Outrun aesthetic)
  static const Color background = Color(0xFF0C0A17);
  static const Color surface = Color(0xFF161327);
  static const Color surfaceLight = Color(0xFF221E3B);
  
  static const Color neonPink = Color(0xFFFF2A85);
  static const Color neonCyan = Color(0xFF00F0FF);
  static const Color neonPurple = Color(0xFFA855F7);
  static const Color neonGreen = Color(0xFF00FF9D);
  static const Color neonAmber = Color(0xFFFFB800);
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9AA7);
  static const Color textMuted = Color(0xFF5A5666);
  
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: neonPink,
      colorScheme: const ColorScheme.dark(
        primary: neonPink,
        secondary: neonCyan,
        surface: surface,
      ),
      fontFamily: 'sans-serif',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: surfaceLight.withValues(alpha: 0.6), width: 1),
        ),
      ),
    );
  }

  // Glow BoxShadow generator
  static List<BoxShadow> neonGlow(Color color, {double intensity = 1.0}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.35 * intensity),
        blurRadius: 28 * intensity,
        spreadRadius: 4 * intensity,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.2 * intensity),
        blurRadius: 60 * intensity,
        spreadRadius: 10 * intensity,
      ),
    ];
  }
}
