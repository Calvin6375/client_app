import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/models/transaction_details_model.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/features/swap/services/rates_service.dart';
import 'package:pretium/features/swap/widgets/currency_picker_bottom_sheet.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/widgets/currency_logo.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretium/utils/firebase_utils.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/bottom_safe_action_bar.dart';

class SendAmountScreen extends StatefulWidget {
  final VoidCallback onNext;
  final Function(TransactionDetails) onUpdate;
  final TransactionDetails initialDetails;
  final bool kenyaOnly;

  const SendAmountScreen({
    super.key,
    required this.onNext,
    required this.onUpdate,
    required this.initialDetails,
    this.kenyaOnly = false,
  });

  @override
  State<SendAmountScreen> createState() => _SendAmountScreenState();
}

class _SendAmountScreenState extends State<SendAmountScreen> {
  late final TextEditingController _fromCtrl;
  late String _fromCurrency;
  late String _toCurrency;
  final WalletRepository _walletRepository = WalletRepository();
  final RatesService _ratesService = RatesService();
  double _fromBalance = 0.0;
  double _toBalance = 0.0;
  double _rate = 1.0;
  bool _loadingBalances = true;

  // Available currencies for Send Money
  static const List<Currency> _availableCurrencies = [
    Currency(code: 'USD', name: 'US Dollar', flagEmoji: '🇺🇸'),
    Currency(code: 'KES', name: 'Kenyan Shilling', flagEmoji: '🇰🇪'),
    Currency(code: 'NGN', name: 'Nigerian Naira', flagEmoji: '🇳🇬'),
    Currency(code: 'USDT', name: 'Tether', flagEmoji: '₮'),
  ];

  String _flagFor(String code) {
    for (final c in _availableCurrencies) {
      if (c.code == code) return c.flagEmoji;
    }
    return '🌍';
  }

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController();
    _fromCurrency = widget.kenyaOnly
        ? 'KES'
        : (widget.initialDetails.fromCurrency.isNotEmpty
            ? widget.initialDetails.fromCurrency
            : 'USD');
    _toCurrency = widget.kenyaOnly
        ? 'KES'
        : (widget.initialDetails.toCurrency.isNotEmpty
            ? widget.initialDetails.toCurrency
            : (_fromCurrency == 'USD' ? 'USDT' : 'USD'));

    _fromCtrl.addListener(_onAmountChanged);
    _loadBalances();
    if (widget.kenyaOnly) {
      _rate = 1.0;
    } else {
      _loadRate();
    }
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

      // Load wallets based on currencies
      if (widget.kenyaOnly) {
        final kesWallet =
            await _walletRepository.getWalletBalance(user.uid, currency: 'KES');
        if (!mounted) return;
        _fromBalance = kesWallet?.balance ?? 0.0;
        _toBalance = _fromBalance;
      } else {
        final fiatWallet = await _walletRepository.getWalletBalance(user.uid);
        final cryptoWallet =
            await _walletRepository.getCryptoWalletBalance(user.uid, 'USDT');

        if (!mounted) return;

        if (_fromCurrency == 'USD') {
          _fromBalance = fiatWallet?.balance ?? 0.0;
        } else if (_fromCurrency == 'USDT') {
          _fromBalance = cryptoWallet?.balance ?? 0.0;
        } else if (_fromCurrency == 'KES') {
          final kesWallet =
              await _walletRepository.getWalletBalance(user.uid, currency: 'KES');
          _fromBalance = kesWallet?.balance ?? 0.0;
        } else {
          _fromBalance = 0.0;
        }

        if (_toCurrency == 'USD') {
          _toBalance = fiatWallet?.balance ?? 0.0;
        } else if (_toCurrency == 'USDT') {
          _toBalance = cryptoWallet?.balance ?? 0.0;
        } else if (_toCurrency == 'KES') {
          final kesWallet =
              await _walletRepository.getWalletBalance(user.uid, currency: 'KES');
          _toBalance = kesWallet?.balance ?? 0.0;
        } else {
          _toBalance = 0.0;
        }
      }

      setState(() => _loadingBalances = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingBalances = false);
    }
  }

  void _loadRate() {
    // Calculate rate based on currency pair
    // Always calculate through USDT as intermediary
    _updateRate();
    
    // Listen to live rate updates
    _ratesService.ratesStream.listen((map) {
      if (mounted) {
        setState(() {
          _updateRate();
          _onAmountChanged(); // Recalculate received amount
        });
      }
    });
  }

  void _updateRate() {
    // Calculate rate through USDT as intermediary
    if (_fromCurrency == 'USDT' || _toCurrency == 'USDT') {
      // Direct USDT pair
      _rate = _ratesService.getRate(_fromCurrency, _toCurrency);
    } else {
      // Fiat-to-fiat: Calculate through USDT
      // Example: KES -> USD = (KES -> USDT) * (USDT -> USD)
      // RatesService already handles inverse rates, so we can call directly
      
      final fromToUsdt = _ratesService.getRate(_fromCurrency, 'USDT');
      final usdtToTo = _ratesService.getRate('USDT', _toCurrency);
      
      _rate = fromToUsdt * usdtToTo;
    }
  }

  void _onAmountChanged() {
    final amount = double.tryParse(_fromCtrl.text) ?? 0;
    final receiveAmount = widget.kenyaOnly ? amount : amount * _rate;
    widget.onUpdate(
      TransactionDetails(
        amountToSend: amount,
        fromCurrency: _fromCurrency,
        amountToReceive: receiveAmount,
        toCurrency: _toCurrency,
      ),
    );
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
      
      // Swap balances
      final tempBalance = _fromBalance;
      _fromBalance = _toBalance;
      _toBalance = tempBalance;
      
      // Clear input
      _fromCtrl.clear();
      
      // Reload rate and balances
      _loadRate();
      _loadBalances();
    });
    _onAmountChanged();
  }

  void _showCurrencyPicker(bool isFromCurrency) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => CurrencyPickerBottomSheet(
        currencies: _availableCurrencies,
        selectedCode: isFromCurrency ? _fromCurrency : _toCurrency,
        onSelected: (currency) {
          setState(() {
            if (isFromCurrency) {
              // Prevent selecting the same currency for both from and to
              if (currency.code != _toCurrency) {
                _fromCurrency = currency.code;
                _fromCtrl.clear();
                _loadBalances();
                _loadRate();
                _onAmountChanged();
              }
            } else {
              // Prevent selecting the same currency for both from and to
              if (currency.code != _fromCurrency) {
                _toCurrency = currency.code;
                _loadBalances();
                _loadRate();
                _onAmountChanged();
              }
            }
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    _fromCtrl.removeListener(_onAmountChanged);
    _fromCtrl.dispose();
    _ratesService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final amountToSend = double.tryParse(_fromCtrl.text.trim()) ?? 0;
    final canContinue = amountToSend > 0;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ListView(
              children: [
                if (widget.kenyaOnly) ...[
                  Text(
                    'Send from your KES wallet in Kenya',
                    style: TextStyle(
                      color: AppColors.getThemeColors(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _SwapCurrencyCard(
                  label: widget.kenyaOnly ? 'Amount (KES)' : 'You Send',
                  currency: _fromCurrency,
                  flagEmoji: _flagFor(_fromCurrency),
                  balance: _fromBalance,
                  loading: _loadingBalances,
                  controller: _fromCtrl,
                  onCurrencyTap:
                      widget.kenyaOnly ? () {} : () => _showCurrencyPicker(true),
                ),
                if (!widget.kenyaOnly) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: IconButton(
                      icon: Icon(Icons.swap_vert, color: primaryColor, size: 32),
                      onPressed: _swapCurrencies,
                      style: IconButton.styleFrom(
                        backgroundColor: primaryColor.withValues(alpha: 0.15),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SwapCurrencyCard(
                    label: 'You Receive',
                    currency: _toCurrency,
                    flagEmoji: _flagFor(_toCurrency),
                    balance: _toBalance,
                    loading: _loadingBalances,
                    amount: (double.tryParse(_fromCtrl.text) ?? 0) * _rate,
                    onCurrencyTap: () => _showCurrencyPicker(false),
                  ),
                  const SizedBox(height: 16),
                  _ExchangeRateDisplay(
                    fromCurrency: _fromCurrency,
                    toCurrency: _toCurrency,
                    rate: _rate,
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        BottomSafeActionBar(
          child: ElevatedButton(
            onPressed: canContinue ? widget.onNext : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: primaryColor.withValues(alpha: 0.38),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.62),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExchangeRateDisplay extends StatelessWidget {
  final String fromCurrency;
  final String toCurrency;
  final double rate;

  const _ExchangeRateDisplay({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark 
            ? colors.surface // Dark slate for dark mode
            : Colors.white.withValues(alpha: 0.9), // Translucent white for light mode
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark 
                ? colors.surfaceVariant
              : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            '1 $fromCurrency = ${rate.toStringAsFixed(4)} $toCurrency',
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwapCurrencyCard extends StatelessWidget {
  final String label;
  final String currency;
  final String flagEmoji;
  final double balance;
  final bool loading;
  final TextEditingController? controller;
  final double? amount;
  final VoidCallback onCurrencyTap;

  const _SwapCurrencyCard({
    required this.label,
    required this.currency,
    required this.flagEmoji,
    required this.balance,
    this.loading = false,
    this.controller,
    this.amount,
    required this.onCurrencyTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? colors.surface // Dark slate for dark mode
            : Colors.white.withValues(alpha: 0.9), // Translucent white for light mode
        borderRadius: BorderRadius.circular(16),
        border: isDark 
            ? null
            : Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1,
              ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(color: colors.textSecondary),
              ),
              if (loading)
                const ShimmerBusyIndicator(width: 64, height: 12)
              else
                Text(
                  'Balance: ${balance.toStringAsFixed(2)}',
                  style: TextStyle(color: colors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: onCurrencyTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? colors.background 
                        : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      CurrencyLogo(
                        code: currency,
                        size: 20,
                        fallbackEmoji: flagEmoji,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currency,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colors.textPrimary,
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down, size: 20, color: colors.textPrimary),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (controller != null)
                Expanded(
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.end,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    maxLength: 100000,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '0.00',
                      hintStyle: TextStyle(color: colors.textSecondary),
                      counterText: '',
                    ),
                  ),
                )
              else
                Text(
                  amount?.toStringAsFixed(2) ?? '0.00',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
