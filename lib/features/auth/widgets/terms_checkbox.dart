import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';

class TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onTermsTap;
  final Color? color;

  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.onTermsTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final checkboxColor = color ?? colors.primary;
    return Row(
      children: [
        Checkbox(
          value: value,
          activeColor: checkboxColor,
          checkColor: colors.onPrimary,
          side: BorderSide(color: colors.border, width: 3.0),
          onChanged: onChanged,
        ),
        GestureDetector(
          onTap: onTermsTap,
          child: Text(
            'Accept Terms and Conditions',
            style: TextStyle(
              decoration: TextDecoration.underline,
              color: checkboxColor,
            ),
          ),
        ),
      ],
    );
  }
}
