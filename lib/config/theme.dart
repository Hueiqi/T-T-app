import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Indigo palette (Tailwind inspired)
  static const Color indigo50 = Color(0xFFEEF2FF);
  static const Color indigo100 = Color(0xFFE0E7FF);
  static const Color indigo200 = Color(0xFFC7D2FE);
  static const Color indigo300 = Color(0xFFA5B4FC);
  static const Color indigo400 = Color(0xFF818CF8);
  static const Color indigo500 = Color(0xFF6366F1);
  static const Color indigo600 = Color(0xFF4F46E5);

  static const Color primaryColor =indigo400;
  static const Color appBarColor = Color(0xFF9192F5); 
  static const Color secondaryColor = indigo600;
  static const Color accentColor = indigo300;
  static const Color backgroundColor = indigo50;
  static const Color darkBackground = Color(0xFF1E1B4B);
  static const Color cardColor = Colors.white;
  static const Color darkCardColor = Color(0xFF312E81);
  static const Color textPrimary = Color(0xFF1E1B4B);
  static const Color textSecondary = Color(0xFF6366F1);
  static const Color successColor = Color(0xFF059669);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor:Color(0xFF9192F5),
    scaffoldBackgroundColor: indigo50,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: cardColor,
      error: errorColor,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(
      ThemeData.light().textTheme,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color.fromARGB(255, 145, 146, 245),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: indigo200,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: darkCardColor,
      error: errorColor,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkCardColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: darkCardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkCardColor,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}
