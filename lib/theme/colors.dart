import 'package:flutter/material.dart';

/// Asli Brand Kit Colors
/// Primary: University Maroon (#A9523C)
/// Based on official logo and institutional identity
class AsliColors {
  // Primary Brand Colors
  static const Color primaryMaroon = Color(0xFFA9523C);
  static const Color heritageBrown = Color(0xFF391F1E);
  
  // Secondary Colors
  static const Color stoneBrown = Color(0xFF665D5A);
  static const Color warmSand = Color(0xFFB5987F);
  
  // Neutrals
  static const Color offWhite = Color(0xFFFEFEFE);
  static const Color lightAsh = Color(0xFFDDCFC9);

  // ==================== BRAND ACCENT PALETTE ====================
  // Warm tones (derived from maroon family)
  static const Color accentTerracotta = Color(0xFFC4704A);  // Lighter maroon
  static const Color accentAmber = Color(0xFFD4915C);        // Warm amber
  static const Color accentRust = Color(0xFF8B4513);         // Deep rust
  static const Color accentCoral = Color(0xFFCB6D51);        // Soft coral
  static const Color accentSienna = Color(0xFF926247);       // Burnt sienna

  // Cool tones (brand-complementary)
  static const Color accentTeal = Color(0xFF3D7A73);         // Heritage teal
  static const Color accentSlate = Color(0xFF556B7A);        // Cool slate
  static const Color accentIndigo = Color(0xFF5C5080);       // Muted indigo
  static const Color accentSage = Color(0xFF6B7F5E);         // Earthy sage
  static const Color accentPlum = Color(0xFF7A4E6B);         // Warm plum

  // Status colors (brand-tinted)
  static const Color statusSuccess = Color(0xFF5A8A5C);      // Olive green
  static const Color statusError = Color(0xFFC44A3D);        // Warm red
  static const Color statusInfo = Color(0xFF4A7A8C);         // Steel blue
  static const Color statusWarning = Color(0xFFCC8A3E);      // Amber gold

  // ==================== DARK MODE PALETTE ====================
  static const Color darkBg = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2A2A2A);
  static const Color darkBorder = Color(0xFF3A3A3A);
  static const Color darkText = Color(0xFFE8E0DC);
  static const Color darkSubtext = Color(0xFF9E9490);
  static const Color darkMaroon = Color(0xFFCF7A64);  // Brighter maroon for dark bg
}

/// Build light theme
ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AsliColors.primaryMaroon,
      secondary: AsliColors.warmSand,
      surface: AsliColors.offWhite,
      surfaceContainerHighest: AsliColors.lightAsh,
      onPrimary: Colors.white,
      onSecondary: AsliColors.heritageBrown,
      onSurface: AsliColors.heritageBrown,
    ),
    scaffoldBackgroundColor: AsliColors.offWhite,
    cardColor: Colors.white,
    dividerColor: AsliColors.lightAsh,
    appBarTheme: const AppBarTheme(
      backgroundColor: AsliColors.primaryMaroon,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AsliColors.offWhite,
      indicatorColor: AsliColors.primaryMaroon.withAlpha(40),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: AsliColors.primaryMaroon, fontWeight: FontWeight.w600, fontSize: 12);
        }
        return const TextStyle(color: AsliColors.stoneBrown, fontSize: 12);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AsliColors.primaryMaroon);
        }
        return const IconThemeData(color: AsliColors.stoneBrown);
      }),
    ),
  );
}

/// Build dark theme  
ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: AsliColors.darkMaroon,
      secondary: AsliColors.warmSand,
      surface: AsliColors.darkSurface,
      surfaceContainerHighest: AsliColors.darkBorder,
      onPrimary: Colors.white,
      onSecondary: AsliColors.darkText,
      onSurface: AsliColors.darkText,
    ),
    scaffoldBackgroundColor: AsliColors.darkBg,
    cardColor: AsliColors.darkCard,
    dividerColor: AsliColors.darkBorder,
    appBarTheme: AppBarTheme(
      backgroundColor: AsliColors.darkSurface,
      foregroundColor: AsliColors.darkText,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AsliColors.darkSurface,
      indicatorColor: AsliColors.darkMaroon.withAlpha(40),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: AsliColors.darkMaroon, fontWeight: FontWeight.w600, fontSize: 12);
        }
        return const TextStyle(color: AsliColors.darkSubtext, fontSize: 12);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AsliColors.darkMaroon);
        }
        return const IconThemeData(color: AsliColors.darkSubtext);
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AsliColors.darkCard,
      contentTextStyle: const TextStyle(color: AsliColors.darkText),
    ),
  );
}
