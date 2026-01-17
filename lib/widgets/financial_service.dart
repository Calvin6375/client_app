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
                fontWeight: FontWeight.w600, // Medium weight - professional
                color: colors.textPrimary, // Theme-aware primary text
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Single horizontal row of 4 compact rounded rectangle buttons - fits on one screen
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            const SizedBox(width: 12),
            _buildServiceButton(
              context,
              FontAwesomeIcons.shoppingBasket,
              "Buy Goods",
              true, // isFontAwesome
              () => _showComingSoonDialog(context),
            ),
            const SizedBox(width: 12),
            _buildServiceButton(
              context,
              FontAwesomeIcons.receipt,
              "Paybill",
              true, // isFontAwesome
              () => _showComingSoonDialog(context),
            ),
            const SizedBox(width: 12),
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

  // Build compact card button with glassmorphism for light mode
  Widget _buildServiceButton(BuildContext context, IconData icon, String label, bool isFontAwesome, [VoidCallback? onTap]) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Theme-aware container color
    final containerColor = isDark 
        ? AppColors.surfaceDark // Dark slate #1E293B for dark mode
        : Colors.white; // Clean white for light mode
    
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(14),
                border: isDark 
                    ? null
                    : Border.all(
                        color: const Color(0xFFE5E7EB), // Soft gray border
                        width: 1,
                      ),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        // Minimal shadow for light mode
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Center(
                child: isFontAwesome
                    ? FaIcon(
                        icon,
                        color: colors.primary, // Theme-aware primary color
                        size: 24,
                      )
                    : Icon(
                        icon,
                        color: colors.primary, // Theme-aware primary color
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary, // Theme-aware secondary text
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
