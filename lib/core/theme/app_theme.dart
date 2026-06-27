import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  // Brand color scheme: Deep Navy, Teal, and Warm Gold
  static const Color primaryLight = Color(0xFF0F172A); // Slate 900
  static const Color primaryDark = Color(0xFFF8FAFC); // Slate 50
  
  static const Color accentColor = Color(0xFFFF7B00); // Brand Orange
  static const Color secondaryColor = Color(0xFF4F46E5); // Indigo Accent

  static const Color bgLight = Color(0xFFF8FAFC); // Clean off-white
  static const Color bgDark = Color(0xFF090D16); // Deep premium dark background

  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF131B2E); // Deep Navy slate card

  static ThemeData getTheme(String langCode, bool isDark) {
    final textTheme = _getTextTheme(langCode, isDark);
    final baseScheme = isDark
        ? ColorScheme.dark(
            primary: primaryDark,
            secondary: accentColor,
            tertiary: secondaryColor,
            background: bgDark,
            surface: cardDark,
            onPrimary: primaryLight,
            onBackground: Colors.white,
            onSurface: const Color(0xFFE2E8F0),
          )
        : ColorScheme.light(
            primary: primaryLight,
            secondary: accentColor,
            tertiary: secondaryColor,
            background: bgLight,
            surface: cardLight,
            onPrimary: Colors.white,
            onBackground: const Color(0xFF1E293B),
            onSurface: const Color(0xFF334155),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: isDark ? bgDark : bgLight,
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: accentColor.withOpacity(0.4),
        selectionHandleColor: accentColor,
        cursorColor: accentColor,
      ),
      cardTheme: CardThemeData(
        color: isDark ? cardDark : cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? bgDark : bgLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: isDark ? Colors.white : primaryLight),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : primaryLight,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? cardDark : cardLight,
        selectedItemColor: accentColor,
        unselectedItemColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
      ),
      buttonTheme: const ButtonThemeData(
        buttonColor: accentColor,
        textTheme: ButtonTextTheme.primary,
      ),
      textTheme: textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: accentColor,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  static TextTheme _getTextTheme(String langCode, bool isDark) {
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (langCode == 'ku' || langCode == 'ar') {
      // Premium Arabic/Kurdish Font from Google (Vazirmatn perfectly supports Sorani Kurdish letters and ligatures)
      return GoogleFonts.vazirmatnTextTheme().copyWith(
        displayLarge: GoogleFonts.vazirmatn(color: textColor, fontWeight: FontWeight.bold, fontSize: 32),
        displayMedium: GoogleFonts.vazirmatn(color: textColor, fontWeight: FontWeight.bold, fontSize: 28),
        titleLarge: GoogleFonts.vazirmatn(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
        titleMedium: GoogleFonts.vazirmatn(color: textColor, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: GoogleFonts.vazirmatn(color: textColor, fontSize: 16, height: 1.6),
        bodyMedium: GoogleFonts.vazirmatn(color: subColor, fontSize: 14, height: 1.5),
        labelLarge: GoogleFonts.vazirmatn(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
      );
    } else {
      // Modern English Font
      return GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 32),
        displayMedium: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 28),
        titleLarge: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 22),
        titleMedium: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w600, fontSize: 18),
        bodyLarge: GoogleFonts.outfit(color: textColor, fontSize: 16, height: 1.5),
        bodyMedium: GoogleFonts.outfit(color: subColor, fontSize: 14, height: 1.4),
        labelLarge: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
      );
    }
  }
}

class AppThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  AppThemeProvider() {
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    notifyListeners();
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
  }
}
