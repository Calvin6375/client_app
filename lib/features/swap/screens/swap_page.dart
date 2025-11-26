import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:pretium/features/swap/services/rates_service.dart';
import 'package:pretium/repositories/wallet_repository.dart';
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
    });
  }

  void _nextStep() {
    if (_step == _SwapStep.input) {
      setState(() => _step = _SwapStep.confirmation);
    } else if (_step == _SwapStep.confirmation) {
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
      _toCurrency = _fromCurrency == 'USD' ? 'USDT' : 'USD';
    }
    
    _rate = _rates.getRate(_fromCurrency, _toCurrency);
    _loadBalances();

    // Listen to live rate updates
    _rates.ratesStream.listen((map) {
      if (mounted) {
        setState(() {
          _rate = _rates.getRate(_fromCurrency, _toCurrency);
        });
      }
    });
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

      // Load both wallets
      final fiatWallet = await _walletRepository.getWalletBalance(user.uid);
      final cryptoWallet = await _walletRepository.getCryptoWalletBalance(user.uid, 'USDT');

      if (!mounted) return;

      // Set balances based on current currencies
      if (_fromCurrency == 'USD') {
        _fromBalance = fiatWallet?.balance ?? 0.0;
        _toBalance = cryptoWallet?.balance ?? 0.0;
      } else {
        _fromBalance = cryptoWallet?.balance ?? 0.0;
        _toBalance = fiatWallet?.balance ?? 0.0;
      }

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
        final theme = Theme.of(context);
        final primaryColor = theme.colorScheme.primary;
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Center(child: Text('Swap Successful')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: primaryColor, size: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'Check history for all transactions.',
                    textAlign: TextAlign.center,
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
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text('Done', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Swap'),
        leading: _step == _SwapStep.confirmation
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _previousStep)
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

class _SwapInputScreen extends StatelessWidget {
  final VoidCallback onNext;
  final TextEditingController fromCtrl;
  final String fromCurrency;
  final String toCurrency;
  final double fromBalance;
  final double toBalance;
  final double rate;
  final bool loadingBalances;
  final VoidCallback onSwapCurrencies;

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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _SwapCurrencyCard(
          label: 'You Send',
          currency: fromCurrency,
          balance: fromBalance,
          loading: loadingBalances,
          controller: fromCtrl,
          onCurrencyTap: () { /* TODO: Show currency picker */ },
        ),
        const SizedBox(height: 8),
        Center(
          child: IconButton(
            icon: Icon(Icons.swap_vert, color: primaryColor, size: 32),
            onPressed: onSwapCurrencies,
            style: IconButton.styleFrom(
              backgroundColor: primaryColor.withOpacity(0.1),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _SwapCurrencyCard(
          label: 'You Receive',
          currency: toCurrency,
          balance: toBalance,
          loading: loadingBalances,
          // Calculate received amount based on rate
          amount: (double.tryParse(fromCtrl.text) ?? 0) * rate,
          onCurrencyTap: () { /* TODO: Show currency picker */ },
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onNext,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text(
            'Confirm and Swap',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
                      // TODO: Add currency icon
                      const Icon(Icons.currency_bitcoin, size: 20),
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
                  amount?.toStringAsFixed(5) ?? '0.00',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _TransactionDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
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
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text('Swap Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _DetailItem(label: 'From', amount: fromAmount, currency: fromCurrency),
                const Divider(height: 32),
                _DetailItem(label: 'To', amount: toAmount, currency: toCurrency, isReceiving: true),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Confirm Swap', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        const Spacer(),
        Text(
          '${isReceiving ? '' : '-'}${amount.toStringAsFixed(5)}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        // TODO: Add currency icon
        const Icon(Icons.currency_bitcoin, size: 20),
        const SizedBox(width: 4),
        Text(currency, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
