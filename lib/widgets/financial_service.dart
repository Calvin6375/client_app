import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pretium/features/send_money/screens/send_money_page.dart';
import 'package:pretium/core/constants/app_colors.dart';

class FinancialServices extends StatelessWidget {
  const FinancialServices({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            spreadRadius: 5,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: colors.shadowLight,
            spreadRadius: 4,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                "Financial Services",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Text(
                "Kenya",
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // First row with Send Money, Buy Goods, and Paybill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildServiceItem(
                context,
                FontAwesomeIcons.paperPlane,
                "Send Money",
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SendMoneyPage()),
                  );
                },
              ),
              _buildServiceItem(
                context,
                FontAwesomeIcons.shoppingBasket,
                "Buy Goods",
                () => _showComingSoonDialog(context),
              ),
              _buildServiceItem(
                context, 
                FontAwesomeIcons.receipt, 
                "Paybill",
                () => _showComingSoonDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Second row with just Airtime, centered
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildServiceItem(
                context, 
                Icons.phone_android, 
                "Airtime",
                () => _showComingSoonDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Pass BuildContext so we can access Theme.of(context)
  Widget _buildServiceItem(BuildContext context, IconData icon, String label, [VoidCallback? onTap]) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(0.1),
          radius: 25,
          child:
              icon.runtimeType == IconData
                  ? FaIcon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  )
                  : Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
        ),
        SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    ),);
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
