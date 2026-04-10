import 'package:flutter/material.dart';

/// App Colors - Centralized color definitions matching TruePay dark fintech landing page
class AppColors {
  // Brand Primary - Dark teal matching TruePay logo (shield color)
  static const Color brandCyan = Color(0xFF26A69A); // Dark teal #26A69A - matches logo shield color
  static const Color brandPrimary = Color(0xFF26A69A); // Dark teal - primary brand accent matching logo
  static const Color brandPrimaryAlt = Color(0xFF00897B); // Darker teal variant
  static const Color brandPrimaryDark = Color(0xFF00796B); // Darkest teal for pressed states
  
  // Background - Deep navy/charcoal for premium dark theme
  static const Color backgroundDeepNavy = Color(0xFF0F172A); // Main background #0F172A
  static const Color backgroundCharcoal = Color(0xFF111827); // Alternative charcoal #111827
  
  // Surface - Elevated dark surfaces for cards, dialogs
  static const Color surfaceDark = Color(0xFF1E293B); // Slate-800 #1E293B - cards, bottom sheets
  static const Color surfaceVariantDark = Color(0xFF334155); // Slate-700 #334155 - divider, borders
  static const Color surfaceDarkGray = Color(0xFF1F2937); // Very dark gray for unselected states
  static const Color surfaceBorder = Color(0xFF2D3748); // Border color for dark surfaces
  
  // Text - High-contrast professional text
  static const Color textPrimaryLight = Color(0xFFFFFFFF); // Pure white #FFFFFF - main text
  static const Color textSecondaryCool = Color(0xFF94A3B8); // Cool gray #94A3B8 - subtitles, labels
  static const Color textTertiaryLight = Color(0xFFE2E8F0); // Very light gray #E2E8F0
  static const Color textTertiary = Color(0xFF64748B); // Tertiary text #64748B
  
  // Secondary/Supporting - Professional green for success, rates, positive indicators
  static const Color successGreen = Color(0xFF10B981); // Emerald-500 #10B981 - professional success
  static const Color successGreenAlt = Color(0xFF059669); // Darker emerald for pressed states
  
  // Semantic Colors
  static const Color errorRed = Color(0xFFEF4444); // Muted red for errors
  
  // Light Mode Colors (kept for compatibility, but dark is default)
  static const LightColors light = LightColors();

  // Dark Mode Colors (TruePay landing page palette)
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

  // Background Colors - Light theme with subtle mint/teal tint
  @override
  Color get background => const Color(0xFFF0FDFA); // Very light mint/teal tint (#F0FDFA)
  @override
  Color get surface => Colors.white.withOpacity(0.95); // Almost white with slight opacity
  @override
  Color get surfaceVariant => const Color(0xFFF8FAFC); // Off-white (#F8FAFC)

  // Text Colors - Light theme
  @override
  Color get textPrimary => const Color(0xFF1F2937); // Dark gray for readability
  @override
  Color get textSecondary => const Color(0xFF6B7280); // Medium gray
  @override
  Color get textTertiary => const Color(0xFF9CA3AF); // Light gray
  @override
  Color get textDisabled => const Color(0xFFD1D5DB);

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

  // Input Colors - Light theme with glassmorphism
  @override
  Color get inputBackground => Colors.white.withOpacity(0.95); // Slightly translucent
  @override
  Color get inputBorder => const Color(0xFFE5E7EB); // Light border
  @override
  Color get inputBorderFocused => AppColors.brandPrimary; // Teal focus border
  @override
  Color get inputPlaceholder => const Color(0xFF9CA3AF); // Light gray placeholder
}

/// Dark Mode Color Palette - TruePay landing page dark fintech theme
class DarkColors implements AppThemeColors {
  const DarkColors();

  // Primary Colors - Dark teal matching logo
  @override
  Color get primary => AppColors.brandPrimary; // #26A69A - dark teal matching logo shield
  @override
  Color get onPrimary => AppColors.textPrimaryLight; // White text on teal buttons

  // Background Colors - Deep navy blue
  @override
  Color get background => AppColors.backgroundDeepNavy; // #0F172A - main background
  @override
  Color get surface => AppColors.surfaceDark; // #1E293B - cards, dialogs
  @override
  Color get surfaceVariant => AppColors.surfaceVariantDark; // #334155 - borders, dividers

  // Text Colors - Bright white and cool grays
  @override
  Color get textPrimary => AppColors.textPrimaryLight; // #F1F5F9 - main text (almost white)
  @override
  Color get textSecondary => AppColors.textSecondaryCool; // #94A3B8 - subtitles, labels
  @override
  Color get textTertiary => AppColors.textTertiary; // #64748B - tertiary text
  @override
  Color get textDisabled => const Color(0xFF475569); // Disabled text

  // Border Colors
  @override
  Color get border => AppColors.surfaceVariantDark; // #334155
  @override
  Color get borderLight => const Color(0xFF475569); // Lighter border variant
  @override
  Color get divider => AppColors.surfaceVariantDark; // #334155

  // Semantic Colors
  @override
  Color get success => AppColors.successGreen; // #00C853 - green for success, rates
  @override
  Color get successLight => AppColors.successGreen.withOpacity(0.2); // Success background tint
  @override
  Color get error => AppColors.errorRed; // #EF4444 - muted red
  @override
  Color get errorLight => AppColors.errorRed.withOpacity(0.2); // Error background tint
  @override
  Color get warning => const Color(0xFFFFB74D); // Orange warning
  @override
  Color get warningLight => const Color(0xFFFFB74D).withOpacity(0.2);
  @override
  Color get info => AppColors.brandPrimary; // Use primary teal for info
  @override
  Color get infoLight => AppColors.brandPrimary.withOpacity(0.2);

  // UI Element Colors
  @override
  Color get shadow => Colors.black.withOpacity(0.5); // Strong shadow for depth
  @override
  Color get shadowLight => Colors.black.withOpacity(0.3); // Lighter shadow
  @override
  Color get overlay => Colors.black.withOpacity(0.8); // Dark overlay for dialogs

  // Icon Colors
  @override
  Color get iconPrimary => AppColors.textPrimaryLight; // White icons
  @override
  Color get iconSecondary => AppColors.textSecondaryCool; // Cool gray icons
  @override
  Color get iconDisabled => AppColors.textTertiary; // Disabled gray icons

  // Input Colors
  @override
  Color get inputBackground => AppColors.surfaceDark; // #1E293B - input background
  @override
  Color get inputBorder => AppColors.surfaceVariantDark; // #334155 - input border
  @override
  Color get inputBorderFocused => AppColors.brandPrimary; // Teal when focused
  @override
  Color get inputPlaceholder => AppColors.textTertiary; // #64748B - placeholder text
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
