import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:pretium/features/swap/services/rates_service.dart';
import 'package:pretium/features/swap/services/swap_order_service.dart';
import 'package:pretium/features/swap/widgets/currency_picker_bottom_sheet.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/utils/logger.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/widgets/currency_logo.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretium/utils/firebase_utils.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/slide_to_confirm.dart';
import 'package:pretium/services/dashboard_session_cache.dart';

class SwapPage extends StatefulWidget {
  final String? initialFromCurrency;
  
  const SwapPage({super.key, this.initialFromCurrency});

  @override
  State<SwapPage> createState() => _SwapPageState();
}

enum _SwapStep { input, confirmation, success }

class _SwapPageState extends State<SwapPage> {
  _SwapStep _step = _SwapStep.input;

  // State for the swap flow
  final _rates = RatesService();
  final _walletRepository = WalletRepository();
  final _fromCtrl = TextEditingController();
  bool _isSubmittingSwap = false;
  String _fromCurrency = 'USD';
  String _toCurrency = 'USDT';
  double _fromBalance = 0.0;
  double _toBalance = 0.0;
  bool _loadingBalances = true;
  bool _loadingWallets = true;
  late double _rate;

  /// Currencies the user actually owns (fiat + crypto wallet nodes).
  final List<String> _ownedCurrencyCodes = [];
  final Map<String, double> _ownedBalances = {};

  void _swapCurrencies() {
    if (_ownedCurrencyCodes.length < 2) return;
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;

      final tempBalance = _fromBalance;
      _fromBalance = _toBalance;
      _toBalance = tempBalance;

      _fromCtrl.clear();

      _rate = _rates.getRate(_fromCurrency, _toCurrency);
      _loadRate();
    });
  }

  void _nextStep() async {
    if (_step == _SwapStep.input) {
      if (_fromCurrency == _toCurrency || _ownedCurrencyCodes.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose two different wallets to exchange.'),
          ),
        );
        return;
      }
      setState(() => _step = _SwapStep.confirmation);
    } else if (_step == _SwapStep.confirmation) {
      await runGuardedAsync(
        this,
        isSubmitting: () => _isSubmittingSwap,
        setSubmitting: (value) => setState(() => _isSubmittingSwap = value),
        action: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please sign in to exchange')),
              );
            }
            return;
          }

          final fromAmount = double.tryParse(_fromCtrl.text) ?? 0;
          if (fromAmount <= 0) return;

          try {
            final fee = fromAmount * 0.005;
            final toAmount = fromAmount * _rate;

            final result = await createSwapOrder(
              fromCurrency: _fromCurrency,
              toCurrency: _toCurrency,
              fromAmount: fromAmount,
              exchangeRate: _rate,
              feeRate: 0.005,
              fee: fee,
              toAmount: toAmount,
            );

            if (!mounted) return;

            if (result.newBalances != null) {
              final nb = result.newBalances!;
              final fromBal = nb[_fromCurrency];
              final toBal = nb[_toCurrency];
              if (fromBal != null) _fromBalance = (fromBal as num).toDouble();
              if (toBal != null) _toBalance = (toBal as num).toDouble();
              setState(() {});
            } else {
              await _loadBalances();
            }

            setState(() => _step = _SwapStep.success);
            _showSuccessDialog();
          } on FirebaseFunctionsException catch (e) {
            if (!mounted) return;
            final message = switch (e.code) {
              'unauthenticated' => 'Please sign in to exchange.',
              'invalid-argument' => 'Invalid exchange request. Please check your input.',
              'failed-precondition' =>
                'Insufficient balance. You don\'t have enough $_fromCurrency to complete this exchange.',
              'internal' => 'Something went wrong. Please try again.',
              _ => 'Exchange failed. Please try again.',
            };
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
            );
          } catch (e, st) {
            Logger.error('Swap order failed', e, st);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Exchange failed. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    }
  }

  void _previousStep() {
    if (_step == _SwapStep.confirmation) {
      setState(() => _step = _SwapStep.input);
    }
  }

  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));

    _hydrateOwnedWalletsFromCache();
    _rate = _rates.getRate(_fromCurrency, _toCurrency);
    _loadOwnedWallets();

    // Listen to live rate updates
    _rates.ratesStream.listen((map) {
      if (mounted) {
        final newRate = _rates.getRate(_fromCurrency, _toCurrency);
        Logger.debug('📊 Rate stream update: $_fromCurrency/$_toCurrency = $newRate');
        setState(() {
          _rate = newRate;
        });
      }
    });
  }

  bool _isCryptoCurrency(String code) {
    final upper = code.toUpperCase();
    return upper == 'USDT' || upper == 'USDC';
  }

  void _hydrateOwnedWalletsFromCache() {
    final snap = DashboardSessionCache.instance.readWalletLastKnown();
    if (snap == null) return;

    final codes = <String>{
      ...snap.availableFiatCurrencies.map((c) => c.toUpperCase()),
      ...snap.availableCryptoCurrencies.map((c) => c.toUpperCase()),
    };
    if (codes.isEmpty) return;

    _ownedCurrencyCodes
      ..clear()
      ..addAll(codes);
    _ownedBalances
      ..clear()
      ..addEntries([
        for (final e in snap.fiatWallets.entries)
          MapEntry(e.key.toUpperCase(), e.value.balance),
        for (final e in snap.cryptoWallets.entries)
          MapEntry(e.key.toUpperCase(), e.value.balance),
      ]);
    _applyOwnedCurrencyDefaults();
    _fromBalance = _ownedBalances[_fromCurrency] ?? 0;
    _toBalance = _ownedBalances[_toCurrency] ?? 0;
    _loadingWallets = false;
    _loadingBalances = false;
  }

  void _applyOwnedCurrencyDefaults() {
    if (_ownedCurrencyCodes.isEmpty) return;

    final preferredFrom = widget.initialFromCurrency?.toUpperCase();
    if (preferredFrom != null && _ownedCurrencyCodes.contains(preferredFrom)) {
      _fromCurrency = preferredFrom;
    } else if (!_ownedCurrencyCodes.contains(_fromCurrency)) {
      _fromCurrency = _ownedCurrencyCodes.first;
    }

    final preferredTo = _isCryptoCurrency(_fromCurrency)
        ? _ownedCurrencyCodes.firstWhere(
            (c) => !_isCryptoCurrency(c),
            orElse: () => _ownedCurrencyCodes.firstWhere(
              (c) => c != _fromCurrency,
              orElse: () => _fromCurrency,
            ),
          )
        : _ownedCurrencyCodes.firstWhere(
            (c) => _isCryptoCurrency(c),
            orElse: () => _ownedCurrencyCodes.firstWhere(
              (c) => c != _fromCurrency,
              orElse: () => _fromCurrency,
            ),
          );

    _toCurrency = preferredTo == _fromCurrency && _ownedCurrencyCodes.length > 1
        ? _ownedCurrencyCodes.firstWhere((c) => c != _fromCurrency)
        : preferredTo;
  }

  Future<void> _loadOwnedWallets() async {
    if (!isFirebaseInitialized()) {
      if (mounted) {
        setState(() {
          _loadingWallets = false;
          _loadingBalances = false;
        });
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingWallets = false;
          _loadingBalances = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loadingWallets = true;
        _loadingBalances = true;
      });
    }

    try {
      final fiat = await _walletRepository.listOwnedFiatWallets(user.uid);
      final crypto = await _walletRepository.listOwnedCryptoWallets(user.uid);

      final codes = <String>{
        ...fiat.keys.map((c) => c.toUpperCase()),
        ...crypto.keys.map((c) => c.toUpperCase()),
      };

      // If RTDB parent listing is empty, fall back to probing known currencies
      // the same way the home wallet card does (existence = non-null fiat node).
      if (codes.isEmpty) {
        for (final currency in const ['KES', 'USD', 'NGN', 'GHS', 'UGX']) {
          try {
            final wallet =
                await _walletRepository.getWalletBalance(user.uid, currency: currency);
            if (wallet != null) {
              fiat[currency] = wallet;
              codes.add(currency);
            }
          } catch (_) {}
        }
        for (final currency in const ['USDT', 'USDC']) {
          try {
            final wallet =
                await _walletRepository.getCryptoWalletBalance(user.uid, currency);
            // Crypto helper returns a zero wallet even when missing — only keep
            // currencies that also appear in a successful parent list or cache.
            if (wallet != null) {
              final cached = DashboardSessionCache.instance
                  .readWalletLastKnown()
                  ?.availableCryptoCurrencies
                  .map((c) => c.toUpperCase())
                  .contains(currency);
              if (cached == true || wallet.balance > 0) {
                crypto[currency] = wallet;
                codes.add(currency);
              }
            }
          } catch (_) {}
        }
      }

      if (!mounted) return;

      setState(() {
        _ownedCurrencyCodes
          ..clear()
          ..addAll(codes);
        _ownedBalances
          ..clear()
          ..addEntries([
            for (final e in fiat.entries) MapEntry(e.key.toUpperCase(), e.value.balance),
            for (final e in crypto.entries) MapEntry(e.key.toUpperCase(), e.value.balance),
          ]);
        _applyOwnedCurrencyDefaults();
        _fromBalance = _ownedBalances[_fromCurrency] ?? 0;
        _toBalance = _ownedBalances[_toCurrency] ?? 0;
        _loadingWallets = false;
        _loadingBalances = false;
      });

      _rate = _rates.getRate(_fromCurrency, _toCurrency);
      await _loadRate();
    } catch (e, st) {
      Logger.error('Failed to load owned wallets for exchange', e, st);
      if (!mounted) return;
      setState(() {
        _loadingWallets = false;
        _loadingBalances = false;
      });
    }
  }
  
  Future<void> _loadRate() async {
    // Explicitly fetch the rate to ensure it's loaded
    Logger.debug('🔄 Loading rate for $_fromCurrency/$_toCurrency');
    await _rates.refreshRate(_fromCurrency, _toCurrency);
    if (mounted) {
      final newRate = _rates.getRate(_fromCurrency, _toCurrency);
      Logger.debug('✅ Rate loaded: $_fromCurrency/$_toCurrency = $newRate');
      setState(() {
        _rate = newRate;
      });
    }
  }

  Future<double> _balanceFor(String currency, String uid) async {
    final code = currency.toUpperCase();
    if (_isCryptoCurrency(code)) {
      final wallet = await _walletRepository.getCryptoWalletBalance(uid, code);
      return wallet?.balance ?? 0.0;
    }
    final wallet = await _walletRepository.getWalletBalance(uid, currency: code);
    return wallet?.balance ?? 0.0;
  }

  Future<void> _loadBalances() async {
    if (!isFirebaseInitialized()) {
      setState(() => _loadingBalances = false);
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loadingBalances = false);
        return;
      }

      setState(() => _loadingBalances = true);

      final fromBal = await _balanceFor(_fromCurrency, user.uid);
      final toBal = await _balanceFor(_toCurrency, user.uid);

      if (!mounted) return;
      setState(() {
        _fromBalance = fromBal;
        _toBalance = toBal;
        _ownedBalances[_fromCurrency] = fromBal;
        _ownedBalances[_toCurrency] = toBal;
        _loadingBalances = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingBalances = false);
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _fromCtrl.dispose();
    _rates.dispose();
    super.dispose();
  }

  Future<void> _showSuccessDialog() async {
    _confettiController.play();
    final navigator = Navigator.of(context);
    await showDialog(
      context: context,
      builder: (dialogContext) {
            final colors = AppColors.getThemeColors(context);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primary = Theme.of(context).colorScheme.primary;
            return Stack(
          alignment: Alignment.topCenter,
          children: [
            AlertDialog(
              backgroundColor: isDark 
                  ? AppColors.surfaceDark 
                  : Colors.white.withValues(alpha: 0.9), // Translucent white for light mode
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Center(
                child: Text(
                  'Exchange Successful',
                  style: TextStyle(color: colors.textPrimary),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: primary, size: 80),
                  const SizedBox(height: 16),
                  Text(
                    'Check history for all transactions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      navigator.pop(); // Dismiss dialog
                      navigator.pop(); // Pop exchange page to navigate to home
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple
              ],
            ),
          ],
        );
      },
    );
  }

  List<Currency> _ownedCurrencyOptions({String? excluding}) {
    final exclude = excluding?.toUpperCase();
    final codes = _ownedCurrencyCodes
        .where((code) => exclude == null || code != exclude)
        .toList()
      ..sort();

    // Keep at least the current selection if it's the only owned wallet.
    if (codes.isEmpty && excluding != null) {
      return [
        Currency(
          code: excluding,
          name: CurrencyLogo.displayNameFor(excluding),
          flagEmoji: CurrencyLogo.emojiFor(excluding),
        ),
      ];
    }

    return [
      for (final code in codes)
        Currency(
          code: code,
          name: CurrencyLogo.displayNameFor(code),
          flagEmoji: CurrencyLogo.emojiFor(code),
        ),
    ];
  }

  void _showCurrencyPicker(BuildContext context, bool isFromCurrency) {
    final other = isFromCurrency ? _toCurrency : _fromCurrency;
    final availableCurrencies = _ownedCurrencyOptions(excluding: other);

    if (availableCurrencies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No wallets available to exchange yet.'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => CurrencyPickerBottomSheet(
        currencies: availableCurrencies,
        selectedCode: isFromCurrency ? _fromCurrency : _toCurrency,
        onSelected: (currency) async {
          setState(() {
            if (isFromCurrency) {
              _fromCurrency = currency.code.toUpperCase();
              if (_toCurrency == _fromCurrency) {
                final alt = _ownedCurrencyCodes.firstWhere(
                  (c) => c != _fromCurrency,
                  orElse: () => _toCurrency,
                );
                _toCurrency = alt;
              }
            } else {
              _toCurrency = currency.code.toUpperCase();
              if (_fromCurrency == _toCurrency) {
                final alt = _ownedCurrencyCodes.firstWhere(
                  (c) => c != _toCurrency,
                  orElse: () => _fromCurrency,
                );
                _fromCurrency = alt;
              }
            }
            _fromCtrl.clear();
          });

          await _loadBalances();
          await _loadRate();

          if (mounted) {
            setState(() {
              _rate = _rates.getRate(_fromCurrency, _toCurrency);
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: colors.background, // Theme-aware background
      appBar: AppBar(
        backgroundColor: isDark
            ? Colors.transparent  // Transparent for dark mode
            : primary.withValues(alpha: 0.08), // Light mint tint (8% opacity) for light mode
        elevation: 0,
        title: Text(
          _step == _SwapStep.confirmation ? 'Confirm sending' : 'Exchange',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
        leading: _step == _SwapStep.confirmation
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                onPressed: _previousStep,
              )
            : null,
      ),
      body: _loadingWallets && _ownedCurrencyCodes.isEmpty
          ? const Center(child: PageContentShimmer(blocks: 3))
          : _ownedCurrencyCodes.length < 2
              ? _ExchangeNoWalletsState(
                  ownedCount: _ownedCurrencyCodes.length,
                  onRefresh: _loadOwnedWallets,
                )
              : IndexedStack(
                  index: _step.index,
                  children: [
                    _ExchangeInputScreen(
                      fromCtrl: _fromCtrl,
                      fromCurrency: _fromCurrency,
                      toCurrency: _toCurrency,
                      fromBalance: _fromBalance,
                      toBalance: _toBalance,
                      rate: _rate,
                      loadingBalances: _loadingBalances,
                      onSwapCurrencies: _swapCurrencies,
                      onNext: _nextStep,
                      onFromCurrencyTap: () => _showCurrencyPicker(context, true),
                      onToCurrencyTap: () => _showCurrencyPicker(context, false),
                    ),
                    _ExchangeConfirmationScreen(
                      fromAmount: double.tryParse(_fromCtrl.text) ?? 0,
                      fromCurrency: _fromCurrency,
                      toAmount: (double.tryParse(_fromCtrl.text) ?? 0) * _rate,
                      toCurrency: _toCurrency,
                      rate: _rate,
                      onNext: _nextStep,
                      isSubmitting: _isSubmittingSwap,
                    ),
                    // Success is a dialog, so this is just a placeholder
                    const SizedBox.shrink(),
                  ],
                ),
    );
  }
}

String _formatExchangeAmount(double amount, String currency) {
  if (amount <= 0) return '0.00';
  final isCrypto = currency.toUpperCase() == 'USDT' ||
      currency.toUpperCase() == 'USDC';
  if (isCrypto) {
    if (amount < 1) return amount.toStringAsFixed(6);
    return amount.toStringAsFixed(4);
  }
  return amount.toStringAsFixed(2);
}

class _ExchangeNoWalletsState extends StatelessWidget {
  const _ExchangeNoWalletsState({
    required this.ownedCount,
    required this.onRefresh,
  });

  final int ownedCount;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 56, color: colors.textTertiary),
            const SizedBox(height: 16),
            Text(
              ownedCount == 0
                  ? 'No wallets found'
                  : 'You need at least two wallets to exchange',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ownedCount == 0
                  ? 'Fund a fiat or crypto wallet, then try again.'
                  : 'Open another currency wallet on your home screen, then return here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRefresh,
              child: Text('Refresh', style: TextStyle(color: primary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExchangeInputScreen extends StatefulWidget {
  final VoidCallback onNext;
  final TextEditingController fromCtrl;
  final String fromCurrency;
  final String toCurrency;
  final double fromBalance;
  final double toBalance;
  final double rate;
  final bool loadingBalances;
  final VoidCallback onSwapCurrencies;
  final VoidCallback onFromCurrencyTap;
  final VoidCallback onToCurrencyTap;

  const _ExchangeInputScreen({
    required this.onNext,
    required this.fromCtrl,
    required this.fromCurrency,
    required this.toCurrency,
    required this.fromBalance,
    required this.toBalance,
    required this.rate,
    required this.loadingBalances,
    required this.onSwapCurrencies,
    required this.onFromCurrencyTap,
    required this.onToCurrencyTap,
  });

  @override
  State<_ExchangeInputScreen> createState() => _ExchangeInputScreenState();
}

class _ExchangeInputScreenState extends State<_ExchangeInputScreen> {
  @override
  void initState() {
    super.initState();
    widget.fromCtrl.addListener(_onAmountChanged);
  }

  @override
  void didUpdateWidget(_ExchangeInputScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rate != widget.rate ||
        oldWidget.fromCurrency != widget.fromCurrency ||
        oldWidget.toCurrency != widget.toCurrency) {
      _onAmountChanged();
    }
  }

  @override
  void dispose() {
    widget.fromCtrl.removeListener(_onAmountChanged);
    super.dispose();
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fromAmount = double.tryParse(widget.fromCtrl.text) ?? 0;
    final toAmount = fromAmount * widget.rate;
    final canContinue = fromAmount > 0 && widget.rate > 0;

    // Soft filled CTA like the reference (light primary when enabled).
    final continueBg = canContinue
        ? (isDark ? primary.withValues(alpha: 0.85) : primary)
        : colors.surfaceVariant.withValues(alpha: isDark ? 0.55 : 0.9);
    final continueFg = canContinue ? Colors.white : colors.textTertiary;

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  Expanded(
                    child: _ExchangePanel(
                      label: 'Send',
                      currency: widget.fromCurrency,
                      balance: widget.fromBalance,
                      loading: widget.loadingBalances,
                      controller: widget.fromCtrl,
                      onAssetTap: widget.onFromCurrencyTap,
                      isTop: true,
                    ),
                  ),
                  Expanded(
                    child: _ExchangePanel(
                      label: 'Get',
                      currency: widget.toCurrency,
                      balance: widget.toBalance,
                      loading: widget.loadingBalances,
                      displayAmount: _formatExchangeAmount(
                        toAmount,
                        widget.toCurrency,
                      ),
                      onAssetTap: widget.onToCurrencyTap,
                      isTop: false,
                    ),
                  ),
                ],
              ),
              // Flip control sitting on the seam between panels.
              Material(
                color: colors.background,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onSwapCurrencies,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A2332) : colors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE5E7EB),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.swap_vert_rounded,
                      color: colors.textPrimary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (fromAmount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(
              widget.rate > 0
                  ? '1 ${widget.fromCurrency} = ${widget.rate.toStringAsFixed(4)} ${widget.toCurrency}'
                  : 'Loading rate...',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: canContinue ? widget.onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: continueBg,
                  foregroundColor: continueFg,
                  disabledBackgroundColor: continueBg,
                  disabledForegroundColor: continueFg,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: continueFg,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 22, color: continueFg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExchangePanel extends StatelessWidget {
  const _ExchangePanel({
    required this.label,
    required this.currency,
    required this.balance,
    required this.onAssetTap,
    required this.isTop,
    this.loading = false,
    this.controller,
    this.displayAmount,
  });

  final String label;
  final String currency;
  final double balance;
  final bool loading;
  final TextEditingController? controller;
  final String? displayAmount;
  final VoidCallback onAssetTap;
  final bool isTop;

  static const _noBorder = OutlineInputBorder(
    borderSide: BorderSide.none,
    borderRadius: BorderRadius.zero,
  );

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Slightly different shades for Send vs Get, matching the reference stack.
    final panelColor = isDark
        ? (isTop ? const Color(0xFF151C2A) : const Color(0xFF0F1520))
        : (isTop ? Colors.white : const Color(0xFFF8FAFC));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, isTop ? 12 : 28, 20, isTop ? 28 : 12),
      color: panelColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (controller != null)
            // Borderless amount field — theme input borders are forced off.
            Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  border: _noBorder,
                  enabledBorder: _noBorder,
                  focusedBorder: _noBorder,
                  disabledBorder: _noBorder,
                  errorBorder: _noBorder,
                  focusedErrorBorder: _noBorder,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                cursorColor: Theme.of(context).colorScheme.primary,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  height: 1.1,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    color: colors.textTertiary.withValues(alpha: 0.7),
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            )
          else
            Text(
              displayAmount ?? '0.00',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                height: 1.1,
              ),
            ),
          const Spacer(),
          Text(
            'Asset',
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onAssetTap,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                CurrencyLogo(code: currency, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            currency,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              currency == 'USDT' || currency == 'USDC'
                                  ? 'Crypto'
                                  : 'Fiat',
                              style: TextStyle(
                                color: colors.textTertiary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loading
                            ? 'Loading…'
                            : '${CurrencyLogo.displayNameFor(currency)} · Bal ${balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExchangeConfirmationScreen extends StatelessWidget {
  final VoidCallback onNext;
  final double fromAmount;
  final String fromCurrency;
  final double toAmount;
  final String toCurrency;
  final double rate;
  final bool isSubmitting;

  const _ExchangeConfirmationScreen({
    required this.onNext,
    required this.fromAmount,
    required this.fromCurrency,
    required this.toAmount,
    required this.toCurrency,
    required this.rate,
    this.isSubmitting = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fee = fromAmount * 0.005;
    final cardColor = isDark ? colors.surface : Colors.white.withValues(alpha: 0.95);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              _ConfirmLegCard(
                label: 'Send',
                amount: _formatExchangeAmount(fromAmount, fromCurrency),
                currency: fromCurrency,
                color: cardColor,
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_downward_rounded,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              _ConfirmLegCard(
                label: 'Get',
                amount: _formatExchangeAmount(toAmount, toCurrency),
                currency: toCurrency,
                color: cardColor,
              ),
              const SizedBox(height: 28),
              _ConfirmMetaRow(
                label: 'Exchange rate',
                value: rate > 0
                    ? '1 $fromCurrency = ${rate.toStringAsFixed(4)} $toCurrency'
                    : '—',
              ),
              const SizedBox(height: 14),
              _ConfirmMetaRow(
                label: 'Network fee',
                value: '${_formatExchangeAmount(fee, fromCurrency)} $fromCurrency',
              ),
              const SizedBox(height: 14),
              const _ConfirmMetaRow(
                label: 'Estimated arrival',
                value: 'Instant',
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SlideToConfirm(
              enabled: fromAmount > 0 && !isSubmitting,
              isLoading: isSubmitting,
              onConfirmed: onNext,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmLegCard extends StatelessWidget {
  const _ConfirmLegCard({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  final String label;
  final String amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? colors.border.withValues(alpha: 0.4)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              CurrencyLogo(code: currency, size: 20),
              const SizedBox(width: 6),
              Text(
                currency,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmMetaRow extends StatelessWidget {
  const _ConfirmMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
