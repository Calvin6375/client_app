import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:pretium/features/swap/services/rates_service.dart';
import 'package:pretium/features/swap/widgets/currency_picker_bottom_sheet.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/services/order_service.dart';
import 'package:pretium/utils/logger.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

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
  final _orderService = OrderService();
  final _fromCtrl = TextEditingController();
  String _fromCurrency = 'USD';
  String _toCurrency = 'USDT';
  double _fromBalance = 0.0;
  double _toBalance = 0.0;
  bool _loadingBalances = true;
  late double _rate;

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
      
      // Refetch rate
      _rate = _rates.getRate(_fromCurrency, _toCurrency);
      _loadRate();
    });
  }

  void _nextStep() async {
    if (_step == _SwapStep.input) {
      setState(() => _step = _SwapStep.confirmation);
    } else if (_step == _SwapStep.confirmation) {
      // Create order when swap is confirmed
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final fromAmount = double.tryParse(_fromCtrl.text) ?? 0;
          await _orderService.createOrder(
            userId: user.uid,
            amount: fromAmount,
            currency: _fromCurrency,
            orderType: 'swap',
            metadata: {
              'fromCurrency': _fromCurrency,
              'toCurrency': _toCurrency,
              'fromAmount': fromAmount,
              'toAmount': fromAmount * _rate,
              'rate': _rate,
            },
          );
          print('✅ Swap order created in Firestore');
        }
      } catch (e) {
        print('⚠️ Failed to create swap order: $e');
        // Don't block the swap flow if order creation fails
      }
      
      setState(() => _step = _SwapStep.success);
      _showSuccessDialog();
    }
  }

  void _previousStep() {
    if (_step == _SwapStep.confirmation) {
      setState(() => _step = _SwapStep.input);
    }
  }

  late ConfettiController _confettiController;

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
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    
    // Set initial currency from parameter or default
    if (widget.initialFromCurrency != null) {
      _fromCurrency = widget.initialFromCurrency!;
      // Default to USDT if from currency is fiat, otherwise default to USD
      _toCurrency = _fromCurrency == 'USDT' ? 'USD' : 'USDT';
    }
    
    _rate = _rates.getRate(_fromCurrency, _toCurrency);
    _loadBalances();
    _loadRate();

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

      // Load balance for "from" currency
      if (_fromCurrency == 'USDT') {
        final cryptoWallet = await _walletRepository.getCryptoWalletBalance(user.uid, 'USDT');
        _fromBalance = cryptoWallet?.balance ?? 0.0;
      } else {
        // Load fiat wallet for the currency (USD, KES, NGN, GHS)
        final fiatWallet = await _walletRepository.getWalletBalance(user.uid, currency: _fromCurrency);
        _fromBalance = fiatWallet?.balance ?? 0.0;
      }

      // Load balance for "to" currency
      if (_toCurrency == 'USDT') {
        final cryptoWallet = await _walletRepository.getCryptoWalletBalance(user.uid, 'USDT');
        _toBalance = cryptoWallet?.balance ?? 0.0;
      } else {
        // Load fiat wallet for the currency (USD, KES, NGN, GHS)
        final fiatWallet = await _walletRepository.getWalletBalance(user.uid, currency: _toCurrency);
        _toBalance = fiatWallet?.balance ?? 0.0;
      }

      if (!mounted) return;
      setState(() => _loadingBalances = false);
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
    await showDialog(
      context: context,
      builder: (context) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            AlertDialog(
              backgroundColor: AppColors.surfaceDark, // Dark slate card
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Center(
                child: Text(
                  'Swap Successful',
                  style: TextStyle(color: AppColors.textPrimaryLight),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: AppColors.brandPrimary, size: 80),
                  const SizedBox(height: 16),
                  Text(
                    'Check history for all transactions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondaryCool),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() => _step = _SwapStep.input);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.backgroundDeepNavy,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.backgroundDeepNavy,
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

  void _showCurrencyPicker(BuildContext context, bool isFromCurrency) {
    final availableCurrencies = [
      const Currency(code: 'USD', name: 'US Dollar', flagEmoji: '🇺🇸'),
      const Currency(code: 'KES', name: 'Kenyan Shilling', flagEmoji: '🇰🇪'),
      const Currency(code: 'NGN', name: 'Nigerian Naira', flagEmoji: '🇳🇬'),
      const Currency(code: 'GHS', name: 'Ghanaian Cedi', flagEmoji: '🇬🇭'),
      const Currency(code: 'USDT', name: 'Tether', flagEmoji: '₮'),
    ];
    
    showModalBottomSheet(
      context: context,
      builder: (context) => CurrencyPickerBottomSheet(
        currencies: availableCurrencies,
        selectedCode: isFromCurrency ? _fromCurrency : _toCurrency,
        onSelected: (currency) async {
          setState(() {
            if (isFromCurrency) {
              _fromCurrency = currency.code;
              // Don't auto-select - let user choose the other currency
            } else {
              _toCurrency = currency.code;
              // Don't auto-select - let user choose the other currency
            }
            // Clear input when currency changes
            _fromCtrl.clear();
          });
          
          // Load balances and refresh rate after state update
          await _loadBalances();
          await _loadRate();
          
          // Force UI update with new rate
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
    return Scaffold(
      backgroundColor: AppColors.backgroundDeepNavy, // Deep navy background
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparent for dark theme
        elevation: 0,
        title: Text('Swap', style: TextStyle(color: AppColors.textPrimaryLight)),
        leading: _step == _SwapStep.confirmation
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.textPrimaryLight),
                onPressed: _previousStep,
              )
            : null,
      ),
      body: IndexedStack(
        index: _step.index,
        children: [
          _SwapInputScreen(
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
          _SwapConfirmationScreen(
            fromAmount: double.tryParse(_fromCtrl.text) ?? 0,
            fromCurrency: _fromCurrency,
            toAmount: (double.tryParse(_fromCtrl.text) ?? 0) * _rate,
            toCurrency: _toCurrency,
            rate: _rate,
            onNext: _nextStep,
          ),
          // Success is a dialog, so this is just a placeholder
          const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _SwapInputScreen extends StatefulWidget {
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

  const _SwapInputScreen({
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
  State<_SwapInputScreen> createState() => _SwapInputScreenState();
}

class _SwapInputScreenState extends State<_SwapInputScreen> {
  @override
  void initState() {
    super.initState();
    // Listen to text changes to update the received amount
    widget.fromCtrl.addListener(_onAmountChanged);
  }

  @override
  void didUpdateWidget(_SwapInputScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If rate or currencies changed, update the received amount
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
    // Trigger rebuild when amount changes to recalculate received amount
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final fromAmount = double.tryParse(widget.fromCtrl.text) ?? 0;
    final toAmount = fromAmount * widget.rate;
    // Calculate fee (e.g., 0.5% of the swap amount)
    final fee = fromAmount * 0.005;
    final totalFromAmount = fromAmount + fee;
    
    // Log fee calculation
    if (fromAmount > 0) {
      Logger.debug('💰 FEE CALCULATION');
      Logger.debug('  From Amount: $fromAmount ${widget.fromCurrency}');
      Logger.debug('  Fee Rate: 0.5% (0.005)');
      Logger.debug('  Calculated Fee: $fee ${widget.fromCurrency}');
      Logger.debug('  Total Amount: $totalFromAmount ${widget.fromCurrency}');
      Logger.debug('  Exchange Rate: ${widget.rate}');
      Logger.debug('  To Amount: $toAmount ${widget.toCurrency}');
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const SizedBox(height: 8),
              _SwapCurrencyCard(
                label: 'You Send',
                currency: widget.fromCurrency,
                balance: widget.fromBalance,
                loading: widget.loadingBalances,
                controller: widget.fromCtrl,
                onCurrencyTap: widget.onFromCurrencyTap,
              ),
              const SizedBox(height: 8),
              Center(
                child: IconButton(
                  icon: Icon(Icons.swap_vert, color: AppColors.brandPrimary, size: 32),
                  onPressed: widget.onSwapCurrencies,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary.withOpacity(0.15),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _SwapCurrencyCard(
                label: 'You Receive',
                currency: widget.toCurrency,
                balance: widget.toBalance,
                loading: widget.loadingBalances,
                amount: toAmount,
                onCurrencyTap: widget.onToCurrencyTap,
              ),
              const SizedBox(height: 16),
              // Exchange rate display
              _ExchangeRateDisplay(
                fromCurrency: widget.fromCurrency,
                toCurrency: widget.toCurrency,
                rate: widget.rate,
              ),
              const SizedBox(height: 24),
              // Fees component
              if (fromAmount > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark, // Dark slate card
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Network Fee',
                            style: TextStyle(
                              color: AppColors.textSecondaryCool,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${fee.toStringAsFixed(5)} ${widget.fromCurrency}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(
                              color: AppColors.textSecondaryCool,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${totalFromAmount.toStringAsFixed(5)} ${widget.fromCurrency}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Button at bottom
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundDeepNavy,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: fromAmount > 0 ? widget.onNext : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: fromAmount > 0 ? AppColors.brandPrimary : AppColors.textTertiary,
                  foregroundColor: AppColors.backgroundDeepNavy,
                  disabledBackgroundColor: AppColors.textTertiary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Confirm and Swap',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.backgroundDeepNavy,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SwapCurrencyCard extends StatelessWidget {
  final String label;
  final String currency;
  final double balance;
  final bool loading;
  final TextEditingController? controller;
  final double? amount; // Used for the "You Receive" card
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
        color: AppColors.surfaceDark, // Dark slate card #1E293B
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
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
              Text(label, style: TextStyle(color: AppColors.textSecondaryCool)),
              if (loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandPrimary,
                  ),
                )
              else
                Text(
                  'Balance: ${balance.toStringAsFixed(2)}',
                  style: TextStyle(color: AppColors.textSecondaryCool),
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
                    color: AppColors.backgroundDeepNavy,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.surfaceVariantDark),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        currency == 'USD' ? Icons.attach_money : Icons.currency_bitcoin,
                        size: 20,
                        color: AppColors.textPrimaryLight,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        currency,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: AppColors.textPrimaryLight,
                      ),
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
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '0.00',
                      hintStyle: TextStyle(color: AppColors.textTertiary),
                    ),
                  ),
                )
              else
                Text(
                  amount?.toStringAsFixed(5) ?? '0.00',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}


class _SwapConfirmationScreen extends StatelessWidget {
  final VoidCallback onNext;
  final double fromAmount;
  final String fromCurrency;
  final double toAmount;
  final String toCurrency;
  final double rate;

  const _SwapConfirmationScreen({
    required this.onNext,
    required this.fromAmount,
    required this.fromCurrency,
    required this.toAmount,
    required this.toCurrency,
    required this.rate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'Swap Details',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark, // Dark slate card
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _DetailItem(label: 'From', amount: fromAmount, currency: fromCurrency),
                Divider(height: 32, color: AppColors.surfaceVariantDark),
                _DetailItem(label: 'To', amount: toAmount, currency: toCurrency, isReceiving: true),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.backgroundDeepNavy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(
              'Confirm Swap',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.backgroundDeepNavy,
              ),
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
    // Handle invalid or zero rates
    final isValidRate = rate > 0 && rate.isFinite;
    final displayRate = isValidRate ? rate : 0.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark, // Dark slate card
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.surfaceVariantDark,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.textSecondaryCool,
          ),
          const SizedBox(width: 8),
          Text(
            isValidRate 
                ? '1 $fromCurrency = ${displayRate.toStringAsFixed(4)} $toCurrency'
                : 'Loading rate...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryCool,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final bool isReceiving;

  const _DetailItem({
    required this.label,
    required this.amount,
    required this.currency,
    this.isReceiving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondaryCool,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        Text(
          '${isReceiving ? '' : '-'}${amount.toStringAsFixed(5)}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(width: 8),
        // TODO: Add currency icon
        Icon(Icons.currency_bitcoin, size: 20, color: AppColors.textPrimaryLight),
        const SizedBox(width: 4),
        Text(
          currency,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }
}
