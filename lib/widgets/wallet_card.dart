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
  
  // Multiple fiat wallets support
  final Map<String, Wallet> _fiatWallets = {}; // currency -> wallet
  final List<String> _availableFiatCurrencies = []; // Order of currencies
  int _currentFiatIndex = 0;
  final PageController _fiatPageController = PageController();
  final PageController _cryptoPageController = PageController();
  
  // Cache for balances to avoid unnecessary backend calls
  Wallet? _cachedFiatWallet;
  Wallet? _cachedCryptoWallet;
  DateTime? _cacheTimestamp;
  static const Duration _cacheValidityDuration = Duration(seconds: 30); // Cache valid for 30 seconds
  
  // Supported fiat currencies to check
  static const List<String> _supportedFiatCurrencies = ['USD', 'KES', 'NGN', 'GHS', 'UGX', 'TZS'];
  
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
    _fiatPageController.dispose();
    _cryptoPageController.dispose();
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
      
      // Load all available fiat currencies
      final Map<String, Wallet> fiatWallets = {};
      final List<String> availableCurrencies = [];
      
      // Try to load each supported fiat currency
      for (final currency in _supportedFiatCurrencies) {
        try {
          final wallet = await _walletRepository.getWalletBalance(user.uid, currency: currency);
          if (wallet != null && wallet.balance > 0) {
            fiatWallets[currency] = wallet;
            availableCurrencies.add(currency);
          } else if (wallet != null) {
            // Include wallets with 0 balance too, but prioritize non-zero
            fiatWallets[currency] = wallet;
            if (!availableCurrencies.contains(currency)) {
              availableCurrencies.add(currency);
            }
          }
        } catch (e) {
          // Skip currencies that fail to load
          continue;
        }
      }
      
      // Ensure at least USD is available
      if (!fiatWallets.containsKey('USD')) {
        final usdWallet = await _walletRepository.getWalletBalance(user.uid, currency: 'USD');
        fiatWallets['USD'] = usdWallet ?? Wallet(currencyCode: 'USD', balance: 0.0);
        if (!availableCurrencies.contains('USD')) {
          availableCurrencies.insert(0, 'USD');
        }
      }
      
      // Load crypto wallet
      final cryptoWallet = await _walletRepository.getCryptoWalletBalance(user.uid, 'USDT');
      
      if (!mounted) return;
      
      // Update cache
      _cachedFiatWallet = fiatWallets[availableCurrencies.isNotEmpty ? availableCurrencies[0] : 'USD'] ?? Wallet(currencyCode: 'USD', balance: 0.0);
      _cachedCryptoWallet = cryptoWallet ?? Wallet(currencyCode: 'USDT', balance: 0.0);
      _cacheTimestamp = now;
      
      setState(() {
        _fiatWallets.clear();
        _fiatWallets.addAll(fiatWallets);
        _availableFiatCurrencies.clear();
        _availableFiatCurrencies.addAll(availableCurrencies);
        
        // Set current fiat wallet to first available or USD
        if (_availableFiatCurrencies.isNotEmpty) {
          _fiatWallet = _fiatWallets[_availableFiatCurrencies[0]];
          _currentFiatIndex = 0;
        } else {
          _fiatWallet = Wallet(currencyCode: 'USD', balance: 0.0);
          _currentFiatIndex = 0;
        }
        
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
    final primary = Theme.of(context).colorScheme.primary;
    final isFiat = widget.selectedTab == 0;
    
    if (isFiat) {
      // Fiat wallets - swipable PageView
      if (_availableFiatCurrencies.isEmpty) {
        // Show default USD wallet while loading
        final defaultWallet = _fiatWallet ?? Wallet(currencyCode: 'USD', balance: 0.0);
        return WalletCardWidget(
          title: "Fiat Wallet",
          currency: defaultWallet.currencyCode,
          balance: defaultWallet.balance,
          secondaryCurrency: null,
          secondaryBalance: null,
          updatedAt: _lastRefreshedAt,
          loading: _loading,
          error: _fiatError,
          backgroundColor: primary,
          onTopUp: () async {
            await Navigator.of(context).pushNamed(RouteNames.topup);
            await _refreshBalance(forceRefresh: true);
          },
          onSwap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SwapPage(initialFromCurrency: defaultWallet.currencyCode),
              ),
            );
          },
        );
      }
      
      // Swipable fiat wallets with page indicator
      return Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.width * 0.75 + 100, // Match circle size + padding
            child: PageView.builder(
              controller: _fiatPageController,
              onPageChanged: (index) {
                setState(() {
                  _currentFiatIndex = index;
                  if (index < _availableFiatCurrencies.length) {
                    _fiatWallet = _fiatWallets[_availableFiatCurrencies[index]];
                  }
                });
              },
              itemCount: _availableFiatCurrencies.length,
              itemBuilder: (context, index) {
            final currency = _availableFiatCurrencies[index];
            final wallet = _fiatWallets[currency] ?? Wallet(currencyCode: currency, balance: 0.0);
            
            // Find secondary currency to display
            // Priority: 1) KES if USD is primary, 2) Next currency in list, 3) First other currency
            String? secondaryCurrency;
            double? secondaryBalance;
            
            if (currency == 'USD' && _fiatWallets.containsKey('KES')) {
              // Show KES next to USD (most common pair)
              secondaryCurrency = 'KES';
              secondaryBalance = _fiatWallets['KES']!.balance;
            } else {
              // Find the next available currency that's not the current one
              for (final otherCurrency in _availableFiatCurrencies) {
                if (otherCurrency != currency && _fiatWallets.containsKey(otherCurrency)) {
                  secondaryCurrency = otherCurrency;
                  secondaryBalance = _fiatWallets[otherCurrency]?.balance;
                  break;
                }
              }
            }
            
            return WalletCardWidget(
              title: "Fiat Wallet",
              currency: wallet.currencyCode,
              balance: wallet.balance,
              secondaryCurrency: secondaryCurrency,
              secondaryBalance: secondaryBalance,
              updatedAt: _lastRefreshedAt,
              loading: _loading && index == _currentFiatIndex,
              error: _fiatError,
              backgroundColor: primary,
              onTopUp: () async {
                await Navigator.of(context).pushNamed(RouteNames.topup);
                await _refreshBalance(forceRefresh: true);
              },
              onSwap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SwapPage(initialFromCurrency: wallet.currencyCode),
                  ),
                );
              },
            );
          },
            ),
          ),
          // Page indicator dots
          if (_availableFiatCurrencies.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _availableFiatCurrencies.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentFiatIndex == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentFiatIndex == index
                          ? primary
                          : primary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    } else {
      // Crypto wallet
      final cryptoWallet = _cryptoWallet ?? Wallet(currencyCode: 'USDT', balance: 0.0);
      return WalletCardWidget(
        title: "Crypto Wallet",
        currency: cryptoWallet.currencyCode,
        balance: cryptoWallet.balance,
        secondaryCurrency: null,
        secondaryBalance: null,
        updatedAt: _lastRefreshedAt,
        loading: _loading,
        error: _cryptoError,
        backgroundColor: primary,
        onTopUp: () async {
          await Navigator.of(context).pushNamed(RouteNames.topup);
          await _refreshBalance(forceRefresh: true);
        },
        onSwap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SwapPage(initialFromCurrency: cryptoWallet.currencyCode),
            ),
          );
        },
      );
    }
  }
}

/// Reusable wallet card widget with modern UX design
class WalletCardWidget extends StatelessWidget {
  final String title;
  final String currency;
  final double balance;
  final String? secondaryCurrency; // For currency pairs (e.g., KES shown next to USD)
  final double? secondaryBalance;
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
    this.secondaryCurrency,
    this.secondaryBalance,
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
          // Large circular balance display - professional metallic dark look
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Very subtle professional shadows - no heavy glow
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6), // Outer shadow
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4), // Inner shadow hint
                  blurRadius: 20,
                  offset: const Offset(0, -2),
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.surfaceDark, // Slate-800 center #1E293B
                    AppColors.surfaceDark.withValues(alpha: 0.95),
                    AppColors.backgroundDeepNavy, // Deep navy edge #0F172A
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
                // Metallic silver border for premium look
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.3), // Silver-metallic border
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Currency label - show only primary currency (professional uppercase)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      currency.toUpperCase(), // Uppercase for professional look
                      style: TextStyle(
                        color: AppColors.textSecondaryCool, // Light gray #94A3B8
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2, // Increased letter spacing for premium feel
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
                    // Primary balance - large, bold, pure white for high contrast
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        balance.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 42,
                          color: AppColors.textPrimaryLight, // Pure white #FFFFFF
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
                      // Top Up Button - professional flat design
                      _CircularActionButton(
                        icon: Icons.add_circle_outline,
                        label: 'Top Up',
                        onPressed: onTopUp,
                        backgroundColor: AppColors.surfaceBorder, // Dark gray #2D3748
                        foregroundColor: AppColors.textTertiaryLight, // Light gray #E2E8F0
                        labelColor: AppColors.textTertiaryLight,
                        isCompact: true,
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // Swap Button - professional flat design with border
                      _CircularActionButton(
                        icon: Icons.swap_horiz,
                        label: 'Swap',
                        onPressed: onSwap,
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.textTertiaryLight, // Light gray #E2E8F0
                        borderColor: Colors.grey.withValues(alpha: 0.4), // Subtle border
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

