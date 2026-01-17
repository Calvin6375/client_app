import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';

class RecentTransactionsHeader extends StatelessWidget {
  const RecentTransactionsHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Row(
      children: [
        Text(
          "Recent transactions",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary, // Theme-aware text color
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () {},
          child: Text(
            "See all",
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary, // Teal for "See all"
            ),
          ),
        ),
      ],
    );
  }
}
