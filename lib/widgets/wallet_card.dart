import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pretium/app/route_names.dart';

class WalletCard extends StatelessWidget {
  const WalletCard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      padding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(minHeight: 250),
      decoration: BoxDecoration(
        // Use brand primary as gradient base. Slightly vary for depth.
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.95),
            Theme.of(context).colorScheme.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child:
          user == null
              ? _StaticBalance()
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .snapshots(),
                builder: (context, snapshot) {
                  double balance = 0.0;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data();
                    if (data != null) {
                      final raw = data['balance'];
                      if (raw is num) balance = raw.toDouble();
                      if (raw is String) {
                        balance = double.tryParse(raw) ?? 0.0;
                      }
                    }
                  }
                  return _WalletBalanceContent(balance: balance);
                },
              ),
    );
  }
}

class _StaticBalance extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _WalletBalanceContent(balance: 12.90);
  }
}

class _WalletBalanceContent extends StatefulWidget {
  final double balance;
  const _WalletBalanceContent({required this.balance, super.key});

  @override
  State<_WalletBalanceContent> createState() => _WalletBalanceContentState();
}

class _WalletBalanceContentState extends State<_WalletBalanceContent> {
  bool _isHidden = false;

  String _maskedAmount(String currencySymbol) {
    // Simple mask for hidden balance
    return '$currencySymbol ••••';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(
                  255,
                  222,
                  238,
                  237,
                ).withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => setState(() => _isHidden = !_isHidden),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(
                    255,
                    222,
                    238,
                    237,
                  ).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _isHidden ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text("Wallet Balance", style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(
          _isHidden
              ? _maskedAmount('KES')
              : "KES ${widget.balance.toStringAsFixed(2)}",
          style: const TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            _isHidden
                ? _maskedAmount('\$')
                : "\$ ${(widget.balance / 129.0).toStringAsFixed(2)}", // naive FX example
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(context).pushNamed(RouteNames.topup);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Top Up'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushNamed(RouteNames.swap);
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Swap'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
