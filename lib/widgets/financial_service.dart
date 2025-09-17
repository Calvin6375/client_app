import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FinancialServices extends StatelessWidget {
  const FinancialServices({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 5,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
              ),
              _buildServiceItem(
                context,
                FontAwesomeIcons.shoppingBasket,
                "Buy Goods",
              ),
              _buildServiceItem(context, FontAwesomeIcons.receipt, "Paybill"),
            ],
          ),
          const SizedBox(height: 16),
          // Second row with just Airtime, centered
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildServiceItem(context, Icons.phone_android, "Airtime"),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Pass BuildContext so we can access Theme.of(context)
  Widget _buildServiceItem(BuildContext context, IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(0.1),
          radius: 25,
          child:
              icon is IconData && icon.fontFamily == 'FontAwesomeSolid'
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
    );
  }
}
