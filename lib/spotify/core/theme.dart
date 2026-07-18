import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Spotify's color palette (approximated from the real app).
class SpotifyColors {
  SpotifyColors._();

  /// Primary brand green (the modern, brighter green).
  static const Color green = Color(0xFF1ED760);
  static const Color greenDark = Color(0xFF1DB954);

  /// Backgrounds.
  static const Color black = Color(0xFF000000);
  static const Color base = Color(0xFF121212);
  static const Color surface = Color(0xFF181818);
  static const Color elevated = Color(0xFF282828);
  static const Color highlight = Color(0xFF1A1A1A);

  /// Text.
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF6A6A6A);

  /// Misc.
  static const Color card = Color(0xFF181818);
  static const Color cardHover = Color(0xFF282828);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.montserratTextTheme(base.textTheme).apply(
      bodyColor: SpotifyColors.textPrimary,
      displayColor: SpotifyColors.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: SpotifyColors.base,
      canvasColor: SpotifyColors.base,
      colorScheme: base.colorScheme.copyWith(
        primary: SpotifyColors.green,
        secondary: SpotifyColors.green,
        surface: SpotifyColors.surface,
        onPrimary: SpotifyColors.black,
        onSurface: SpotifyColors.textPrimary,
        brightness: Brightness.dark,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: SpotifyColors.textPrimary,
        centerTitle: false,
      ),
      iconTheme: const IconThemeData(color: SpotifyColors.textPrimary),
      dividerColor: SpotifyColors.elevated,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: SpotifyColors.textPrimary,
        inactiveTrackColor: SpotifyColors.textTertiary,
        thumbColor: SpotifyColors.textPrimary,
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: SpotifyColors.black,
        selectedItemColor: SpotifyColors.textPrimary,
        unselectedItemColor: SpotifyColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: SpotifyColors.elevated,
        contentTextStyle: TextStyle(color: SpotifyColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
