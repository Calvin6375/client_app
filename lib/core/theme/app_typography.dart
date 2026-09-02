import 'package:flutter/material.dart';

/// TruePay brand typeface.
///
/// Weights bundled in [assets/fonts]: Regular (400), Medium (500),
/// SemiBold (600), Bold (700). Prefer [FontWeight] values that map to these
/// so Flutter selects the matching static face instead of synthesizing.
abstract final class AppTypography {
  static const String fontFamily = 'Inter';

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  /// Applies Inter across Material text themes while preserving sizes/weights.
  static ThemeData apply(ThemeData theme) {
    return theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: fontFamily),
      primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: fontFamily),
    );
  }
}
