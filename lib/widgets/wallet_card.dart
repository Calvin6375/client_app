import 'package:flutter/material.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/models/wallet_model.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/features/swap/screens/swap_page.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class WalletCard extends StatefulWidget {
  final int selectedTab;
  const WalletCard({super.key, this.selectedTab = 0});

  @override
  State<WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<WalletCard> {
  final WalletRepository _walletRepository = WalletRepository();
  Wallet? _fiatWallet;
  Wallet? _cryptoWallet;
  bool _loading = false;
  String? _fiatError;
  String? _cryptoError;
  DateTime? _lastRefreshedAt;
  
  // Cache for balances to avoid unnecessary backend calls
  Wallet? _cachedFiatWallet;
  Wallet? _cachedCryptoWallet;
  DateTime? _cacheTimestamp;
  static const Duration _cacheValidityDuration = Duration(seconds: 30); // Cache valid for 30 seconds
  
  @override
  void initState() {
    super.initState();
    if (_isFirebaseInitialized()) {
      // Only refresh immediately after login (when widget is first created)
      _refreshBalance();
    }
  }
  
  bool _isFirebaseInitialized() {
    return Firebase.apps.isNotEmpty;
  }


  @override
  void dispose() {
    super.dispose();
  }

  // Public method to refresh balance (can be called from parent)
  Future<void> refreshBalance({bool silent = false, bool forceRefresh = false}) async {
    await _refreshBalance(silent: silent, forceRefresh: forceRefresh);
  }
  
  Future<void> _refreshBalance({bool silent = false, bool forceRefresh = false}) async {
    if (!_isFirebaseInitialized()) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Check cache validity
      final now = DateTime.now();
      final isCacheValid = _cacheTimestamp != null && 
                          _cachedFiatWallet != null && 
                          _cachedCryptoWallet != null &&
                          now.difference(_cacheTimestamp!) < _cacheValidityDuration;
      
      // Use cached data if available and valid, unless force refresh is requested
      if (isCacheValid && !forceRefresh && silent) {
        if (!mounted) return;
        setState(() {
          _fiatWallet = _cachedFiatWallet;
          _cryptoWallet = _cachedCryptoWallet;
        });
        return;
      }
      
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
      
      // Update cache
      _cachedFiatWallet = fiatWallet ?? Wallet(currencyCode: 'USD', balance: 0.0);
      _cachedCryptoWallet = cryptoWallet ?? Wallet(currencyCode: 'USDT', balance: 0.0);
      _cacheTimestamp = now;
      
      setState(() {
        _fiatWallet = _cachedFiatWallet;
        _cryptoWallet = _cachedCryptoWallet;
        _lastRefreshedAt = now;
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
    
    // Use selectedTab from parent instead of PageView
    final isFiat = widget.selectedTab == 0;
    final currentWallet = isFiat ? fiatWallet : cryptoWallet;
    final currentError = isFiat ? _fiatError : _cryptoError;
    final walletTitle = isFiat ? "Fiat Wallet" : "Crypto Wallet";
    
    return WalletCardWidget(
      title: walletTitle,
      currency: currentWallet.currencyCode,
      balance: currentWallet.balance,
      updatedAt: _lastRefreshedAt,
      loading: _loading,
      error: currentError,
      backgroundColor: primary,
                onTopUp: () async {
                  await Navigator.of(context).pushNamed(RouteNames.topup);
                  await _refreshBalance(forceRefresh: true);
                },
      onSwap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SwapPage(initialFromCurrency: currentWallet.currencyCode),
          ),
        );
      },
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
    final size = MediaQuery.of(context).size;
    final circleSize = size.width * 0.75; // Large circular element
    
    return Center(
      child: Column(
        children: [
          // Large circular balance display with glow effect
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Outer glow effect
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.3),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.2),
                  blurRadius: 80,
                  spreadRadius: 30,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    backgroundColor,
                    backgroundColor.withValues(alpha: 0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: colors.onPrimary.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Account number or balance label
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      currency,
                      style: TextStyle(
                        color: colors.onPrimary.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Balance or Loading/Error
                  if (loading)
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: CircularProgressIndicator(
                        color: colors.onPrimary,
                        strokeWidth: 3,
                      ),
                    )
                  else if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        balance.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 36,
                          color: colors.onPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Action buttons inside circle - aligned on same axis
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Top Up Button
                      _CircularActionButton(
                        icon: Icons.add_circle_outline,
                        label: 'Top Up',
                        onPressed: onTopUp,
                        backgroundColor: colors.onPrimary,
                        foregroundColor: backgroundColor,
                        labelColor: colors.onPrimary, // White text for visibility
                        isCompact: true,
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // Swap Button
                      _CircularActionButton(
                        icon: Icons.swap_horiz,
                        label: 'Swap',
                        onPressed: onSwap,
                        backgroundColor: colors.onPrimary.withValues(alpha: 0.2),
                        foregroundColor: colors.onPrimary,
                        borderColor: colors.onPrimary.withValues(alpha: 0.7),
                        isCompact: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
  final Color? labelColor; // Optional separate color for label text
  final bool isCompact;

  const _CircularActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    this.labelColor,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonSize = isCompact ? 48.0 : 64.0;
    final iconSize = isCompact ? 22.0 : 28.0;
    final fontSize = isCompact ? 11.0 : 13.0;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: buttonSize,
          height: buttonSize,
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
              size: iconSize,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: labelColor ?? foregroundColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }
}

