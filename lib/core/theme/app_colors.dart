import 'package:flutter/material.dart';

/// Apple-inspired color palette for Love Cook
/// Clean, warm, and family-friendly colors
class AppColors {
  AppColors._();

  // Primary colors - warm orange tones for cooking/food theme
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryLight = Color(0xFFFF8F66);
  static const Color primaryDark = Color(0xFFFF7744);

  // Secondary colors - fresh green for health/ingredients
  static const Color secondary = Color(0xFF4CAF50);
  static const Color secondaryLight = Color(0xFF81C784);
  static const Color secondaryDark = Color(0xFF66BB6A);

  // Background colors - light mode
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color inputBackground = Color(0xFFF1F3F4);
  static const Color chipBackground = Color(0xFFF1F3F4);

  // Background colors - dark mode
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color inputBackgroundDark = Color(0xFF2C2C2C);

  // Text colors - light mode
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);

  // Text colors - dark mode
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textTertiaryDark = Color(0xFF808080);

  // Semantic colors
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF007AFF);

  static const Color successDark = Color(0xFF30D158);
  static const Color warningDark = Color(0xFFFFD60A);
  static const Color errorDark = Color(0xFFFF453A);
  static const Color infoDark = Color(0xFF0A84FF);

  // Border and divider
  static const Color border = Color(0xFFE5E5E5);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF3A3A3A);
  static const Color dividerDark = Color(0xFF3A3A3A);

  // Food category colors
  static const Color vegetable = Color(0xFF4CAF50);
  static const Color meat = Color(0xFFE57373);
  static const Color seafood = Color(0xFF4FC3F7);
  static const Color dairy = Color(0xFFFFF59D);
  static const Color grain = Color(0xFFFFCC80);
  static const Color fruit = Color(0xFFCE93D8);
  static const Color seasoning = Color(0xFFA1887F);
  static const Color other = Color(0xFF90A4AE);

  // Freshness indicator colors
  static const Color fresh = Color(0xFF4CAF50);
  static const Color normal = Color(0xFFFF9800);
  static const Color expiring = Color(0xFFFF5722);
  static const Color expired = Color(0xFFF44336);

  // Health tag colors
  static const Color healthTagDiabetes = Color(0xFF2196F3);
  static const Color healthTagHighBloodPressure = Color(0xFFE91E63);
  static const Color healthTagWeightLoss = Color(0xFF9C27B0);
  static const Color healthTagChildGrowth = Color(0xFFFF9800);
  static const Color healthTagPregnancy = Color(0xFFE91E63);
  static const Color healthTagVegetarian = Color(0xFF4CAF50);
}
