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
              Text("Kenya", style: TextStyle(color: const Color(0xFF176D68))),
              Icon(Icons.keyboard_arrow_down, color: const Color(0xFF176D68)),
            ],
          ),
          const SizedBox(height: 16),
          // First row with Send Money, Buy Goods, and Paybill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildServiceItem(FontAwesomeIcons.paperPlane, "Send Money"),
              _buildServiceItem(FontAwesomeIcons.shoppingBasket, "Buy Goods"),
              _buildServiceItem(FontAwesomeIcons.receipt, "Paybill"),
            ],
          ),
          const SizedBox(height: 16),
          // Second row with just Airtime, centered
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [_buildServiceItem(Icons.phone_android, "Airtime")],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildServiceItem(IconData icon, String label) {
    final bool isFaIcon =
        icon is IconData && icon.fontFamily == 'FontAwesomeSolid';
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFF176D68).withOpacity(0.1),
          radius: 25,
          child:
              icon is IconData && icon.fontFamily == 'FontAwesomeSolid'
                  ? FaIcon(icon, color: const Color(0xFF176D68), size: 20)
                  : Icon(icon, color: const Color(0xFF176D68), size: 20),
        ),
        SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
