import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';

/// App Text Styles - Centralized text style definitions
/// All styles are theme-aware and work with both light and dark modes
class AppTextStyles {
  AppTextStyles._(); // Private constructor to prevent instantiation

  // ============================================================================
  // HEADING STYLES
  // ============================================================================

  /// Large heading style (e.g., page titles, welcome text)
  /// Font size: 24, Bold
  static TextStyle headingLarge(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: colors.textPrimary,
      letterSpacing: 0,
    );
  }

  /// Medium heading style (e.g., section titles, card titles)
  /// Font size: 20, Bold
  static TextStyle headingMedium(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: colors.textPrimary,
      letterSpacing: 0,
    );
  }

  /// Small heading style (e.g., subsection titles)
  /// Font size: 18, Bold
  static TextStyle headingSmall(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: colors.textPrimary,
      letterSpacing: 0,
    );
  }

  /// Extra small heading style (e.g., widget labels)
  /// Font size: 16, Semi-bold
  static TextStyle headingXSmall(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: colors.textPrimary,
      letterSpacing: 0,
    );
  }

  // ============================================================================
  // BODY STYLES
  // ============================================================================

  /// Large body text style
  /// Font size: 16, Regular
  static TextStyle bodyLarge(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: colors.textPrimary,
      letterSpacing: 0,
    );
  }

  /// Medium body text style (default)
  /// Font size: 14, Regular
  static TextStyle bodyMedium(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: colors.textPrimary,
      letterSpacing: 0,
    );
  }

  /// Small body text style
  /// Font size: 12, Regular
  static TextStyle bodySmall(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: colors.textSecondary,
      letterSpacing: 0,
    );
  }

  /// Extra small body text style
  /// Font size: 10, Regular
  static TextStyle bodyXSmall(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.normal,
      color: colors.textTertiary,
      letterSpacing: 0,
    );
  }

  // ============================================================================
  // LABEL STYLES
  // ============================================================================

  /// Label style for form fields and inputs
  /// Font size: 14, Medium weight
  static TextStyle label(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: colors.textPrimary,
      letterSpacing: 0,
    );
  }

  /// Small label style
  /// Font size: 12, Medium weight
  static TextStyle labelSmall(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: colors.textSecondary,
      letterSpacing: 0,
    );
  }

  // ============================================================================
  // CAPTION STYLES
  // ============================================================================

  /// Caption style for secondary information
  /// Font size: 12, Regular, Secondary color
  static TextStyle caption(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: colors.textSecondary,
      letterSpacing: 0.3,
    );
  }

  /// Small caption style
  /// Font size: 10, Regular, Tertiary color
  static TextStyle captionSmall(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.normal,
      color: colors.textTertiary,
      letterSpacing: 0.3,
    );
  }

  // ============================================================================
  // BUTTON STYLES
  // ============================================================================

  /// Primary button text style
  /// Font size: 16, Semi-bold
  static TextStyle buttonLarge(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: colors.onPrimary,
      letterSpacing: 0.5,
    );
  }

  /// Medium button text style
  /// Font size: 14, Semi-bold
  static TextStyle buttonMedium(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: colors.onPrimary,
      letterSpacing: 0.5,
    );
  }

  /// Small button text style
  /// Font size: 12, Semi-bold
  static TextStyle buttonSmall(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: colors.onPrimary,
      letterSpacing: 0.5,
    );
  }

  /// Text button style (outlined/secondary buttons)
  /// Font size: 14, Semi-bold, Primary color
  static TextStyle buttonText(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: colors.primary,
      letterSpacing: 0.5,
    );
  }

  // ============================================================================
  // SPECIAL STYLES
  // ============================================================================

  /// Balance amount style (large, bold, for wallet displays)
  /// Font size: 28, Bold, White/OnPrimary
  static TextStyle balanceAmount(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: colors.onPrimary,
      letterSpacing: 0.5,
    );
  }

  /// Card title style (for wallet cards, financial services)
  /// Font size: 14, Medium weight, with opacity
  static TextStyle cardTitle(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: colors.onPrimary.withOpacity(0.7),
      letterSpacing: 0.5,
    );
  }

  /// Timestamp style (for "Updated" text, transaction dates)
  /// Font size: 12, Regular, with opacity
  static TextStyle timestamp(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: colors.onPrimary.withOpacity(0.7),
      letterSpacing: 0.3,
    );
  }

  /// Error text style
  /// Font size: 12, Regular, Error color
  static TextStyle error(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: colors.error,
      letterSpacing: 0,
    );
  }

  /// Success text style
  /// Font size: 12, Regular, Success color
  static TextStyle success(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: colors.success,
      letterSpacing: 0,
    );
  }

  /// Amount text style for transactions (debit/credit)
  /// Font size: 14, Semi-bold
  static TextStyle transactionAmount(
    BuildContext context, {
    bool isDebit = false,
  }) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: isDebit ? colors.error : colors.success,
      letterSpacing: 0,
    );
  }

  /// Greeting text style (for header greetings)
  /// Font size: 18, Bold, OnPrimary
  static TextStyle greeting(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: colors.onPrimary,
      letterSpacing: 0,
    );
  }

  /// Service label style (for financial service icons)
  /// Font size: 12, Regular
  static TextStyle serviceLabel(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: colors.textPrimary,
      letterSpacing: 0,
    );
  }

  /// Subtitle style (for secondary text under headings)
  /// Font size: 14, Regular, Secondary color
  static TextStyle subtitle(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: colors.textSecondary,
      letterSpacing: 0,
    );
  }

  // ============================================================================
  // INPUT FIELD STYLES
  // ============================================================================

  /// Input hint text style
  /// Font size: 14, Regular, Placeholder color
  static TextStyle inputHint(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: colors.inputPlaceholder,
      letterSpacing: 0,
    );
  }

  /// Input label style (unfocused)
  /// Font size: 14, Regular, Primary color
  static TextStyle inputLabel(BuildContext context, {Color? customColor}) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: customColor ?? colors.primary,
      letterSpacing: 0,
    );
  }

  /// Input floating label style (focused)
  /// Font size: 14, Regular, Primary color
  static TextStyle inputFloatingLabel(
    BuildContext context, {
    Color? customColor,
  }) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: customColor ?? colors.primary,
      letterSpacing: 0,
    );
  }

  // ============================================================================
  // LINK STYLES
  // ============================================================================

  /// Link text style (for clickable text)
  /// Font size: 14, Regular, Primary color, Underlined
  static TextStyle link(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: colors.primary,
      decoration: TextDecoration.underline,
      letterSpacing: 0,
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Apply a color to an existing text style
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Apply opacity to an existing text style's color
  static TextStyle withOpacity(TextStyle style, double opacity) {
    return style.copyWith(color: style.color?.withOpacity(opacity));
  }

  /// Make text bold
  static TextStyle bold(TextStyle style) {
    return style.copyWith(fontWeight: FontWeight.bold);
  }

  /// Make text medium weight
  static TextStyle medium(TextStyle style) {
    return style.copyWith(fontWeight: FontWeight.w500);
  }

  /// Make text semi-bold
  static TextStyle semiBold(TextStyle style) {
    return style.copyWith(fontWeight: FontWeight.w600);
  }
}
