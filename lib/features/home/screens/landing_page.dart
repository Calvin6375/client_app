import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pretium/features/send_money/screens/send_money_page.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/services/app_access_guard.dart';
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
  bool _accessChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifyCustomerAccess());
  }

  Future<void> _verifyCustomerAccess() async {
    final guard = AppAccessGuard();
    final access = await guard.evaluate();
    if (!mounted) return;
    if (access != AppAccessResult.allowed) {
      await guard.enforceDeniedAccess(context, access);
      return;
    }
    setState(() => _accessChecked = true);
  }

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
    if (!_accessChecked) {
      return Scaffold(
        backgroundColor: AppColors.getThemeColors(context).background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
                  // Credit-card style wallet display
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
      bottomNavigationBar: _buildFloatingBottomNav(context, colors, primary),
    );
  }

  Widget _buildFloatingBottomNav(
    BuildContext context,
    AppThemeColors colors,
    Color primary,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark
        ? AppColors.surfaceDark.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _FloatingNavItem(
                      icon: Icons.account_balance_wallet_outlined,
                      isSelected: _selectedIndex == 0,
                      primary: primary,
                      inactiveColor: colors.textTertiary,
                      onTap: () {
                        _onItemTapped(0);
                        Navigator.of(context).pushNamed(RouteNames.wallet);
                      },
                    ),
                  ),
                  Expanded(
                    child: _FloatingNavItem(
                      faIcon: FontAwesomeIcons.paperPlane,
                      isSelected: _selectedIndex == 1,
                      primary: primary,
                      inactiveColor: colors.textTertiary,
                      onTap: () {
                        _onItemTapped(1);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const SendMoneyPage(initialFromCurrency: 'USD'),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: _FloatingNavItem(
                      icon: Icons.history_outlined,
                      isSelected: _selectedIndex == 2,
                      primary: primary,
                      inactiveColor: colors.textTertiary,
                      onTap: () {
                        _onItemTapped(2);
                        Navigator.of(context).pushNamed(RouteNames.transactions);
                      },
                    ),
                  ),
                  Expanded(
                    child: _FloatingNavItem(
                      icon: Icons.person_outline,
                      isSelected: _selectedIndex == 3,
                      primary: primary,
                      inactiveColor: colors.textTertiary,
                      onTap: () {
                        _onItemTapped(3);
                        Navigator.of(context).pushNamed(RouteNames.walletSettings);
                      },
                    ),
                  ),
                ],
              ),
            ),
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

class _FloatingNavItem extends StatelessWidget {
  const _FloatingNavItem({
    this.icon,
    this.faIcon,
    required this.isSelected,
    required this.primary,
    required this.inactiveColor,
    required this.onTap,
  }) : assert(icon != null || faIcon != null);

  final IconData? icon;
  final IconData? faIcon;
  final bool isSelected;
  final Color primary;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? primary : inactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 62,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (faIcon != null)
                FaIcon(faIcon, size: 22, color: color)
              else
                Icon(icon, size: 24, color: color),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 5 : 0,
                height: isSelected ? 5 : 0,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
