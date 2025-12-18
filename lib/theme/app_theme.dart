import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // FIRSAT KOLİK - Renk Paleti
  static const Color primary = Color(0xFFF9F506); // Varsayılan: Sarı
  static const Color accent = Color(0xFF2D3142); // Koyu Gri / Siyahımsı
  static const Color background = Color(0xFFF8F8F5); // Açık Zemin (#f8f8f5)
  static const Color surface = Colors.white; // Kart Zemini (#ffffff)
  static const Color textPrimary = Color(0xFF181811); // Ana Metin (#181811)
  static const Color textSecondary = Color(0xFF8C8B5F); // İkincil Metin (#8c8b5f)
  static const Color success = Color(0xFF10B981); // Başarılı (Yeşil)
  static const Color error = Color(0xFFEF4444); // Hata (Kırmızı)

  static ThemeData getLightTheme() {
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
      // Sistem fontunu kullan (Türkçe karakter desteği için)
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
          borderRadius: BorderRadius.circular(24), // rounded-2xl (24px)
          side: BorderSide(color: Colors.black.withOpacity(0.05), width: 2), // ring-2 ring-black/5
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
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      ),
    );
  }

  // Backward compatibility
  static ThemeData get lightTheme => getLightTheme();

  // Dark Theme Renkleri - HTML tasarımından
  static const Color darkBackground = Color(0xFF23220F); // Koyu zemin (#23220f)
  static const Color darkSurface = Color(0xFF23231A); // Koyu Kart Zemini (#23231a)
  static const Color darkSurfaceElevated = Color(0xFF2C2C1E); // Yükseltilmiş yüzeyler için
  static const Color darkTextPrimary = Colors.white; // Daha açık metin
  static const Color darkTextSecondary = Color(0xFF8C8B5F); // İkincil Metin
  static const Color darkBorder = Color(0xFF333333); // Daha belirgin border
  static const Color darkDivider = Color(0xFF2A2A2A); // Divider rengi

  static ThemeData getDarkTheme() {
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
      // Sistem fontunu kullan
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
          side: const BorderSide(color: darkBorder, width: 2), // Daha belirgin border
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
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      ),
      dividerColor: darkDivider,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceElevated,
        labelStyle: const TextStyle(color: darkTextSecondary),
        hintStyle: const TextStyle(color: darkTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceElevated,
        selectedColor: primary.withOpacity(0.2),
        labelStyle: const TextStyle(color: darkTextPrimary),
        secondaryLabelStyle: const TextStyle(color: darkTextPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorder, width: 2),
        ),
      ),
    );
  }
  
  // Backward compatibility
  static ThemeData get darkTheme => getDarkTheme();
}
