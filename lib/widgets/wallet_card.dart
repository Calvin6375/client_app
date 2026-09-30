import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/wallet_accounts_provider.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:pretium/features/crypto/screens/usdc_receive_screen.dart';
import 'package:pretium/features/crypto/services/crypto_api_service.dart';
import 'package:pretium/features/pay/screens/pay_page.dart';
import 'package:pretium/features/topup/screens/topup_page.dart';
import 'package:pretium/models/wallet_model.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/widgets/safari_card.dart';

class WalletCard extends ConsumerStatefulWidget {
  final int selectedTab;
  final String? focusCryptoCurrency;
  const WalletCard({
    super.key,
    this.selectedTab = 0,
    this.focusCryptoCurrency,
  });

  @override
  ConsumerState<WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends ConsumerState<WalletCard> {
  Wallet? _fiatWallet;
  bool _loading = false;
  String? _fiatError;
  String? _cryptoError;
  DateTime? _lastRefreshedAt;
  
  // Multiple fiat wallets support
  final Map<String, Wallet> _fiatWallets = {};
  final List<String> _availableFiatCurrencies = [];
  int _currentFiatIndex = 0;
  static const double _carouselViewportFraction = 0.88;
  final PageController _fiatPageController =
      PageController(viewportFraction: _carouselViewportFraction);

  // Multiple crypto wallets (USDT legacy + Circle USDC)
  final Map<String, Wallet> _cryptoWallets = {};
  final List<String> _availableCryptoCurrencies = ['USDT', 'USDC'];
  int _currentCryptoIndex = 0;
  String? _pendingCryptoFocus;
  final PageController _cryptoPageController =
      PageController(viewportFraction: _carouselViewportFraction);

  // Cache for balances to avoid unnecessary backend calls
  static const List<String> _supportedCryptoCurrencies = ['USDT', 'USDC'];
  static const double _cardAspectRatio = 1.586; // ISO/IEC 7810 ID-1 card ratio

  /// Keeps KES as the first fiat wallet card whenever it is available.
  static List<String> _withKesFirst(List<String> currencies) {
    if (!currencies.contains('KES')) return List<String>.from(currencies);
    return [
      'KES',
      ...currencies.where((c) => c != 'KES'),
    ];
  }

  double _cardHeight(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width - 40;
    return cardWidth / _cardAspectRatio;
  }

  Widget _buildWalletPager({
    required PageController controller,
    required int itemCount,
    required int currentIndex,
    required ValueChanged<int> onPageChanged,
    required Widget Function(BuildContext context, int index) itemBuilder,
  }) {
    return SizedBox(
      height: _cardHeight(context),
      child: PageView.builder(
        controller: controller,
        clipBehavior: Clip.none,
        padEnds: true,
        onPageChanged: onPageChanged,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return _CarouselPage(
            controller: controller,
            index: index,
            fallbackPage: currentIndex.toDouble(),
            viewportFraction: _carouselViewportFraction,
            child: itemBuilder(context, index),
          );
        },
      ),
    );
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
  
  DateTime? _appliedSnapshotAt;

  @override
  void initState() {
    super.initState();
    _pendingCryptoFocus = widget.focusCryptoCurrency;
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
    _lastRefreshedAt = snap.refreshedAt;
    _loading = false;
    _fiatError = null;
    _cryptoError = null;
    _applyPendingCryptoFocus();
  }

  @override
  void didUpdateWidget(WalletCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusCryptoCurrency != null &&
        widget.focusCryptoCurrency != oldWidget.focusCryptoCurrency) {
      _pendingCryptoFocus = widget.focusCryptoCurrency;
      _applyPendingCryptoFocus();
    }
  }

  void showCryptoCurrency(String? code) {
    if (code == null || code.trim().isEmpty) return;
    _pendingCryptoFocus = code;
    _applyPendingCryptoFocus();
    if (mounted) setState(() {});
  }

  void _applyPendingCryptoFocus() {
    final code = _pendingCryptoFocus?.trim().toUpperCase();
    if (code == null || code.isEmpty) return;
    final index = _availableCryptoCurrencies.indexWhere(
      (c) => c.toUpperCase() == code,
    );
    if (index < 0) return;
    _pendingCryptoFocus = null;
    _currentCryptoIndex = index;
    if (_cryptoPageController.hasClients) {
      _cryptoPageController.jumpToPage(index);
    }
  }
  
  @override
  void dispose() {
    _fiatPageController.dispose();
    _cryptoPageController.dispose();
    super.dispose();
  }

  void _applyAccountsSnapshot(WalletSessionSnapshot snap) {
    if (_appliedSnapshotAt == snap.refreshedAt) return;
    _hydrateFromSnapshotSync(snap);
    _appliedSnapshotAt = snap.refreshedAt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_fiatPageController.hasClients && _availableFiatCurrencies.length > 1) {
        _fiatPageController.jumpToPage(
          _currentFiatIndex.clamp(0, _availableFiatCurrencies.length - 1),
        );
      }
      if (_cryptoPageController.hasClients &&
          _availableCryptoCurrencies.length > 1) {
        _cryptoPageController.jumpToPage(
          _currentCryptoIndex.clamp(0, _availableCryptoCurrencies.length - 1),
        );
      }
    });
  }

  // Public method to refresh balance (can be called from parent)
  Future<void> refreshBalance({bool silent = false, bool forceRefresh = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _fiatError = null;
        _cryptoError = null;
      });
    }
    try {
      await ref.read(walletAccountsProvider.notifier).refresh(force: forceRefresh);
    } catch (e) {
      if (!mounted) return;
      if (silent &&
          (_fiatWallet != null ||
              _fiatWallets.isNotEmpty ||
              _cryptoWallets.isNotEmpty)) {
        return;
      }
      final errorMsg = e.toString();
      final truncatedError =
          errorMsg.length > 100 ? '${errorMsg.substring(0, 100)}...' : errorMsg;
      setState(() {
        _fiatError = truncatedError;
        _cryptoError = truncatedError;
      });
    } finally {
      if (mounted && !silent) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(walletAccountsProvider);
    final snap = accounts.valueOrNull;
    if (snap != null) {
      _applyAccountsSnapshot(snap);
    } else if (accounts.hasError &&
        _fiatWallets.isEmpty &&
        _cryptoWallets.isEmpty) {
      final errorMsg = accounts.error.toString();
      _fiatError = errorMsg.length > 100
          ? '${errorMsg.substring(0, 100)}...'
          : errorMsg;
      _cryptoError = _fiatError;
    }
    if (accounts.isLoading &&
        _fiatWallets.isEmpty &&
        _cryptoWallets.isEmpty) {
      _loading = true;
    } else if (!accounts.isLoading) {
      _loading = false;
    }

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
          _buildWalletPager(
            controller: _fiatPageController,
            itemCount: _availableFiatCurrencies.length,
            currentIndex: _currentFiatIndex,
            onPageChanged: (index) {
              setState(() {
                _currentFiatIndex = index;
                if (index < _availableFiatCurrencies.length) {
                  _fiatWallet = _fiatWallets[_availableFiatCurrencies[index]];
                }
              });
            },
            itemBuilder: (context, index) {
              final currency = _availableFiatCurrencies[index];
              final wallet = _fiatWallets[currency] ??
                  Wallet(currencyCode: currency, balance: 0.0);

              String? secondaryCurrency;
              double? secondaryBalance;

              if (currency == 'USD' && _fiatWallets.containsKey('KES')) {
                secondaryCurrency = 'KES';
                secondaryBalance = _fiatWallets['KES']!.balance;
              } else {
                for (final otherCurrency in _availableFiatCurrencies) {
                  if (otherCurrency != currency &&
                      _fiatWallets.containsKey(otherCurrency)) {
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
          _buildWalletPager(
            controller: _cryptoPageController,
            itemCount: _availableCryptoCurrencies.length,
            currentIndex: _currentCryptoIndex,
            onPageChanged: (index) {
              setState(() => _currentCryptoIndex = index);
            },
            itemBuilder: (context, index) {
              final currency = _availableCryptoCurrencies[index];
              final wallet = _cryptoWallets[currency] ??
                  Wallet(currencyCode: currency, balance: 0.0);

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
      await _openUsdcTopUp();
      return;
    }
    await _openTopUpFlow();
  }

  Future<void> _openUsdcTopUp() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Preparing USDC address…'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      final status = await CryptoApiService().ensureProductionWallet();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => UsdcReceiveScreen(walletStatus: status),
        ),
      );
      if (mounted) await refreshBalance(forceRefresh: true);
    } on CryptoApiException catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not prepare USDC wallet')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _openTopUpFlow() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const TopUpPage(),
      ),
    );
    if (mounted) await refreshBalance(forceRefresh: true);
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
    if (mounted) await refreshBalance(forceRefresh: true);
  }
}

/// Reusable wallet card widget — FlowPay credit-card layout with app colors
class _CarouselPage extends StatelessWidget {
  const _CarouselPage({
    required this.controller,
    required this.index,
    required this.fallbackPage,
    required this.viewportFraction,
    required this.child,
  });

  final PageController controller;
  final int index;
  final double fallbackPage;
  final double viewportFraction;
  final Widget child;

  double get _page {
    if (controller.hasClients && controller.position.hasContentDimensions) {
      return controller.page ?? fallbackPage;
    }
    return fallbackPage;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final page = _page;
        final delta = page - index;
        final distance = delta.abs().clamp(0.0, 1.0);
        final zoomOut = Curves.easeOutCubic.transform(distance);
        // Focused page scales up to the original card size; neighbors ease down.
        final scale = (1 / viewportFraction) * (1.0 - 0.16 * zoomOut);
        final slide = 14.0 * zoomOut;
        final dx = delta == 0 ? 0.0 : -delta.sign * slide;

        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: child,
            ),
          ),
        );
      },
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

