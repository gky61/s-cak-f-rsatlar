import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Sıcak Fırsatlar - Canlı Turuncu Renk Paleti
  static const Color primary = Color(0xFFFF6B35); // Ana Turuncu
  static const Color secondary = Color(0xFFFF9F1C); // İkincil Turuncu
  static const Color accent = Color(0xFF2D3142); // Koyu Gri / Siyahımsı
  static const Color background = Color(0xFFF2F4F7); // Açık Gri Zemin
  static const Color surface = Colors.white; // Kart Zemini
  static const Color textPrimary = Color(0xFF1F2937); // Ana Metin
  static const Color textSecondary = Color(0xFF6B7280); // İkincil Metin
  static const Color success = Color(0xFF10B981); // Başarılı (Yeşil)
  static const Color error = Color(0xFFEF4444); // Hata (Kırmızı)

  static ThemeData get lightTheme {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: surface,
      background: background,
      error: error,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: baseColorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto', // Varsayılan font
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayMedium: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          height: 1.1,
          color: textPrimary,
        ),
        headlineMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.2,
          color: textPrimary,
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: textPrimary,
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: textSecondary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: accent,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      ),
    );
  }

  // Dark Theme Renkleri
  static const Color darkBackground = Color(0xFF121212); // Koyu Zemin
  static const Color darkSurface = Color(0xFF1E1E1E); // Koyu Kart Zemini
  static const Color darkTextPrimary = Color(0xFFE5E5E5); // Açık Metin
  static const Color darkTextSecondary = Color(0xFFB0B0B0); // İkincil Metin
  static const Color darkBorder = Color(0xFF2D2D2D); // Koyu Border

  static ThemeData get darkTheme {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      surface: darkSurface,
      background: darkBackground,
      error: error,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: baseColorScheme,
      scaffoldBackgroundColor: darkBackground,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayMedium: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          height: 1.1,
          color: darkTextPrimary,
        ),
        headlineMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.2,
          color: darkTextPrimary,
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: darkTextPrimary,
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: darkTextPrimary,
        ),
        bodyLarge: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: darkTextPrimary,
        ),
        bodyMedium: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: darkTextSecondary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: darkTextPrimary,
        ),
        iconTheme: IconThemeData(color: darkTextPrimary),
      ),
      cardTheme: CardTheme(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: darkBorder, width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurface,
        contentTextStyle: const TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primary,
        unselectedItemColor: darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      ),
      dividerColor: darkBorder,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
    );
  }
}
