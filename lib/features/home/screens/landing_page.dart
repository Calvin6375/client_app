import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pretium/features/pay/screens/pay_page.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/services/app_access_guard.dart';
import 'package:pretium/services/wallet_balance_refresh.dart';
import 'package:pretium/widgets/app_shimmer.dart';
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
    return const DashboardScreen();
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
  bool _navVisible = true;
  Timer? _navRevealTimer;

  static const Duration _navAnimDuration = Duration(milliseconds: 320);
  static const Duration _navRevealDelay = Duration(milliseconds: 220);

  @override
  void initState() {
    WalletBalanceRefresh.revision.addListener(_onBalancesRefreshed);
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifyCustomerAccess());
  }

  @override
  void dispose() {
    _navRevealTimer?.cancel();
    WalletBalanceRefresh.revision.removeListener(_onBalancesRefreshed);
    super.dispose();
  }

  void _setNavVisible(bool visible) {
    if (!mounted || _navVisible == visible) return;
    setState(() => _navVisible = visible);
  }

  void _scheduleNavReveal() {
    _navRevealTimer?.cancel();
    _navRevealTimer = Timer(_navRevealDelay, () => _setNavVisible(true));
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // Only react to the dashboard list, not nested horizontal scrolls.
    if (notification.depth != 0) return false;

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta;
      if (delta != null && delta.abs() > 0.8) {
        _navRevealTimer?.cancel();
        _setNavVisible(false);
      }
    } else if (notification is ScrollEndNotification) {
      _scheduleNavReveal();
    }
    return false;
  }

  void _onBalancesRefreshed() {
    if (!mounted) return;
    final txState = _transactionsKey.currentState;
    if (txState == null) return;
    try {
      (txState as dynamic).refreshTransactions();
    } catch (_) {}
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

  Future<void> _silentRefreshBalance() async {
    final walletCardState = _walletCardKey.currentState;
    if (walletCardState == null) return;
    try {
      await (walletCardState as dynamic).refreshBalance(
        silent: true,
        forceRefresh: true,
      );
    } catch (_) {}
  }

  Future<void> _openAndRefreshOnReturn(Future<dynamic> Function() openRoute) async {
    await openRoute();
    if (!mounted) return;
    await _silentRefreshBalance();
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
        body: const DashboardShimmer(),
      );
    }

    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // Room for the floating dock so list content can scroll clear of it.
    const floatingNavClearance = 108.0;

    return Scaffold(
      backgroundColor: colors.background,
      // Let body paint under the dock so the nav truly floats over content.
      extendBody: true,
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
                color: Colors.transparent,
                child: const HeaderWidget(),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: RefreshIndicator(
                    onRefresh: _handleRefresh,
                    color: primary,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        floatingNavClearance + bottomInset,
                      ),
                      children: [
                        const SizedBox(height: 16),
                        // Segmented control style - wallet toggle with glassmorphism container
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.surfaceDark
                                : Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Theme.of(context).brightness == Brightness.light
                                ? Border.all(
                                    color: const Color(0xFFE5E7EB),
                                    width: 1,
                                  )
                                : null,
                            boxShadow:
                                Theme.of(context).brightness == Brightness.light
                                    ? [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.04),
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
                        WalletCard(
                          key: _walletCardKey,
                          selectedTab: _selectedTab,
                        ),
                        const SizedBox(height: 12),
                        FinancialServices(
                          swapInitialCurrency:
                              _selectedTab == 0 ? 'USD' : 'USDT',
                        ),
                        const SizedBox(height: 40),
                        const RecentTransactionsHeader(),
                        const SizedBox(height: 16),
                        PlaceholderTransactions(key: _transactionsKey),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              duration: _navAnimDuration,
              curve: _navVisible ? Curves.easeOutCubic : Curves.easeInCubic,
              offset: _navVisible ? Offset.zero : const Offset(0, 1.15),
              child: AnimatedOpacity(
                duration: _navAnimDuration,
                curve: Curves.easeOut,
                opacity: _navVisible ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_navVisible,
                  child: _buildFloatingBottomNav(context, colors, primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomNav(
    BuildContext context,
    AppThemeColors colors,
    Color primary,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark
        ? AppColors.surfaceDark.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.72);

    void openPay() {
      _onItemTapped(1);
      _openAndRefreshOnReturn(
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PayPage(
              initialCurrency: _selectedTab == 0 ? 'KES' : 'USD',
            ),
          ),
        ),
      );
    }

    // Transparent Material avoids Scaffold painting a solid bottom "card" band.
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 6),
          child: SizedBox(
            height: 88,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.4 : 0.12),
                          blurRadius: 28,
                          spreadRadius: 0,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.18 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(36),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.55),
                            ),
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
                                    _openAndRefreshOnReturn(
                                      () => Navigator.of(context)
                                          .pushNamed(RouteNames.wallet),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 72),
                              Expanded(
                                child: _FloatingNavItem(
                                  icon: Icons.history_outlined,
                                  isSelected: _selectedIndex == 2,
                                  primary: primary,
                                  inactiveColor: colors.textTertiary,
                                  onTap: () {
                                    _onItemTapped(2);
                                    _openAndRefreshOnReturn(
                                      () => Navigator.of(context)
                                          .pushNamed(RouteNames.transactions),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: _ElevatedPayNavButton(
                    primary: primary,
                    background: colors.background,
                    onTap: openPay,
                  ),
                ),
              ],
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

class _ElevatedPayNavButton extends StatelessWidget {
  const _ElevatedPayNavButton({
    required this.primary,
    required this.background,
    required this.onTap,
  });

  final Color primary;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary,
            border: Border.all(color: background, width: 4),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: ColorFiltered(
            // White in the asset becomes the button teal; black outlines stay dark.
            colorFilter: ColorFilter.mode(primary, BlendMode.modulate),
            child: Image.asset(
              'assets/images/pay_nav_icon.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingNavItem extends StatelessWidget {
  const _FloatingNavItem({
    required this.icon,
    required this.isSelected,
    required this.primary,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
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
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 5),
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
