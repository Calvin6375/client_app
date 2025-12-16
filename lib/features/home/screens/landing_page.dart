import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pretium/features/send_money/screens/send_money_page.dart';
import 'package:pretium/core/constants/app_colors.dart';
import '/widgets/header_widget.dart';
import '/widgets/wallet_card.dart';
import '/widgets/financial_service.dart';
import '/widgets/recent_transaction_header.dart';
import '/widgets/placeholder_transactions.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});
  
  @override
  Widget build(BuildContext context) {
    // Return the dashboard directly to avoid nesting MaterialApp, so app-level routes work
    return DashboardScreen();
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: primary,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 16,
              right: 16,
              bottom: 12,
            ),
            color: primary,
            child: HeaderWidget(),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(0),
                  topRight: Radius.circular(0),
                ),
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        const WalletCard(),
                        const SizedBox(height: 24),
                        const FinancialServices(),
                        const SizedBox(height: 24),
                        const RecentTransactionsHeader(),
                        const PlaceholderTransactions(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.account_balance_wallet),
              iconSize: 28,
              color: _selectedIndex == 0 ? primary : colors.iconSecondary,
              onPressed: () => _onItemTapped(0),
            ),
            GestureDetector(
              onTap: () {
                _onItemTapped(1);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SendMoneyPage(initialFromCurrency: 'USD')),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: FaIcon(FontAwesomeIcons.paperPlane, color: colors.onPrimary, size: 24),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.receipt_long),
              color: _selectedIndex == 2 ? primary : colors.iconSecondary,
              onPressed: () => _onItemTapped(2),
            ),
          ],
        ),
      ),
    );
  }
}
