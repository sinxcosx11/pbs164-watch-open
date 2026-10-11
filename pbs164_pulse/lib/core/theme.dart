import 'package:flutter/material.dart';

class PbsTheme {
  static const Color bgDark = Color(0xFF090D16);
  static const Color cardDark = Color(0xFF131A29);
  static const Color cardBorder = Color(0x1AFFFFFF);

  static const Color cyan = Color(0xFF00F2FE);
  static const Color electricBlue = Color(0xFF4FACFE);
  static const Color neonPink = Color(0xFFFF2A6D);
  static const Color neonGreen = Color(0xFF00F5A0);
  static const Color amber = Color(0xFFFFB300);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: cyan,
      colorScheme: const ColorScheme.dark(
        primary: cyan,
        secondary: electricBlue,
        surface: cardDark,
        error: neonPink,
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
