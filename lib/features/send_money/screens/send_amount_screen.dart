import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/core/providers/wallet_accounts_provider.dart';
import 'package:pretium/models/transaction_details_model.dart';
import 'package:pretium/features/swap/widgets/currency_picker_bottom_sheet.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/widgets/currency_logo.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/bottom_safe_action_bar.dart';

class SendAmountScreen extends ConsumerStatefulWidget {
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
  ConsumerState<SendAmountScreen> createState() => _SendAmountScreenState();
}

class _SendAmountScreenState extends ConsumerState<SendAmountScreen> {
  late final TextEditingController _fromCtrl;
  late String _fromCurrency;
  late String _toCurrency;
  double _rate = 1.0;
  StreamSubscription<Map<String, double>>? _ratesSub;

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
    if (widget.kenyaOnly) {
      _rate = 1.0;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadRate();
      });
    }
  }

  @override
  void dispose() {
    _ratesSub?.cancel();
    _fromCtrl.removeListener(_onAmountChanged);
    _fromCtrl.dispose();
    super.dispose();
  }

  double _balanceFor(String code) {
    final snap = ref.read(walletAccountsProvider).valueOrNull;
    final upper = code.toUpperCase();
    return snap?.fiatWallets[upper]?.balance ??
        snap?.cryptoWallets[upper]?.balance ??
        0;
  }

  void _loadRate() {
    _updateRate();
    _ratesSub?.cancel();
    _ratesSub = ref.read(ratesServiceProvider).ratesStream.listen((_) {
      if (!mounted) return;
      setState(() {
        _updateRate();
        _onAmountChanged();
      });
    });
  }

  void _updateRate() {
    final rates = ref.read(ratesServiceProvider);
    if (_fromCurrency == 'USDT' || _toCurrency == 'USDT') {
      _rate = rates.getRate(_fromCurrency, _toCurrency);
    } else {
      final fromToUsdt = rates.getRate(_fromCurrency, 'USDT');
      final usdtToTo = rates.getRate('USDT', _toCurrency);
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
      _fromCtrl.clear();
      _loadRate();
    });
    _onAmountChanged();
  }

  void _showCurrencyPicker(bool isFromCurrency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
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
                _loadRate();
                _onAmountChanged();
              }
            } else {
              // Prevent selecting the same currency for both from and to
              if (currency.code != _fromCurrency) {
                _toCurrency = currency.code;
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
  Widget build(BuildContext context) {
    final accounts = ref.watch(walletAccountsProvider);
    final fromBalance = _balanceFor(_fromCurrency);
    final toBalance = _balanceFor(_toCurrency);
    final loadingBalances = accounts.isLoading && accounts.valueOrNull == null;
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
                  balance: fromBalance,
                  loading: loadingBalances,
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
                    balance: toBalance,
                    loading: loadingBalances,
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
