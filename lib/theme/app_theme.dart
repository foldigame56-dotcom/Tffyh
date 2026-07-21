import 'package:flutter/material.dart';

/// Единая тема приложения — тёмно-синяя с градиентом, в цветах логотипа
/// (глубокий тёмно-синий фон, электрик-блю акцент, золотистые глаза кота
/// как редкий акцентный цвет для важных элементов).
class AppTheme {
  static const Color deepNavy = Color(0xFF060B18);
  static const Color navy = Color(0xFF0B1220);
  static const Color surface = Color(0xFF121B2E);
  static const Color surfaceLight = Color(0xFF1B2740);
  static const Color electricBlue = Color(0xFF3B82F6);
  static const Color cyan = Color(0xFF38BDF8);
  static const Color gold = Color(0xFFFFC857);
  static const Color connectedGreen = Color(0xFF34D399);
  static const Color danger = Color(0xFFEF4444);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [deepNavy, navy, Color(0xFF0A1428)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [electricBlue, cyan],
  );

  static const LinearGradient connectedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), connectedGreen],
  );

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navy,
      colorScheme: ColorScheme.fromSeed(
        seedColor: electricBlue,
        brightness: Brightness.dark,
        surface: surface,
        secondary: gold,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: surfaceLight, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cyan, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: electricBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      dividerColor: surfaceLight,
    );
  }
}
