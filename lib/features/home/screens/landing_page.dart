import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pretium/features/send_money/screens/send_money_page.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/app/route_names.dart';
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
  final GlobalKey<State<PlaceholderTransactions>> _transactionsKey = GlobalKey<State<PlaceholderTransactions>>();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleRefresh() async {
    // Refresh wallet balance when user pulls down
    final walletCardState = _walletCardKey.currentState;
    if (walletCardState != null) {
      try {
        await (walletCardState as dynamic).refreshBalance(forceRefresh: true);
      } catch (e) {
        // If method doesn't exist, ignore
      }
    }
    // Refresh recent transactions (get transaction endpoint)
    final transactionsState = _transactionsKey.currentState;
    if (transactionsState != null) {
      try {
        await (transactionsState as dynamic).refreshTransactions();
      } catch (e) {
        // If method doesn't exist, ignore
      }
    }
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
                  // Segmented control style - wallet toggle with glassmorphism container
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.surfaceDark // Dark slate #1E293B for dark mode
                          : Colors.white.withOpacity(0.9), // Light background for toggle container
                      borderRadius: BorderRadius.circular(16),
                      border: Theme.of(context).brightness == Brightness.light
                          ? Border.all(
                              color: const Color(0xFFE5E7EB), // Soft gray border
                              width: 1,
                            )
                          : null,
                      boxShadow: Theme.of(context).brightness == Brightness.light
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
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
                  const SizedBox(height: 12),
                  // Large circular wallet display
                  WalletCard(
                    key: _walletCardKey,
                    selectedTab: _selectedTab,
                  ),
                const SizedBox(height: 12),
                // Financial Services grid
                FinancialServices(
                  swapInitialCurrency: _selectedTab == 0 ? 'USD' : 'USDT',
                ),
                const SizedBox(height: 40),
                // Recent Transactions
                const RecentTransactionsHeader(),
                const SizedBox(height: 16),
                PlaceholderTransactions(key: _transactionsKey),
                const SizedBox(height: 24),
              ],
            ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white.withOpacity(0.95) // Clean white background
              : colors.background, // Dark background for dark mode
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfaceVariantDark // Subtle top border for dark
                  : const Color(0xFFE5E7EB), // Soft gray border for light mode
              width: 1,
            ),
          ),
          boxShadow: Theme.of(context).brightness == Brightness.light
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ]
              : null,
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
                  ? primary // Theme-aware primary color when active
                  : colors.textTertiary, // Theme-aware tertiary when inactive
              onPressed: () {
                _onItemTapped(0);
                Navigator.of(context).pushNamed(RouteNames.wallet);
              },
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
                  color: primary, // Theme-aware primary color
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.3), // Theme-aware glow
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: FaIcon(
                  FontAwesomeIcons.paperPlane,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.backgroundDeepNavy // Deep navy icon for dark mode
                      : Colors.white, // White icon for light mode
                  size: 22,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.receipt_long),
              iconSize: 26,
              color: _selectedIndex == 2 
                  ? primary // Theme-aware primary color when active
                  : colors.textTertiary, // Theme-aware tertiary when inactive
              onPressed: () {
                _onItemTapped(2);
                Navigator.of(context).pushNamed(RouteNames.transactions);
              },
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillTab(String label, int index) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
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
                ? primary // Uniform primary color (teal/green from financial icons)
                : Colors.transparent, // Transparent when unselected
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected 
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.backgroundDeepNavy // Deep navy text on teal for dark mode
                      : Colors.white) // White text on teal for light mode
                  : colors.textSecondary, // Theme-aware secondary text when unselected
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
