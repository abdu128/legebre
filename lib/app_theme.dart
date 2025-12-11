import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primaryGreen = Color(0xFF0B8A48);
  static const Color secondaryGreen = Color(0xFF26C281);
  static const Color background = Color(0xFFF5F9F5);
  static const Color card = Colors.white;
  static const Color accentPurple = Color(0xFF7A5AF8);
  static const Color accentBlue = Color(0xFF2F89FC);
  static const Color accentRed = Color(0xFFFF3B57);
  static const Color accentOrange = Color(0xFFF8A541);
  static const Color deepBrown = Color(0xFF5C4B36);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryGreen,
      onPrimary: Colors.white,
      secondary: AppColors.secondaryGreen,
      onSecondary: Colors.white,
      error: AppColors.accentRed,
      onError: Colors.white,
      surface: AppColors.card,
      onSurface: const Color(0xFF1A1C18),
      surfaceContainerHighest: const Color(0xFFE8EFE6),
      onSurfaceVariant: const Color(0xFF40473E),
      outline: const Color(0xFFB3C1B2),
      shadow: Colors.black.withValues(alpha: .08),
      scrim: Colors.black54,
      inverseSurface: const Color(0xFF2F322B),
      inversePrimary: AppColors.secondaryGreen,
      tertiary: AppColors.accentPurple,
      onTertiary: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.background,
    textTheme: GoogleFonts.poppinsTextTheme(
      const TextTheme(
        displaySmall: TextStyle(fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF40514E)),
        bodySmall: TextStyle(fontSize: 12, color: Color(0xFF6C7A76)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.deepBrown,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: AppColors.primaryGreen.withValues(alpha: .25),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.background,
      selectedColor: AppColors.primaryGreen.withValues(alpha: .15),
      labelStyle: const TextStyle(color: AppColors.deepBrown),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: AppColors.primaryGreen,
      unselectedItemColor: Color(0xFFADBAAE),
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 12,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: StadiumBorder(),
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
    ),
  );
}
