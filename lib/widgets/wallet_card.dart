import 'dart:async';

import 'package:flutter/material.dart';
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
  static const double _cardAspectRatio = 1.586; // ISO/IEC 7810 ID-1 card ratio
  static const double _actionButtonsHeight = 56;

  double _cardHeight(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width - 40;
    return cardWidth / _cardAspectRatio;
  }

  double _pageItemHeight(BuildContext context) {
    return _cardHeight(context) + _actionButtonsHeight + 12;
  }
  
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
            height: _pageItemHeight(context),
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
          // Page indicator dots — FlowPay-style circular indicators
          if (_availableFiatCurrencies.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _availableFiatCurrencies.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentFiatIndex == index ? 10 : 6,
                    height: _currentFiatIndex == index ? 10 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentFiatIndex == index
                          ? primary
                          : primary.withOpacity(0.25),
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
            height: _pageItemHeight(context),
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
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _availableCryptoCurrencies.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentCryptoIndex == index ? 10 : 6,
                    height: _currentCryptoIndex == index ? 10 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentCryptoIndex == index
                          ? primary
                          : primary.withOpacity(0.25),
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

/// Reusable wallet card widget — FlowPay credit-card layout with app colors
class WalletCardWidget extends StatefulWidget {
  final String title;
  final String currency;
  final double balance;
  final String? secondaryCurrency;
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
  State<WalletCardWidget> createState() => _WalletCardWidgetState();
}

class _WalletCardWidgetState extends State<WalletCardWidget> {
  bool _balanceVisible = true;

  String get _currencySymbol {
    switch (widget.currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'USDT':
      case 'USDC':
        return '${widget.currency.toUpperCase()} ';
      case 'KES':
        return 'KSh ';
      case 'NGN':
        return '₦';
      case 'GHS':
        return 'GH₵';
      case 'UGX':
        return 'USh ';
      default:
        return '${widget.currency.toUpperCase()} ';
    }
  }

  String get _maskedCardNumber {
    final seed = widget.currency.hashCode.abs();
    final last4 = (seed % 10000).toString().padLeft(4, '0');
    return '**** **** **** $last4';
  }

  String get _displayBalance {
    if (!_balanceVisible) return '****';
    return '$_currencySymbol${widget.balance.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final size = MediaQuery.of(context).size;
    final cardWidth = size.width - 40;
    const cardAspectRatio = 1.586;
    final cardHeight = cardWidth / cardAspectRatio;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            AppColors.surfaceDark,
                            AppColors.surfaceDark.withOpacity(0.95),
                            AppColors.backgroundDeepNavy,
                          ]
                        : [
                            widget.backgroundColor.withOpacity(0.95),
                            widget.backgroundColor.withOpacity(0.75),
                            widget.backgroundColor.withOpacity(0.55),
                          ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles — app teal accent, not FlowPay blue
                    Positioned(
                      top: -cardHeight * 0.12,
                      right: -cardWidth * 0.08,
                      child: Container(
                        width: cardWidth * 0.5,
                        height: cardWidth * 0.5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.backgroundColor.withOpacity(isDark ? 0.12 : 0.18),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -cardHeight * 0.18,
                      left: -cardWidth * 0.12,
                      child: Container(
                        width: cardWidth * 0.42,
                        height: cardWidth * 0.42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.backgroundColor.withOpacity(isDark ? 0.08 : 0.12),
                        ),
                      ),
                    ),
                    // Subtle diagonal sheen
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              Colors.white.withOpacity(isDark ? 0.06 : 0.12),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: brand logo + balance toggle
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _BrandLogo(isDark: isDark),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => _balanceVisible = !_balanceVisible,
                                    ),
                                    child: Icon(
                                      _balanceVisible
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: colors.textPrimary.withOpacity(0.85),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Balance',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (widget.loading)
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: colors.textPrimary,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else if (widget.error != null)
                                    Text(
                                      '—',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  else
                                    Text(
                                      _displayBalance,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Card number
                          Text(
                            'Card Number',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _maskedCardNumber,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const Spacer(),
                          // Bottom row: expiry, CVC, SafariCard brand
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _CardDetailColumn(
                                label: 'Expiry Date',
                                value: '**/**',
                                colors: colors,
                              ),
                              const SizedBox(width: 28),
                              _CardDetailColumn(
                                label: 'CVC',
                                value: '***',
                                colors: colors,
                              ),
                              const Spacer(),
                              const _SafariCardBrand(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // FlowPay-style action buttons below the card
          Row(
            children: [
              Expanded(
                child: _FlowPayActionButton(
                  label: 'Add Money',
                  isPrimary: true,
                  onPressed: widget.onTopUp,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FlowPayActionButton(
                  label: 'Withdraw',
                  isPrimary: false,
                  onPressed: widget.onWithdraw,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(5),
          child: Image.asset(
            'assets/images/troupay_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.account_balance_wallet,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'TruePay',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _CardDetailColumn extends StatelessWidget {
  const _CardDetailColumn({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _SafariCardBrand extends StatelessWidget {
  const _SafariCardBrand();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final colors = AppColors.getThemeColors(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/card.png',
          height: 52,
          width: 52,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.credit_card,
            size: 40,
            color: primary,
          ),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                children: [
                  TextSpan(
                    text: 'Safari',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  TextSpan(
                    text: 'Card',
                    style: TextStyle(color: primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
                children: [
                  TextSpan(
                    text: 'by ',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  TextSpan(
                    text: 'truepay',
                    style: TextStyle(color: primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FlowPayActionButton extends StatelessWidget {
  const _FlowPayActionButton({
    required this.label,
    required this.isPrimary,
    required this.onPressed,
  });

  final String label;
  final bool isPrimary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isPrimary
          ? primary
          : (isDark ? AppColors.surfaceDark : const Color(0xFFE5E7EB)),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary
                  ? (isDark ? AppColors.backgroundDeepNavy : Colors.white)
                  : colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

