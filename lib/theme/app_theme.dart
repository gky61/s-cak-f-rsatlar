import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Modern & Energetic - Renk Paleti
  static const Color primary = Color(0xFFFF6B35); // Vibrant Orange (Action/Highlight)
  static const Color secondary = Color(0xFF004E92); // Deep Ocean Blue (Brand/Trust)
  static const Color accent = Color(0xFF2D3436); // Dark Charcoal (Legacy support)
  static const Color background = Color(0xFFF8F9FA); // Soft White/Light Grey
  static const Color surface = Color(0xFFFFFFFF); // White (Card Background)
  static const Color textPrimary = Color(0xFF2D3436); // Dark Charcoal
  static const Color textSecondary = Color(0xFF636E72); // Grey
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

    // Türkçe karakter desteği için Google Fonts'tan Roboto kullan
    final textTheme = GoogleFonts.robotoTextTheme();
    
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: baseColorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: GoogleFonts.roboto().fontFamily, // Türkçe karakter desteği için
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        displayMedium: GoogleFonts.roboto(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          height: 1.1,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.roboto(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.2,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.roboto(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.roboto(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.roboto(
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: textSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        foregroundColor: textPrimary,
        titleTextStyle: GoogleFonts.roboto(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
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
          textStyle: GoogleFonts.roboto(
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
          textStyle: GoogleFonts.roboto(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: accent,
        contentTextStyle: GoogleFonts.roboto(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.roboto(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500, fontSize: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: secondary,
        labelStyle: GoogleFonts.roboto(color: textPrimary),
        secondaryLabelStyle: GoogleFonts.roboto(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: GoogleFonts.roboto(color: textSecondary),
        hintStyle: GoogleFonts.roboto(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
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

    // Türkçe karakter desteği için Google Fonts'tan Roboto kullan
    final textThemeDark = GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme);
    
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: baseColorScheme,
      scaffoldBackgroundColor: darkBackground,
      fontFamily: GoogleFonts.roboto().fontFamily, // Türkçe karakter desteği için
    );

    return base.copyWith(
      textTheme: textThemeDark.copyWith(
        displayMedium: GoogleFonts.roboto(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          height: 1.1,
          color: darkTextPrimary,
        ),
        headlineMedium: GoogleFonts.roboto(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.2,
          color: darkTextPrimary,
        ),
        titleLarge: GoogleFonts.roboto(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: darkTextPrimary,
        ),
        titleMedium: GoogleFonts.roboto(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: darkTextPrimary,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: darkTextPrimary,
        ),
        bodyMedium: GoogleFonts.roboto(
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: darkTextSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        titleTextStyle: GoogleFonts.roboto(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: darkTextPrimary,
        ),
        iconTheme: const IconThemeData(color: darkTextPrimary),
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
          textStyle: GoogleFonts.roboto(
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
          textStyle: GoogleFonts.roboto(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurface,
        contentTextStyle: GoogleFonts.roboto(
          color: darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primary,
        unselectedItemColor: darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.roboto(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500, fontSize: 12),
      ),
      dividerColor: darkDivider,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceElevated,
        labelStyle: GoogleFonts.roboto(color: darkTextSecondary),
        hintStyle: GoogleFonts.roboto(color: darkTextSecondary),
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
        selectedColor: secondary,
        labelStyle: GoogleFonts.roboto(color: darkTextPrimary),
        secondaryLabelStyle: GoogleFonts.roboto(color: Colors.white),
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
