import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const teal = Color(0xFF02A1B4);
  static const deepTeal = Color(0xFF087D89);
  static const aqua = Color(0xFF00B3CA);
  static const coral = Color(0xFFFF8A78);
  static const peach = Color(0xFFFFF0E9);
  static const mint = Color(0xFFE5F6F1);
  static const sky = Color(0xFFEAF4FF);
  static const lavender = Color(0xFFF0EDFF);
  static const ink = Color(0xFF18383D);
  static const muted = Color(0xFF71878C);
  static const canvas = Color(0xFFF5F9F9);
  static const line = Color(0xFFE6EEEE);
  static const gold = Color(0xFFFFB547);
  static const red = Color(0xFFE66A6A);
  static const green = Color(0xFF2E9D78);
}

class AppTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final surface = isDark
        ? const Color(0xFF172A2E)
        : Colors.white;

    final canvas = isDark
        ? const Color(0xFF101F23)
        : AppColors.canvas;

    final ink = isDark
        ? const Color(0xFFE7F1F2)
        : AppColors.ink;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: brightness,
      primary: AppColors.teal,
      secondary: AppColors.coral,
      surface: surface,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      cardColor: surface,
    );

    return base.copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: ink,
        displayColor: ink,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
      ),

      dividerColor: isDark
          ? const Color(0xFF2B4146)
          : AppColors.line,

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? const Color(0xFF20363B)
            : const Color(0xFFF7FAFA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: GoogleFonts.poppins(
          color: AppColors.muted,
          fontSize: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF2B4146)
                : AppColors.line,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF2B4146)
                : AppColors.line,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: AppColors.teal,
            width: 1.5,
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}