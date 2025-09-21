import 'package:flutter/material.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/models/wallet_model.dart';

class WalletCard extends StatefulWidget {
  const WalletCard({super.key});

  @override
  State<WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<WalletCard> {
  final _wallets = [
    Wallet(currencyCode: 'KES', balance: 12050.75),
    Wallet(currencyCode: 'USD', balance: 350.50),
    Wallet(currencyCode: 'NGN', balance: 150000.00),
    Wallet(currencyCode: 'GBP', balance: 85.20),
  ];

  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PageView.builder(
            itemCount: _wallets.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return _SingleWalletCard(wallet: _wallets[index]);
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_wallets.length, (index) {
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SingleWalletCard extends StatelessWidget {
  final Wallet wallet;
  const _SingleWalletCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withOpacity(0.95),
            primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Wallet Balance", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            "${wallet.currencyCode} ${wallet.balance.toStringAsFixed(2)}",
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pushNamed(RouteNames.topup),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Top Up'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pushNamed(RouteNames.swap),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Swap'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
