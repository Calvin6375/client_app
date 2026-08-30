import 'package:flutter/material.dart';
import 'package:pretium/features/crypto/screens/usdc_receive_screen.dart';
import 'package:pretium/features/pay/screens/pay_page.dart';
import 'package:pretium/features/topup/models/topup_deposit_country.dart';
import 'package:pretium/features/topup/screens/topup_page.dart';
import 'package:pretium/models/wallet_model.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:pretium/services/wallet_balance_refresh.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretium/utils/firebase_utils.dart';
import 'package:pretium/widgets/app_shimmer.dart';

class WalletCard extends StatefulWidget {
  final int selectedTab;
  const WalletCard({super.key, this.selectedTab = 0});

  @override
  State<WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<WalletCard> {
  final WalletRepository _walletRepository = WalletRepository();
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

  // Cache for balances to avoid unnecessary backend calls
  Wallet? _cachedFiatWallet;
  Wallet? _cachedCryptoWallet;
  DateTime? _cacheTimestamp;
  static const Duration _cacheValidityDuration = Duration(seconds: 30); // Cache valid for 30 seconds

  static const List<String> _supportedCryptoCurrencies = ['USDT', 'USDC'];
  /// Always shown on home even at 0 balance; other currencies need balance > 0.
  static const Set<String> _zeroBalanceAlwaysVisibleFiat = {'KES', 'USD'};
  static const Set<String> _zeroBalanceAlwaysVisibleCrypto = {'USDT', 'USDC'};
  static const double _cardAspectRatio = 1.586; // ISO/IEC 7810 ID-1 card ratio

  /// Keeps KES as the first fiat wallet card whenever it is available.
  static List<String> _withKesFirst(List<String> currencies) {
    if (!currencies.contains('KES')) return List<String>.from(currencies);
    return [
      'KES',
      ...currencies.where((c) => c != 'KES'),
    ];
  }

  static bool _showFiatOnHome(String code, double balance) {
    final upper = code.trim().toUpperCase();
    if (upper.isEmpty) return false;
    if (_zeroBalanceAlwaysVisibleFiat.contains(upper)) return true;
    return balance > 0;
  }

  static bool _showCryptoOnHome(String code, double balance) {
    final upper = code.trim().toUpperCase();
    if (upper.isEmpty) return false;
    if (_zeroBalanceAlwaysVisibleCrypto.contains(upper)) return true;
    return balance > 0;
  }

  double _cardHeight(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width - 40;
    return cardWidth / _cardAspectRatio;
  }

  Widget _buildActionButtons(
    BuildContext context, {
    required VoidCallback onTopUp,
    required VoidCallback onPay,
  }) {
    final cardWidth = MediaQuery.of(context).size.width - 40;

    return Center(
      child: SizedBox(
        width: cardWidth,
        child: Row(
          children: [
            Expanded(
              child: _FlowPayActionButton(
                label: 'Top Up',
                isPrimary: false,
                onPressed: onTopUp,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FlowPayActionButton(
                label: 'Pay',
                isPrimary: true,
                onPressed: onPay,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void initState() {
    super.initState();
    WalletBalanceRefresh.revision.addListener(_onExternalBalanceRefresh);
    if (!isFirebaseInitialized()) return;
    // Stale-while-revalidate: paint last known balance immediately, then
    // refresh in the background without a loading spinner.
    final snap = DashboardSessionCache.instance.readWalletLastKnown();
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
      _refreshBalance(silent: true, forceRefresh: true);
    } else {
      _refreshBalance();
    }
  }

  void _onExternalBalanceRefresh() {
    if (!mounted) return;
    final snap = DashboardSessionCache.instance.readWalletLastKnown();
    if (snap != null) {
      setState(() => _hydrateFromSnapshotSync(snap));
    }
    _refreshBalance(silent: true, forceRefresh: true);
  }

  void _hydrateFromSnapshotSync(WalletSessionSnapshot snap) {
    _fiatWallets
      ..clear()
      ..addAll(snap.fiatWallets);
    _availableFiatCurrencies
      ..clear()
      ..addAll(_withKesFirst(snap.availableFiatCurrencies));
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
    WalletBalanceRefresh.revision.removeListener(_onExternalBalanceRefresh);
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

      // Single GET /api/accounts — Firestore + USDC ledger (no RTDB wallet reads).
      final accounts = await _walletRepository.fetchAccounts(
        forceRefresh: forceRefresh,
      );

      final Map<String, Wallet> fiatWallets = Map<String, Wallet>.from(
        accounts.fiatWallets,
      );
      for (final e in accounts.fiatBalances.entries) {
        fiatWallets.putIfAbsent(
          e.key,
          () => Wallet(currencyCode: e.key, balance: e.value),
        );
      }
      // Always keep default fiat shells so KES/USD appear even at 0.
      for (final code in _zeroBalanceAlwaysVisibleFiat) {
        fiatWallets.putIfAbsent(
          code,
          () =>
              accounts.fiatWallet(code) ?? Wallet(currencyCode: code, balance: 0),
        );
      }

      // Home carousel: KES/USD always; other fiat only when balance > 0.
      final availableCurrencies = fiatWallets.entries
          .where((e) => _showFiatOnHome(e.key, e.value.balance))
          .map((e) => e.key)
          .toList();
      final orderedFiatCurrencies = _withKesFirst(availableCurrencies);

      final Map<String, Wallet> cryptoWallets = {
        for (final code in _supportedCryptoCurrencies)
          code: accounts.cryptoWallet(code) ??
              Wallet(currencyCode: code, balance: 0),
      };
      for (final e in accounts.cryptoWallets.entries) {
        cryptoWallets[e.key] = e.value;
      }

      // Home carousel: USDT/USDC always; other crypto only when balance > 0.
      final cryptoCodes = cryptoWallets.entries
          .where((e) => _showCryptoOnHome(e.key, e.value.balance))
          .map((e) => e.key)
          .toList();
      if (!cryptoCodes.contains('USDT')) cryptoCodes.insert(0, 'USDT');
      if (!cryptoCodes.contains('USDC')) cryptoCodes.add('USDC');

      if (!mounted) return;

      _cachedFiatWallet = fiatWallets[
              orderedFiatCurrencies.isNotEmpty ? orderedFiatCurrencies[0] : 'USD'] ??
          Wallet(currencyCode: 'USD', balance: 0.0);
      _cachedCryptoWallet =
          cryptoWallets['USDT'] ?? Wallet(currencyCode: 'USDT', balance: 0.0);
      _cacheTimestamp = now;

      DashboardSessionCache.instance.recordWalletSnapshot(
        fiatWallets: fiatWallets,
        availableFiatCurrencies: orderedFiatCurrencies,
        cryptoWallets: cryptoWallets,
        availableCryptoCurrencies: cryptoCodes,
        cachedFiatWallet: _cachedFiatWallet,
        cachedCryptoWallet: _cachedCryptoWallet,
      );

      setState(() {
        _fiatWallets
          ..clear()
          ..addAll(fiatWallets);
        _availableFiatCurrencies
          ..clear()
          ..addAll(orderedFiatCurrencies);

        if (_availableFiatCurrencies.isNotEmpty) {
          _fiatWallet = _fiatWallets[_availableFiatCurrencies[0]];
          _currentFiatIndex = 0;
        } else {
          _fiatWallet = Wallet(currencyCode: 'USD', balance: 0.0);
          _currentFiatIndex = 0;
        }

        _cryptoWallets
          ..clear()
          ..addAll(cryptoWallets);
        _availableCryptoCurrencies
          ..clear()
          ..addAll(cryptoCodes);
        _lastRefreshedAt = now;
        _fiatError = null;
        _cryptoError = null;
      });
    } catch (e) {
      // This should rarely happen now since fetchWalletBalance returns default wallet
      if (!mounted) return;
      // Keep showing cached balance on silent refresh failures — no error flash.
      if (silent && (_fiatWallet != null || _fiatWallets.isNotEmpty || _cryptoWallets.isNotEmpty)) {
        return;
      }
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WalletCardWidget(
              title: "Fiat Wallet",
              currency: defaultWallet.currencyCode,
              balance: defaultWallet.balance,
              secondaryCurrency: null,
              secondaryBalance: null,
              updatedAt: _lastRefreshedAt,
              loading: _loading,
              error: _fiatError,
              backgroundColor: primary,
            ),
            const SizedBox(height: 12),
            _buildActionButtons(
              context,
              onTopUp: _openTopUpFlow,
              onPay: () => _openPayFlow(isCrypto: false),
            ),
          ],
        );
      }
      
      // Swipable fiat wallets — only the card slides; buttons stay fixed
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _cardHeight(context),
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
            );
          },
            ),
          ),
          const SizedBox(height: 12),
          _buildActionButtons(
            context,
            onTopUp: _openTopUpFlow,
            onPay: () => _openPayFlow(isCrypto: false),
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
                          : primary.withValues(alpha: 0.25),
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WalletCardWidget(
              title: "Crypto Wallet",
              currency: 'USDT',
              balance: 0,
              updatedAt: _lastRefreshedAt,
              loading: _loading,
              error: _cryptoError,
              backgroundColor: primary,
            ),
            const SizedBox(height: 12),
            _buildActionButtons(
              context,
              onTopUp: () => _openCryptoTopUp('USDT'),
              onPay: () => _openPayFlow(isCrypto: true),
            ),
          ],
        );
      }

      final currentCryptoCurrency =
          _availableCryptoCurrencies[_currentCryptoIndex.clamp(0, _availableCryptoCurrencies.length - 1)];

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _cardHeight(context),
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
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildActionButtons(
            context,
            onTopUp: () => _openCryptoTopUp(currentCryptoCurrency),
            onPay: () => _openPayFlow(isCrypto: true),
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
                          : primary.withValues(alpha: 0.25),
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

  Future<void> _openTopUpFlow() async {
    final currencyCode = widget.selectedTab == 0 &&
            _availableFiatCurrencies.isNotEmpty
        ? _availableFiatCurrencies[
            _currentFiatIndex.clamp(0, _availableFiatCurrencies.length - 1)]
        : (_fiatWallet?.currencyCode ?? 'USD');

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TopUpPage(
          initialDepositCountry: TopupDepositCountry.resolve(currencyCode),
        ),
      ),
    );
    if (mounted) await _refreshBalance(forceRefresh: true);
  }

  Future<void> _openPayFlow({required bool isCrypto}) async {
    final String payCurrency;
    if (isCrypto) {
      payCurrency = 'USD';
    } else if (_availableFiatCurrencies.isNotEmpty) {
      payCurrency = _availableFiatCurrencies[
          _currentFiatIndex.clamp(0, _availableFiatCurrencies.length - 1)];
    } else {
      payCurrency = _fiatWallet?.currencyCode ?? 'KES';
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PayPage(initialCurrency: payCurrency),
      ),
    );
    if (mounted) await _refreshBalance(forceRefresh: true);
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
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
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
                        AppColors.surfaceDark.withValues(alpha: 0.95),
                        AppColors.backgroundDeepNavy,
                      ]
                    : [
                        widget.backgroundColor.withValues(alpha: 0.95),
                        widget.backgroundColor.withValues(alpha: 0.75),
                        widget.backgroundColor.withValues(alpha: 0.55),
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
                      color: widget.backgroundColor.withValues(alpha: isDark ? 0.12 : 0.18),
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
                      color: widget.backgroundColor.withValues(alpha: isDark ? 0.08 : 0.12),
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
                          Colors.white.withValues(alpha: isDark ? 0.06 : 0.12),
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
                                  color: colors.textPrimary.withValues(alpha: 0.85),
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
                                const ShimmerBusyIndicator(width: 72, height: 18)
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
                      // Bottom row: expiry, CVC, SafariTap brand
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
                          const _SafariTapBrand(),
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

class _SafariTapBrand extends StatelessWidget {
  const _SafariTapBrand();

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
                    text: 'Tap',
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

