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
  int _selectedTab = 0; // For pill-shaped tabs: 0 = Fiat, 1 = Crypto
  final GlobalKey<State<WalletCard>> _walletCardKey = GlobalKey<State<WalletCard>>();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  Future<void> _handleRefresh() async {
    // Refresh wallet balance when user pulls down
    final walletCardState = _walletCardKey.currentState;
    if (walletCardState != null) {
      // Call the refreshBalance method using dynamic dispatch
      try {
        await (walletCardState as dynamic).refreshBalance(forceRefresh: true);
      } catch (e) {
        // If method doesn't exist, ignore
      }
    }
    // Add a small delay for better UX
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 16,
              right: 16,
              bottom: 12,
            ),
            color: Colors.transparent, // Transparent for professional dark look
            child: HeaderWidget(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: primary,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 16),
                  // Segmented control style - wallet toggle with dark container
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark, // Dark slate #1E293B container
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPillTab('Fiat Wallet', 0),
                        const SizedBox(width: 4),
                        _buildPillTab('Crypto Wallet', 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Large circular wallet display
                  WalletCard(
                    key: _walletCardKey,
                    selectedTab: _selectedTab,
                  ),
                const SizedBox(height: 20),
                // Financial Services grid
                const FinancialServices(),
                const SizedBox(height: 40),
                // Recent Transactions
                const RecentTransactionsHeader(),
                const SizedBox(height: 16),
                const PlaceholderTransactions(),
                const SizedBox(height: 24),
              ],
            ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundDeepNavy, // Deep navy #0F172A
          border: Border(
            top: BorderSide(
              color: AppColors.surfaceDark.withValues(alpha: 0.5), // Subtle top border
              width: 1,
            ),
          ),
        ),
        child: BottomAppBar(
          color: Colors.transparent,
          elevation: 0,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.account_balance_wallet),
              iconSize: 26,
              color: _selectedIndex == 0 
                  ? AppColors.brandCyan // Vibrant cyan #00D4FF when active
                  : AppColors.textTertiary, // Slate-500 #64748B when inactive
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
                  color: AppColors.brandCyan, // Vibrant cyan #00D4FF - primary CTA
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandCyan.withValues(alpha: 0.3), // Cyan glow
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: FaIcon(FontAwesomeIcons.paperPlane, color: AppColors.backgroundDeepNavy, size: 22), // Deep navy icon for contrast
              ),
            ),
            IconButton(
              icon: const Icon(Icons.receipt_long),
              iconSize: 26,
              color: _selectedIndex == 2 
                  ? AppColors.brandCyan // Vibrant cyan #00D4FF when active
                  : AppColors.textTertiary, // Slate-500 #64748B when inactive
              onPressed: () => _onItemTapped(2),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillTab(String label, int index) {
    final colors = AppColors.getThemeColors(context);
    final isSelected = _selectedTab == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppColors.brandCyan // Vibrant cyan #00D4FF when selected (accent)
                : Colors.transparent, // Transparent when unselected
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected 
                  ? AppColors.backgroundDeepNavy // Deep navy text on cyan background
                  : AppColors.textSecondaryCool, // Cool gray #94A3B8 when unselected
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
