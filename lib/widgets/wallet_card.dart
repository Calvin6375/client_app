import 'package:flutter/material.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/models/wallet_model.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/features/swap/screens/swap_page.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class WalletCard extends StatefulWidget {
  const WalletCard({super.key});

  @override
  State<WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<WalletCard> {
  final WalletRepository _walletRepository = WalletRepository();
  final PageController _pageController = PageController();
  Wallet? _fiatWallet;
  Wallet? _cryptoWallet;
  bool _loading = false;
  String? _fiatError;
  String? _cryptoError;
  DateTime? _lastRefreshedAt;
  int _currentPage = 0;
  
  bool _isFirebaseInitialized() {
    return Firebase.apps.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    if (_isFirebaseInitialized()) {
      _refreshBalance();
      // Auto-refresh every 60s
      Future.doWhile(() async {
        await Future.delayed(const Duration(seconds: 60));
        if (!mounted) return false;
        await _refreshBalance(silent: true);
        return mounted;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refreshBalance({bool silent = false}) async {
    if (!_isFirebaseInitialized()) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      if (!silent) {
        setState(() { 
          _loading = true; 
          _fiatError = null;
          _cryptoError = null;
        });
      }
      
      // Load both fiat (USD) and crypto (USDT) wallets
      final fiatWallet = await _walletRepository.getWalletBalance(user.uid);
      final cryptoWallet = await _walletRepository.getCryptoWalletBalance(user.uid, 'USDT');
      
      if (!mounted) return;
      setState(() {
        _fiatWallet = fiatWallet ?? Wallet(currencyCode: 'USD', balance: 0.0);
        _cryptoWallet = cryptoWallet ?? Wallet(currencyCode: 'USDT', balance: 0.0);
        _lastRefreshedAt = DateTime.now();
        _fiatError = null; // Clear any previous errors
        _cryptoError = null; // Clear any previous errors
      });
    } catch (e) {
      // This should rarely happen now since fetchWalletBalance returns default wallet
      if (!mounted) return;
      setState(() { 
        // Only show error for unexpected exceptions (network issues, etc.)
        final errorMsg = e.toString();
        final truncatedError = errorMsg.length > 100 ? '${errorMsg.substring(0, 100)}...' : errorMsg;
        _fiatError = truncatedError;
        _cryptoError = truncatedError;
      });
    } finally {
      if (mounted && !silent) {
        setState(() { _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fiatWallet = _fiatWallet ?? Wallet(currencyCode: 'USD', balance: 0.0);
    final cryptoWallet = _cryptoWallet ?? Wallet(currencyCode: 'USDT', balance: 0.0);
    final primary = Theme.of(context).colorScheme.primary;
    
    return Column(
      children: [
        SizedBox(
          height: 280,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              WalletCardWidget(
                title: "Fiat Wallet",
                currency: fiatWallet.currencyCode,
                balance: fiatWallet.balance,
                updatedAt: _lastRefreshedAt,
                loading: _loading,
                error: _fiatError,
                backgroundColor: primary,
                onTopUp: () async {
                  await Navigator.of(context).pushNamed(RouteNames.topup);
                  await _refreshBalance();
                },
                onSwap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SwapPage(initialFromCurrency: fiatWallet.currencyCode),
                    ),
                  );
                },
              ),
              WalletCardWidget(
                title: "Crypto Wallet",
                currency: cryptoWallet.currencyCode,
                balance: cryptoWallet.balance,
                updatedAt: _lastRefreshedAt,
                loading: _loading,
                error: _cryptoError,
                backgroundColor: primary,
                onTopUp: () async {
                  await Navigator.of(context).pushNamed(RouteNames.topup);
                  await _refreshBalance();
                },
                onSwap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SwapPage(initialFromCurrency: cryptoWallet.currencyCode),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Swipe indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (index) {
            return Container(
              width: _currentPage == index ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _currentPage == index 
                    ? primary 
                    : primary.withValues(alpha: 0.3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Reusable wallet card widget with modern UX design
class WalletCardWidget extends StatelessWidget {
  final String title;
  final String currency;
  final double balance;
  final DateTime? updatedAt;
  final bool loading;
  final String? error;
  final Color backgroundColor;
  final VoidCallback onTopUp;
  final VoidCallback onSwap;

  const WalletCardWidget({
    super.key,
    required this.title,
    required this.currency,
    required this.balance,
    this.updatedAt,
    this.loading = false,
    this.error,
    required this.backgroundColor,
    required this.onTopUp,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            backgroundColor.withValues(alpha: 0.95),
            backgroundColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            title,
            style: TextStyle(
              color: colors.onPrimary.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          
          // Balance or Loading/Error
          if (loading)
            SizedBox(
              height: 36,
              width: 36,
              child: CircularProgressIndicator(
                color: colors.onPrimary,
                strokeWidth: 3,
              ),
            )
          else if (error != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 60),
              child: SingleChildScrollView(
                child: Text(
                  error!,
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 12,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else
            Text(
              "$currency ${balance.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 28,
                color: colors.onPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          
          // Updated timestamp
          if (updatedAt != null && !loading && error == null) ...[
            const SizedBox(height: 8),
            Text(
              'Updated ${TimeOfDay.fromDateTime(updatedAt!).format(context)}',
              style: TextStyle(
                color: colors.onPrimary.withValues(alpha: 0.7),
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          ],
          
          const Spacer(),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Top Up Button
              _CircularActionButton(
                icon: Icons.add_circle_outline,
                label: 'Top Up',
                onPressed: onTopUp,
                backgroundColor: colors.onPrimary,
                foregroundColor: backgroundColor,
              ),
              
              const SizedBox(width: 16),
              
              // Swap Button
              _CircularActionButton(
                icon: Icons.swap_horiz,
                label: 'Swap',
                onPressed: onSwap,
                backgroundColor: colors.onPrimary.withValues(alpha: 0.2),
                foregroundColor: colors.onPrimary,
                borderColor: colors.onPrimary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular action button with icon and label
class _CircularActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;

  const _CircularActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: borderColor != null
                  ? Border.all(color: borderColor!, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: AppColors.getThemeColors(context).shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: onPressed,
              icon: Icon(
                icon,
                color: foregroundColor,
                size: 28,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
