import 'package:flutter/material.dart';

/// App Colors - Centralized color definitions for light and dark modes
class AppColors {
  // Brand Colors
  static const Color brandPrimary = Color(0xFF0097A7); // Teal-blue from logo

  // Light Mode Colors
  static const LightColors light = LightColors();

  // Dark Mode Colors
  static const DarkColors dark = DarkColors();

  // Helper method to get theme-aware colors
  static AppThemeColors getThemeColors(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }
}

/// Light Mode Color Palette
class LightColors implements AppThemeColors {
  const LightColors();

  // Primary Colors
  @override
  Color get primary => AppColors.brandPrimary;
  @override
  Color get onPrimary => Colors.white;

  // Background Colors
  @override
  Color get background => const Color(0xFFF2F5F8); // Light gray background
  @override
  Color get surface => Colors.white;
  @override
  Color get surfaceVariant => const Color(0xFFF5F5F5);

  // Text Colors
  @override
  Color get textPrimary => const Color(0xFF1A1A1A); // Almost black
  @override
  Color get textSecondary => const Color(0xFF666666); // Medium gray
  @override
  Color get textTertiary => const Color(0xFF999999); // Light gray
  @override
  Color get textDisabled => const Color(0xFFCCCCCC);

  // Border Colors
  @override
  Color get border => const Color(0xFFE0E0E0);
  @override
  Color get borderLight => const Color(0xFFF0F0F0);
  @override
  Color get divider => const Color(0xFFE0E0E0);

  // Semantic Colors
  @override
  Color get success => const Color(0xFF4CAF50);
  @override
  Color get successLight => const Color(0xFFE8F5E9);
  @override
  Color get error => const Color(0xFFE53935);
  @override
  Color get errorLight => const Color(0xFFFFEBEE);
  @override
  Color get warning => const Color(0xFFFF9800);
  @override
  Color get warningLight => const Color(0xFFFFF3E0);
  @override
  Color get info => const Color(0xFF2196F3);
  @override
  Color get infoLight => const Color(0xFFE3F2FD);

  // UI Element Colors
  @override
  Color get shadow => Colors.black.withOpacity(0.1);
  @override
  Color get shadowLight => Colors.black.withOpacity(0.05);
  @override
  Color get overlay => Colors.black.withOpacity(0.5);

  // Icon Colors
  @override
  Color get iconPrimary => const Color(0xFF1A1A1A);
  @override
  Color get iconSecondary => const Color(0xFF666666);
  @override
  Color get iconDisabled => const Color(0xFFCCCCCC);

  // Input Colors
  @override
  Color get inputBackground => Colors.white;
  @override
  Color get inputBorder => const Color(0xFFE0E0E0);
  @override
  Color get inputBorderFocused => AppColors.brandPrimary;
  @override
  Color get inputPlaceholder => const Color(0xFF999999);
}

/// Dark Mode Color Palette
class DarkColors implements AppThemeColors {
  const DarkColors();

  // Primary Colors
  @override
  Color get primary => AppColors.brandPrimary;
  @override
  Color get onPrimary => Colors.white;

  // Background Colors
  @override
  Color get background => const Color(0xFF121212); // Dark background
  @override
  Color get surface => const Color(0xFF1E1E1E); // Card surface
  @override
  Color get surfaceVariant => const Color(0xFF2C2C2C);

  // Text Colors
  @override
  Color get textPrimary => Colors.white;
  @override
  Color get textSecondary => const Color(0xFFB0B0B0); // Light gray
  @override
  Color get textTertiary => const Color(0xFF808080); // Medium gray
  @override
  Color get textDisabled => const Color(0xFF555555);

  // Border Colors
  @override
  Color get border => const Color(0xFF3A3A3A);
  @override
  Color get borderLight => const Color(0xFF2A2A2A);
  @override
  Color get divider => const Color(0xFF3A3A3A);

  // Semantic Colors
  @override
  Color get success => const Color(0xFF66BB6A);
  @override
  Color get successLight => const Color(0xFF2E3A2E);
  @override
  Color get error => const Color(0xFFEF5350);
  @override
  Color get errorLight => const Color(0xFF3A2E2E);
  @override
  Color get warning => const Color(0xFFFFB74D);
  @override
  Color get warningLight => const Color(0xFF3A332E);
  @override
  Color get info => const Color(0xFF42A5F5);
  @override
  Color get infoLight => const Color(0xFF2E343A);

  // UI Element Colors
  @override
  Color get shadow => Colors.black.withOpacity(0.3);
  @override
  Color get shadowLight => Colors.black.withOpacity(0.2);
  @override
  Color get overlay => Colors.black.withOpacity(0.7);

  // Icon Colors
  @override
  Color get iconPrimary => Colors.white;
  @override
  Color get iconSecondary => const Color(0xFFB0B0B0);
  @override
  Color get iconDisabled => const Color(0xFF555555);

  // Input Colors
  @override
  Color get inputBackground => const Color(0xFF2C2C2C);
  @override
  Color get inputBorder => const Color(0xFF3A3A3A);
  @override
  Color get inputBorderFocused => AppColors.brandPrimary;
  @override
  Color get inputPlaceholder => const Color(0xFF808080);
}

/// Interface for theme-aware colors
abstract class AppThemeColors {
  // Primary
  Color get primary;
  Color get onPrimary;

  // Background
  Color get background;
  Color get surface;
  Color get surfaceVariant;

  // Text
  Color get textPrimary;
  Color get textSecondary;
  Color get textTertiary;
  Color get textDisabled;

  // Border
  Color get border;
  Color get borderLight;
  Color get divider;

  // Semantic
  Color get success;
  Color get successLight;
  Color get error;
  Color get errorLight;
  Color get warning;
  Color get warningLight;
  Color get info;
  Color get infoLight;

  // UI Elements
  Color get shadow;
  Color get shadowLight;
  Color get overlay;

  // Icons
  Color get iconPrimary;
  Color get iconSecondary;
  Color get iconDisabled;

  // Inputs
  Color get inputBackground;
  Color get inputBorder;
  Color get inputBorderFocused;
  Color get inputPlaceholder;
}
