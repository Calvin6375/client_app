import 'package:flutter/material.dart';

class WalletIconHeader extends StatelessWidget {
  final Color color;
  const WalletIconHeader({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 50),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 210, 213, 212),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Icon(
          Icons.account_balance_wallet_rounded,
          size: 35,
          color: color,
        ),
      ),
    );
  }
}
