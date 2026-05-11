import 'package:flutter/material.dart';
import 'colors.dart';

/// Extension on BuildContext for easy theme-aware color access
/// Usage: context.cardBg, context.textPrimary, context.borderColor, etc.
extension AsliTheme on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  
  // Backgrounds
  Color get pageBg => isDark ? AsliColors.darkBg : AsliColors.offWhite;
  Color get cardBg => isDark ? AsliColors.darkCard : Colors.white;
  Color get surfaceBg => isDark ? AsliColors.darkSurface : AsliColors.offWhite;
  
  // Text
  Color get textPrimary => isDark ? AsliColors.darkText : AsliColors.heritageBrown;
  Color get textSecondary => isDark ? AsliColors.darkSubtext : AsliColors.stoneBrown;
  
  // Borders
  Color get borderColor => isDark ? AsliColors.darkBorder : AsliColors.lightAsh;
  
  // Brand accent
  Color get accent => isDark ? AsliColors.darkMaroon : AsliColors.primaryMaroon;
  
  // Input fields
  Color get inputFill => isDark ? AsliColors.darkSurface : AsliColors.lightAsh.withAlpha(100);
}
