import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pretium/features/send_money/screens/send_money_page.dart';
import 'package:pretium/core/constants/app_colors.dart';

class FinancialServices extends StatelessWidget {
  const FinancialServices({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with country selector - centered
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Financial Services",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        // Single horizontal row of 4 large rounded rectangle buttons - centered
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildServiceButton(
              context,
              FontAwesomeIcons.paperPlane,
              "Send Money",
              true, // isFontAwesome
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SendMoneyPage()),
                );
              },
            ),
            const SizedBox(width: 16),
            _buildServiceButton(
              context,
              FontAwesomeIcons.shoppingBasket,
              "Buy Goods",
              true, // isFontAwesome
              () => _showComingSoonDialog(context),
            ),
            const SizedBox(width: 16),
            _buildServiceButton(
              context,
              FontAwesomeIcons.receipt,
              "Paybill",
              true, // isFontAwesome
              () => _showComingSoonDialog(context),
            ),
            const SizedBox(width: 16),
            _buildServiceButton(
              context,
              Icons.phone_android,
              "Airtime",
              false, // isFontAwesome
              () => _showComingSoonDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  // Build larger rounded rectangle button for services - matching reference design
  Widget _buildServiceButton(BuildContext context, IconData icon, String label, bool isFontAwesome, [VoidCallback? onTap]) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    // Use the same primary turquoise color as the Fiat Wallet button
    final containerColor = primary;
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 75,
            height: 90,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: colors.shadowLight,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: isFontAwesome
                  ? FaIcon(
                      icon,
                      color: colors.onPrimary,
                      size: 36,
                    )
                  : Icon(
                      icon,
                      color: colors.onPrimary,
                      size: 36,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Coming Soon"),
          content: const Text("This feature is under development."),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
