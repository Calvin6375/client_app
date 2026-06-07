import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pretium/features/crypto/screens/usdc_receive_screen.dart';
import 'package:pretium/features/crypto/screens/usdc_send_screen.dart';
import 'package:pretium/features/crypto/services/crypto_api_service.dart';
import 'package:pretium/features/topup/models/topup_deposit_country.dart';
import 'package:pretium/features/topup/screens/direct_fiat_deposit_flow.dart';
import 'package:pretium/features/topup/screens/select_country_topup_screen.dart';
import 'package:pretium/features/topup/screens/topup_page.dart';
import 'package:pretium/models/wallet_model.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretium/utils/firebase_utils.dart';

class WalletCard extends StatefulWidget {
  final int selectedTab;
  const WalletCard({super.key, this.selectedTab = 0});

  @override
  State<WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<WalletCard> {
  final WalletRepository _walletRepository = WalletRepository();
  final CryptoApiService _cryptoApi = CryptoApiService();
  Wallet? _fiatWallet;
  bool _loading = false;
  String? _fiatError;
  String? _cryptoError;
  DateTime? _lastRefreshedAt;
  
  // Multiple fiat wallets support
  final Map<String, Wallet> _fiatWallets = {};
  final List<String> _availableFiatCurrencies = [];
  int _currentFiatIndex = 0;
  final PageController _fiatPageController = PageController();

  // Multiple crypto wallets (USDT legacy + Circle USDC)
  final Map<String, Wallet> _cryptoWallets = {};
  final List<String> _availableCryptoCurrencies = ['USDT', 'USDC'];
  int _currentCryptoIndex = 0;
  final PageController _cryptoPageController = PageController();
  StreamSubscription<Wallet?>? _usdcBalanceSubscription;
  
  // Cache for balances to avoid unnecessary backend calls
  Wallet? _cachedFiatWallet;
  Wallet? _cachedCryptoWallet;
  DateTime? _cacheTimestamp;
  static const Duration _cacheValidityDuration = Duration(seconds: 30); // Cache valid for 30 seconds
  
  // Supported fiat currencies to check
  static const List<String> _supportedFiatCurrencies = ['USD', 'KES', 'NGN', 'GHS', 'UGX'];
  static const List<String> _supportedCryptoCurrencies = ['USDT', 'USDC'];
  
  @override
  void initState() {
    super.initState();
    if (!isFirebaseInitialized()) return;
    _subscribeUsdcBalance();
    final snap = DashboardSessionCache.instance.readWalletIfFresh();
    if (snap != null) {
      _hydrateFromSnapshotSync(snap);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_fiatPageController.hasClients && _availableFiatCurrencies.length > 1) {
          _fiatPageController.jumpToPage(_currentFiatIndex.clamp(0, _availableFiatCurrencies.length - 1));
        }
        if (_cryptoPageController.hasClients && _availableCryptoCurrencies.length > 1) {
          _cryptoPageController.jumpToPage(_currentCryptoIndex.clamp(0, _availableCryptoCurrencies.length - 1));
        }
      });
    } else {
      _refreshBalance();
    }
  }

  void _subscribeUsdcBalance() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _usdcBalanceSubscription?.cancel();
    _usdcBalanceSubscription = _walletRepository
        .streamCryptoWalletBalance(user.uid, 'USDC')
        .listen((wallet) {
      if (!mounted || wallet == null) return;
      setState(() {
        _cryptoWallets['USDC'] = wallet;
      });
    });
  }

  void _hydrateFromSnapshotSync(WalletSessionSnapshot snap) {
    _fiatWallets
      ..clear()
      ..addAll(snap.fiatWallets);
    _availableFiatCurrencies
      ..clear()
      ..addAll(snap.availableFiatCurrencies);
    if (_availableFiatCurrencies.isNotEmpty) {
      _fiatWallet = _fiatWallets[_availableFiatCurrencies[0]];
      _currentFiatIndex = 0;
    } else {
      _fiatWallet = Wallet(currencyCode: 'USD', balance: 0.0);
      _currentFiatIndex = 0;
    }
    _cryptoWallets
      ..clear()
      ..addAll(snap.cryptoWallets);
    _availableCryptoCurrencies
      ..clear()
      ..addAll(snap.availableCryptoCurrencies.isNotEmpty
          ? snap.availableCryptoCurrencies
          : _supportedCryptoCurrencies);
    _cachedFiatWallet = snap.cachedFiatWallet;
    _cachedCryptoWallet = snap.cachedCryptoWallet;
    _cacheTimestamp = snap.refreshedAt;
    _lastRefreshedAt = snap.refreshedAt;
    _loading = false;
    _fiatError = null;
    _cryptoError = null;
  }
  
  @override
  void dispose() {
    _usdcBalanceSubscription?.cancel();
    _fiatPageController.dispose();
    _cryptoPageController.dispose();
    super.dispose();
  }

  // Public method to refresh balance (can be called from parent)
  Future<void> refreshBalance({bool silent = false, bool forceRefresh = false}) async {
    await _refreshBalance(silent: silent, forceRefresh: forceRefresh);
  }
  
  Future<void> _refreshBalance({bool silent = false, bool forceRefresh = false}) async {
    if (!isFirebaseInitialized()) return;
    
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
      
      // Load crypto wallets (USDT from RTDB, USDC from RTDB + API for authoritative display)
      final Map<String, Wallet> cryptoWallets = {};
      for (final currency in _supportedCryptoCurrencies) {
        try {
          final wallet = await _walletRepository.getCryptoWalletBalance(user.uid, currency);
          cryptoWallets[currency] = wallet ?? Wallet(currencyCode: currency, balance: 0.0);
        } catch (_) {
          cryptoWallets[currency] = Wallet(currencyCode: currency, balance: 0.0);
        }
      }

      // Refresh USDC available balance from Circle API (authoritative for send validation)
      try {
        final usdcBalance = await _cryptoApi.getBalance();
        cryptoWallets['USDC'] = Wallet(
          currencyCode: 'USDC',
          balance: usdcBalance,
          updatedAt: now,
        );
      } catch (_) {
        // RTDB stream / repository value remains
      }
      
      if (!mounted) return;
      
      // Update cache
      _cachedFiatWallet = fiatWallets[availableCurrencies.isNotEmpty ? availableCurrencies[0] : 'USD'] ?? Wallet(currencyCode: 'USD', balance: 0.0);
      _cachedCryptoWallet = cryptoWallets['USDT'] ?? Wallet(currencyCode: 'USDT', balance: 0.0);
      _cacheTimestamp = now;

      DashboardSessionCache.instance.recordWalletSnapshot(
        fiatWallets: fiatWallets,
        availableFiatCurrencies: availableCurrencies,
        cryptoWallets: cryptoWallets,
        availableCryptoCurrencies: List<String>.from(_supportedCryptoCurrencies),
        cachedFiatWallet: _cachedFiatWallet,
        cachedCryptoWallet: _cachedCryptoWallet,
      );

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
        
        _cryptoWallets.clear();
        _cryptoWallets.addAll(cryptoWallets);
        _lastRefreshedAt = now;
        _fiatError = null;
        _cryptoError = null;
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
          onTopUp: _openTopUpFlow,
          onWithdraw: () => _openKenyaWithdraw(context),
        );
      }
      
      // Swipable fiat wallets with page indicator (height aligned with Crypto layout - no extra space)
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.width * 0.75 + 48, // Circle size + minimal space for page indicator
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
              onTopUp: _openTopUpFlow,
              onWithdraw: () => _openKenyaWithdraw(context),
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
                          : primary.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    } else {
      // Crypto wallets — swipable PageView (USDT + USDC)
      if (_availableCryptoCurrencies.isEmpty) {
        return WalletCardWidget(
          title: "Crypto Wallet",
          currency: 'USDT',
          balance: 0,
          updatedAt: _lastRefreshedAt,
          loading: _loading,
          error: _cryptoError,
          backgroundColor: primary,
          onTopUp: () => _openCryptoTopUp('USDT'),
          onWithdraw: () => _openCryptoWithdraw('USDT'),
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.width * 0.75 + 48,
            child: PageView.builder(
              controller: _cryptoPageController,
              onPageChanged: (index) {
                setState(() => _currentCryptoIndex = index);
              },
              itemCount: _availableCryptoCurrencies.length,
              itemBuilder: (context, index) {
                final currency = _availableCryptoCurrencies[index];
                final wallet = _cryptoWallets[currency] ?? Wallet(currencyCode: currency, balance: 0.0);

                String? secondaryCurrency;
                double? secondaryBalance;
                if (currency == 'USDT' && _cryptoWallets.containsKey('USDC')) {
                  secondaryCurrency = 'USDC';
                  secondaryBalance = _cryptoWallets['USDC']!.balance;
                } else if (currency == 'USDC' && _cryptoWallets.containsKey('USDT')) {
                  secondaryCurrency = 'USDT';
                  secondaryBalance = _cryptoWallets['USDT']!.balance;
                }

                return WalletCardWidget(
                  title: "Crypto Wallet",
                  currency: wallet.currencyCode,
                  balance: wallet.balance,
                  secondaryCurrency: secondaryCurrency,
                  secondaryBalance: secondaryBalance,
                  updatedAt: _lastRefreshedAt,
                  loading: _loading && index == _currentCryptoIndex,
                  error: _cryptoError,
                  backgroundColor: primary,
                  onTopUp: () => _openCryptoTopUp(currency),
                  onWithdraw: () => _openCryptoWithdraw(currency),
                );
              },
            ),
          ),
          if (_availableCryptoCurrencies.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _availableCryptoCurrencies.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentCryptoIndex == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentCryptoIndex == index
                          ? primary
                          : primary.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }
  }

  Future<void> _openCryptoTopUp(String currency) async {
    if (currency == 'USDC') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const UsdcReceiveScreen()),
      );
      if (mounted) await _refreshBalance(forceRefresh: true);
      return;
    }
    await _openTopUpFlow();
  }

  Future<void> _openCryptoWithdraw(String currency) async {
    if (currency == 'USDC') {
      final usdcBalance = _cryptoWallets['USDC']?.balance;
      final refreshed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => UsdcSendScreen(availableBalance: usdcBalance),
        ),
      );
      if (mounted && refreshed == true) {
        await _refreshBalance(forceRefresh: true);
      }
      return;
    }
    _showWithdrawComingSoon(context);
  }

  Future<void> _openTopUpFlow() async {
    final country = await Navigator.of(context).push<TopupDepositCountry>(
      MaterialPageRoute<TopupDepositCountry>(
        builder: (_) => const SelectCountryTopUpScreen(),
      ),
    );
    if (!mounted || country == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TopUpPage(initialDepositCountry: country),
      ),
    );
    if (mounted) await _refreshBalance(forceRefresh: true);
  }

  void _openKenyaWithdraw(BuildContext context) {
    final kesBalance = _fiatWallets['KES']?.balance ?? 0.0;
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            builder: (_) => DirectFiatDepositScreen(
              fiatBalance: kesBalance,
              walletCurrencyCode: 'KES',
              flowKind: DirectFiatFlowKind.withdraw,
            ),
          ),
        )
        .then((_) {
          if (mounted) _refreshBalance(forceRefresh: true);
        });
  }

  void _showWithdrawComingSoon(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Coming Soon'),
        content: const Text('Withdraw will be available soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
  final VoidCallback onWithdraw;

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
    required this.onWithdraw,
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
              // Theme-aware shadows - enhanced glassmorphism for light mode
              boxShadow: Theme.of(context).brightness == Brightness.dark
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6), // Outer shadow for dark
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4), // Inner shadow hint
                        blurRadius: 20,
                        offset: const Offset(0, -2),
                        spreadRadius: -5,
                      ),
                    ]
                  : [
                      // Subtle shadow - soft and diffused (matching image)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06), // Very subtle shadow
                        blurRadius: 24,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                      // Light greenish-teal outline/glow (wallet page design)
                      BoxShadow(
                        color: (backgroundColor).withOpacity(0.25),
                        blurRadius: 20,
                        spreadRadius: -2,
                      ),
                    ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? [
                          AppColors.surfaceDark, // Slate-800 center #1E293B
                          AppColors.surfaceDark.withOpacity(0.95),
                          AppColors.backgroundDeepNavy, // Deep navy edge #0F172A
                        ]
                      : [
                          // Soft gradient: light teal center to white edge (matching image)
                          const Color(0xFFE0F7FA), // Light teal center (#E0F7FA)
                          const Color(0xFFF0FDFA), // Very light mint
                          Colors.white, // Almost white edge
                        ],
                  stops: const [0.0, 0.6, 1.0],
                ),
                // Border adapts to theme - very subtle for light mode
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.withOpacity(0.3) // Silver-metallic border for dark
                      : Colors.white.withOpacity(0.4), // Very subtle white border
                  width: 1,
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
                        color: colors.textSecondary, // Theme-aware secondary text
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
                        // Primary balance - large, bold, theme-aware color
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            balance.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 42,
                              color: colors.textPrimary, // Theme-aware primary text
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
                      // Top Up Button - glassmorphism design for light mode
                      _CircularActionButton(
                        icon: Icons.add_circle_outline,
                        label: 'Top Up',
                        onPressed: onTopUp,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.surfaceBorder // Dark gray #2D3748 for dark mode
                            : colors.primary, // Uniform primary color (teal/green from financial icons)
                        foregroundColor: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textTertiaryLight // Light gray for dark mode
                            : Colors.white, // White icon for light mode on teal
                        labelColor: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textTertiaryLight
                            : Colors.black, // Black label text for visibility in light mode
                        isCompact: true,
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // Withdraw (swap control moved to Financial Services)
                      _CircularActionButton(
                        icon: FontAwesomeIcons.moneyBillTransfer,
                        label: 'Withdraw',
                        onPressed: onWithdraw,
                        isFontAwesome: true,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.transparent
                            : Colors.white.withOpacity(0.9), // Light background for light mode
                        foregroundColor: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textTertiaryLight // Light gray for dark mode
                            : colors.primary, // Uniform primary color (teal/green) for icon
                        borderColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.withOpacity(0.4) // Subtle border for dark
                            : const Color(0xFFE5E7EB), // Light gray border for light mode
                        labelColor: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textTertiaryLight
                            : colors.textPrimary,
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
  final bool isFontAwesome;

  const _CircularActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    this.labelColor,
    this.isCompact = false,
    this.isFontAwesome = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonSize = isCompact ? 48.0 : 64.0;
    final iconSize = isCompact ? 22.0 : 28.0;
    final fontSize = isCompact ? 11.0 : 13.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.getThemeColors(context);
    
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
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    // Subtle shadow for light mode buttons
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: isFontAwesome
                ? FaIcon(
                    icon,
                    color: foregroundColor,
                    size: iconSize,
                  )
                : Icon(
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

