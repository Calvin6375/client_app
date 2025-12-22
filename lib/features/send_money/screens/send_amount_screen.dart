import 'package:flutter/material.dart';
import 'package:pretium/models/transaction_details_model.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/features/swap/services/rates_service.dart';
import 'package:pretium/features/swap/widgets/currency_picker_bottom_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class SendAmountScreen extends StatefulWidget {
  final VoidCallback onNext;
  final Function(TransactionDetails) onUpdate;
  final TransactionDetails initialDetails;
  const SendAmountScreen({
    super.key,
    required this.onNext,
    required this.onUpdate,
    required this.initialDetails,
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

  bool _isFirebaseInitialized() {
    try {
      Firebase.app();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController();
    _fromCurrency = widget.initialDetails.fromCurrency.isNotEmpty 
        ? widget.initialDetails.fromCurrency 
        : 'USD';
    _toCurrency = widget.initialDetails.toCurrency.isNotEmpty 
        ? widget.initialDetails.toCurrency 
        : (_fromCurrency == 'USD' ? 'USDT' : 'USD');

    _fromCtrl.addListener(_onAmountChanged);
    _loadBalances();
    _loadRate();
  }

  Future<void> _loadBalances() async {
    if (!_isFirebaseInitialized()) {
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
      final fiatWallet = await _walletRepository.getWalletBalance(user.uid);
      final cryptoWallet = await _walletRepository.getCryptoWalletBalance(user.uid, 'USDT');

      if (!mounted) return;

      // Set balances based on current currencies
      // For now, we only have USD fiat wallet and USDT crypto wallet
      // KES and NGN balances would need to be fetched separately if available
      if (_fromCurrency == 'USD') {
        _fromBalance = fiatWallet?.balance ?? 0.0;
      } else if (_fromCurrency == 'USDT') {
        _fromBalance = cryptoWallet?.balance ?? 0.0;
      } else {
        // KES, NGN - for now show 0.00 (would need separate wallet balance calls)
        _fromBalance = 0.0;
      }

      if (_toCurrency == 'USD') {
        _toBalance = fiatWallet?.balance ?? 0.0;
      } else if (_toCurrency == 'USDT') {
        _toBalance = cryptoWallet?.balance ?? 0.0;
      } else {
        // KES, NGN - for now show 0.00 (would need separate wallet balance calls)
        _toBalance = 0.0;
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
    widget.onUpdate(
      TransactionDetails(
        amountToSend: amount,
        fromCurrency: _fromCurrency,
        amountToReceive: amount * _rate,
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
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _SwapCurrencyCard(
                  label: 'You Send',
                  currency: _fromCurrency,
                  balance: _fromBalance,
                  loading: _loadingBalances,
                  controller: _fromCtrl,
                  onCurrencyTap: () => _showCurrencyPicker(true),
                ),
                const SizedBox(height: 8),
                Center(
                  child: IconButton(
                    icon: Icon(Icons.swap_vert, color: primaryColor, size: 32),
                    onPressed: _swapCurrencies,
                    style: IconButton.styleFrom(
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _SwapCurrencyCard(
                  label: 'You Receive',
                  currency: _toCurrency,
                  balance: _toBalance,
                  loading: _loadingBalances,
                  amount: (double.tryParse(_fromCtrl.text) ?? 0) * _rate,
                  onCurrencyTap: () => _showCurrencyPicker(false),
                ),
                const SizedBox(height: 16),
                // Exchange rate display
                _ExchangeRateDisplay(
                  fromCurrency: _fromCurrency,
                  toCurrency: _toCurrency,
                  rate: _rate,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: widget.onNext,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
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
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: textColor,
          ),
          const SizedBox(width: 8),
          Text(
            '1 $fromCurrency = ${rate.toStringAsFixed(4)} $toCurrency',
            style: TextStyle(
              fontSize: 14,
              color: textColor,
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
  final double balance;
  final bool loading;
  final TextEditingController? controller;
  final double? amount;
  final VoidCallback onCurrencyTap;

  const _SwapCurrencyCard({
    required this.label,
    required this.currency,
    required this.balance,
    this.loading = false,
    this.controller,
    this.amount,
    required this.onCurrencyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey)),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  'Balance: ${balance.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.grey),
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
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.public, size: 20),
                      const SizedBox(width: 8),
                      Text(currency, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Icon(Icons.keyboard_arrow_down, size: 20),
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
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '0.00',
                    ),
                  ),
                )
              else
                Text(
                  amount?.toStringAsFixed(2) ?? '0.00',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
