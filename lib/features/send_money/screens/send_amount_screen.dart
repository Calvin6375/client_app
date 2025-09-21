import 'package:flutter/material.dart';
import 'package:pretium/models/transaction_details_model.dart';

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
  final double _balance = 250000.0; // This would come from a service
  final double _rate = 740.0; // This would come from a service

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController(text: widget.initialDetails.amountToSend.toString());
    _fromCurrency = widget.initialDetails.fromCurrency;
    _toCurrency = widget.initialDetails.toCurrency;

    _fromCtrl.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    final amount = double.tryParse(_fromCtrl.text) ?? 0;
    widget.onUpdate(
      TransactionDetails(
        amountToSend: amount,
        fromCurrency: _fromCurrency,
        amountToReceive: amount / _rate,
        toCurrency: _toCurrency,
      ),
    );
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
    });
    _onAmountChanged();
  }

  @override
  void dispose() {
    _fromCtrl.removeListener(_onAmountChanged);
    _fromCtrl.dispose();
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
                  balance: _balance,
                  controller: _fromCtrl,
                  onCurrencyTap: () { /* TODO: Show currency picker */ },
                ),
                const SizedBox(height: 8),
                Center(
                  child: IconButton(
                    icon: Icon(Icons.swap_vert, color: primaryColor, size: 32),
                    onPressed: _swapCurrencies,
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
                  currency: _toCurrency,
                  balance: 4.42,
                  amount: (double.tryParse(_fromCtrl.text) ?? 0) / _rate,
                  onCurrencyTap: () { /* TODO: Show currency picker */ },
                ),
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
                      _TransactionDetailRow(
                        label: 'Exchange Rate',
                        value: '1 $_toCurrency = $_rate $_fromCurrency',
                      ),
                      const _TransactionDetailRow(label: 'Network Fee', value: 'Free'),
                      const _TransactionDetailRow(label: 'Service Fee', value: 'Free'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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

class _SwapCurrencyCard extends StatelessWidget {
  final String label;
  final String currency;
  final double balance;
  final TextEditingController? controller;
  final double? amount;
  final VoidCallback onCurrencyTap;

  const _SwapCurrencyCard({
    required this.label,
    required this.currency,
    required this.balance,
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
              Text('Balance: $balance', style: const TextStyle(color: Colors.grey)),
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
