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
  static const bgCard = Color(0x801E293B); // rgba(30, 41, 59, 0.7)
  
  static const glassBg = Color(0x661E293B); // rgba(30, 41, 59, 0.4)
  static const glassBorder = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)
  
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
    color: textWhite,
  );
  
  static TextStyle get titleStyle => GoogleFonts.oswald(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: textWhite,
  );
  
  static TextStyle get bodyStyle => GoogleFonts.roboto(
    fontSize: 14,
    color: textLight,
  );
  
  static TextStyle get captionStyle => GoogleFonts.roboto(
    fontSize: 12,
    color: textGray,
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
    fillColor: const Color(0x990F172A), // rgba(15, 23, 42, 0.6)
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
  
  // Primary Button Style
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: textWhite,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    elevation: 0,
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
  
  // Secondary Button Style
  static ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: glassBg,
    foregroundColor: textWhite,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: glassBorder),
    ),
    elevation: 0,
  );
  
  // Full Theme Data
  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryCyan,
    scaffoldBackgroundColor: bgDark,
    textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme).copyWith(
      headlineLarge: headingStyle,
      titleLarge: titleStyle,
      bodyLarge: bodyStyle,
      bodyMedium: captionStyle,
    ),
    colorScheme: const ColorScheme.dark(
      primary: primaryCyan,
      secondary: primaryBlue,
      surface: bgCard,
      error: accentRed,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: titleStyle,
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
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: primaryButtonStyle,
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: const TextStyle(color: textGray),
      hintStyle: const TextStyle(color: textGray),
      filled: true,
      fillColor: const Color(0x990F172A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: glassBorder),
      ),
    ),
  );
}
