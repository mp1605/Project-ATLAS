import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Professional theme matching the HTML dashboard
class AppTheme {
  // Color Palette (matching Dashboard.html)
  static const primaryBlue = Color(0xFF3B82F6);
  static const primaryCyan = Color(0xFF06B6D4);
  static const accentGreen = Color(0xFF10B981);
  static const accentOrange = Color(0xFFF59E0B);
  static const accentRed = Color(0xFFEF4444);
  
  static const textWhite = Color(0xFFF8FAFC);
  static const textLight = Color(0xFFE2E8F0);
  static const textGray = Color(0xFF94A3B8);
  
  static const bgDark = Color(0xFF0F172A);
  static const bgDarker = Color(0xFF020617);
  static const bgCard = Color(0x801E293B);
  
  // Light Palette
  static const bgLight = Color(0xFFF8FAFC); // Slate-50
  static const bgLightSecondary = Color(0xFFF1F5F9); // Slate-100
  static const textBlack = Color(0xFF0F172A);
  static const textDarkGray = Color(0xFF475569);
  
  static const glassBg = Color(0x661E293B);
  static const glassBorder = Color(0x14FFFFFF);
  
  // Gradients
  static const darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E3A5F),
      Color(0xFF0F172A),
      Color(0xFF0A0E1A),
    ],
  );

  static const lightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF1F5F9),
      Color(0xFFF8FAFC),
      Colors.white,
    ],
  );
  
  static const cyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryCyan],
  );
  
  // Typography using Google Fonts
  static TextStyle get headingStyle => GoogleFonts.oswald(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
  );
  
  static TextStyle get titleStyle => GoogleFonts.oswald(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
  );
  
  static TextStyle get bodyStyle => GoogleFonts.roboto(
    fontSize: 14,
  );
  
  static TextStyle get captionStyle => GoogleFonts.roboto(
    fontSize: 12,
  );
  
  // Glass Card Decoration
  static BoxDecoration glassCard({Color? color}) => BoxDecoration(
    color: color ?? glassBg,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: glassBorder, width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 6,
        offset: const Offset(0, 4),
      ),
    ],
  );
  
  // Small Glass Card
  static BoxDecoration smallGlassCard({Color? color}) => BoxDecoration(
    color: color ?? glassBg,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: glassBorder, width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );
  
  // Input Field Decoration
  static InputDecoration inputDecoration({
    required String label,
    String? hint,
    Widget? prefix,
    Widget? suffix,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefix,
    suffixIcon: suffix,
    labelStyle: const TextStyle(color: textGray, fontSize: 14),
    hintStyle: const TextStyle(color: textGray, fontSize: 14),
    filled: true,
    fillColor: const Color(0x990F172A),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: glassBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: glassBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: primaryCyan, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: accentRed),
    ),
  );
  
  // Dark Theme Data
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryCyan,
    scaffoldBackgroundColor: bgDark,
    textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme).copyWith(
      headlineLarge: headingStyle.copyWith(color: textWhite),
      titleLarge: titleStyle.copyWith(color: textWhite),
      bodyLarge: bodyStyle.copyWith(color: textLight),
      bodyMedium: captionStyle.copyWith(color: textGray),
    ),
    colorScheme: const ColorScheme.dark(
      primary: primaryCyan,
      secondary: primaryBlue,
      surface: bgCard,
      onSurface: textWhite,
      error: accentRed,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: titleStyle.copyWith(color: textWhite),
      iconTheme: const IconThemeData(color: textWhite),
    ),
    cardTheme: CardThemeData(
      color: glassBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: glassBorder),
      ),
    ),
  );

  // Light Theme Data
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: bgLight,
    textTheme: GoogleFonts.robotoTextTheme(ThemeData.light().textTheme).copyWith(
      headlineLarge: headingStyle.copyWith(color: textBlack),
      titleLarge: titleStyle.copyWith(color: textBlack),
      bodyLarge: bodyStyle.copyWith(color: textBlack),
      bodyMedium: captionStyle.copyWith(color: textDarkGray),
    ),
    colorScheme: const ColorScheme.light(
      primary: primaryBlue,
      secondary: primaryCyan,
      surface: Colors.white,
      onSurface: textBlack,
      error: accentRed,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 1,
      centerTitle: false,
      titleTextStyle: titleStyle.copyWith(color: textBlack),
      iconTheme: const IconThemeData(color: textBlack),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: textGray.withOpacity(0.1)),
      ),
    ),
  );

  // Shorthand for backward compatibility (defaults to dark)
  static ThemeData get theme => darkTheme;
}
