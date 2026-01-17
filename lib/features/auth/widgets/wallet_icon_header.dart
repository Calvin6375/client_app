import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';

class WalletIconHeader extends StatelessWidget {
  final Color color;
  const WalletIconHeader({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Transform.translate(
      offset: const Offset(0, 50),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.background, // Use theme background color to match screen
          borderRadius: BorderRadius.circular(17),
        ),
        child: Image.asset(
          'assets/images/icon_2.png',
          width: 80,
          height: 80,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
