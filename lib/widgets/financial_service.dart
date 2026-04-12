import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pretium/features/send_money/screens/send_money_page.dart';
import 'package:pretium/features/swap/screens/swap_page.dart';
import 'package:pretium/core/constants/app_colors.dart';

class FinancialServices extends StatelessWidget {
  /// Initial "from" currency for [SwapPage] when opened from this row (e.g. USD for fiat, USDT for crypto tab).
  final String swapInitialCurrency;

  const FinancialServices({
    super.key,
    this.swapInitialCurrency = 'USD',
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Financial Services",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildServiceButton(
              context,
              FontAwesomeIcons.paperPlane,
              "Send Money",
              true,
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SendMoneyPage()),
                );
              },
            ),
            const SizedBox(width: 12),
            _buildServiceButton(
              context,
              FontAwesomeIcons.arrowRightArrowLeft,
              "Swap",
              true,
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SwapPage(initialFromCurrency: swapInitialCurrency),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            _buildServiceButton(
              context,
              FontAwesomeIcons.receipt,
              "Pay",
              true,
              () => _showComingSoonDialog(context),
            ),
            const SizedBox(width: 12),
            _buildServiceButton(
              context,
              FontAwesomeIcons.ellipsis,
              "More",
              true,
              () => _showComingSoonDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceButton(BuildContext context, IconData icon, String label, bool isFontAwesome, [VoidCallback? onTap]) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDark ? AppColors.surfaceDark : Colors.white;

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
                        color: const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Center(
                child: isFontAwesome
                    ? FaIcon(
                        icon,
                        color: colors.primary,
                        size: 24,
                      )
                    : Icon(
                        icon,
                        color: colors.primary,
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
                color: colors.textSecondary,
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
