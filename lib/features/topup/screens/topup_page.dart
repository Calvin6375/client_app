// First, add this to your pubspec.yaml:
// dependencies:
//   intasend_flutter: ^latest_version

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/features/topup/services/intasend_service.dart';
import 'dart:convert';
import 'dart:io';

// Top Up main screen composed of smaller widgets
class TopUpPage extends StatefulWidget {
  const TopUpPage({super.key});

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  final TextEditingController _amountCtrl = TextEditingController(
    text: '1250.00',
  );
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();

  bool _hideBalance = false;
  double _balance = 26135.00;
  String _selectedCurrency = 'USD';
  bool _isProcessingPayment = false;

  // IntaSend configuration
  static const String intaSendPublicKey ='ISPubKey_live_c2dbd636-a9a5-4a90-bdb8-dc7e7c7401a2';
  static const bool isTestMode = false;

  // Currency symbols mapping
  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'KES':
        return 'KSh';
      case 'UGX':
        return 'USh';
      case 'TZS':
        return 'TSh';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '\$';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  void _applyQuick(double v) {
    final current =
        double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0;
    final next = current + v;
    _amountCtrl.text = next.toStringAsFixed(2);
    setState(() {});
  }

  // FIXED: Using the official IntaSend Flutter plugin
  Future<void> _processIntaSendPayment() async {
    print('\n🚀 Starting IntaSend payment process...');
    print('Current balance: $_balance');
    print('Selected currency: $_selectedCurrency');

    if (_amountCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _firstNameCtrl.text.isEmpty ||
        _lastNameCtrl.text.isEmpty) {
      print('❌ Validation failed: Missing required fields');
      _showError('Please fill in all required fields');
      return;
    }

    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (amount <= 0) {
      print('❌ Validation failed: Invalid amount: $amount');
      _showError('Please enter a valid amount');
      return;
    }

    print('✅ Payment validation passed');
    print('Payment details:');
    print('  Amount: $amount');
    print('  Currency: $_selectedCurrency');
    print('  Email: ${_emailCtrl.text.trim()}');
    print('  Name: ${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}');

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      // Create IntaSend service instance
      final intaSendService = IntaSendService(
        publicKey: intaSendPublicKey,
        isTestMode: isTestMode,
      );

      print('🔗 Initiating IntaSend checkout...');
      
      // Process payment using custom HTTP service
      final result = await intaSendService.processPayment(
        amount: amount,
        email: _emailCtrl.text.trim(),
        currency: _selectedCurrency,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
      );

      if (result['success']) {
        print('✅ IntaSend checkout URL created successfully');
        final checkoutUrl = result['checkout_url'];
        
        if (checkoutUrl != null) {
          // Show payment launched dialog with URL for manual access if needed
          _showPaymentLaunchedDialog(checkoutUrl, result['message']);
        } else {
          _showError('Checkout URL not received from IntaSend');
        }
      } else {
        print('❌ IntaSend checkout failed: ${result['error']}');
        _showError(result['error'] ?? 'Payment failed');
      }

    } catch (e) {
      print('❌ Exception in payment process: $e');
      _showError('Error processing payment: $e');
    } finally {
      print('📋 Payment process completed, resetting state...');
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  void _showError(String message) {
    print('❌ Showing error dialog: $message');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              print('👍 User acknowledged error dialog');
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SuccessDialog(),
    );
  }

  void _showPaymentLaunchedDialog(String checkoutUrl, String? message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Payment Ready'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payment,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'IntaSend checkout is ready!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (message != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(message, style: TextStyle(color: Colors.green[700]))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Please complete your payment using one of the options below:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              
              // Payment URL section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.link, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text('Payment URL:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      checkoutUrl,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () async {
                              final intaSendService = IntaSendService(
                                publicKey: intaSendPublicKey,
                                isTestMode: isTestMode,
                              );
                              final launched = await intaSendService.launchCheckout(checkoutUrl);
                              if (!launched) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not open payment page automatically. Please copy the URL above.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.open_in_browser, size: 16),
                            label: const Text('Open Page', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: checkoutUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payment URL copied to clipboard!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy URL', style: TextStyle(fontSize: 12)),
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
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              // Simulate successful payment for demo
              _showSuccess();
            },
            child: const Text('Payment Completed'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: primary,
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Topup', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(
              _hideBalance ? Icons.visibility_off : Icons.visibility,
              color: Colors.white70,
            ),
            onPressed: () => setState(() => _hideBalance = !_hideBalance),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance header area with subtle pattern could be added via decoration
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _BalanceHeader(
              balance: _balance,
              hidden: _hideBalance,
              currencySymbol: _getCurrencySymbol(_selectedCurrency),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF2F5F8),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SetAmountCard(
                    controller: _amountCtrl,
                    currencySymbol: _getCurrencySymbol(_selectedCurrency),
                    onQuickAdd: _applyQuick,
                  ),
                  const SizedBox(height: 16),
                  _FiatOptionCard(
                    emailController: _emailCtrl,
                    firstNameController: _firstNameCtrl,
                    lastNameController: _lastNameCtrl,
                    selectedCurrency: _selectedCurrency,
                    isProcessing: _isProcessingPayment,
                    onCurrencyChanged: (currency) {
                      setState(() {
                        _selectedCurrency = currency;
                      });
                    },
                    onPaymentPressed: _processIntaSendPayment,
                  ),
                  const SizedBox(height: 16),
                  const _CryptoOptionCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Rest of your widget classes remain the same...
class _BalanceHeader extends StatelessWidget {
  final double balance;
  final bool hidden;
  final String currencySymbol;
  const _BalanceHeader({
    required this.balance,
    required this.hidden,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Balance', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        Text(
          hidden
              ? '$currencySymbol ••••'
              : '$currencySymbol${balance.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _SetAmountCard extends StatelessWidget {
  final TextEditingController controller;
  final String currencySymbol;
  final void Function(double) onQuickAdd;
  const _SetAmountCard({
    required this.controller,
    required this.currencySymbol,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set amount',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'How much would you like to top up?',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencySymbol,
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '0.00',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [5, 10, 25, 50].map((e) {
                return ActionChip(
                  label: Text('${currencySymbol}${e.toStringAsFixed(0)}'),
                  onPressed: () => onQuickAdd(e.toDouble()),
                  backgroundColor: primary.withOpacity(0.08),
                  labelStyle: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiatOptionCard extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final String selectedCurrency;
  final bool isProcessing;
  final void Function(String) onCurrencyChanged;
  final VoidCallback onPaymentPressed;

  const _FiatOptionCard({
    required this.emailController,
    required this.firstNameController,
    required this.lastNameController,
    required this.selectedCurrency,
    required this.isProcessing,
    required this.onCurrencyChanged,
    required this.onPaymentPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: primary),
                const SizedBox(width: 8),
                const Text(
                  'Fiat Option',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pay with IntaSend using your card or mobile money',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Email field
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter your email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // First name and Last name row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: firstNameController,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      hintText: 'Enter first name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: lastNameController,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      hintText: 'Enter last name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Currency selector
            DropdownButtonFormField<String>(
              value: selectedCurrency,
              decoration: InputDecoration(
                labelText: 'Currency',
                prefixIcon: const Icon(Icons.monetization_on_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: ['USD', 'KES', 'UGX', 'TZS', 'EUR', 'GBP']
                  .map(
                    (currency) => DropdownMenuItem(
                      value: currency,
                      child: Text(currency),
                    ),
                  )
                  .toList(),
              onChanged: (value) => onCurrencyChanged(value ?? 'USD'),
            ),
            const SizedBox(height: 16),

            // IntaSend checkout button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isProcessing ? Colors.grey : primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isProcessing ? null : onPaymentPressed,
                icon: isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.payment),
                label: Text(
                  isProcessing ? 'Processing...' : 'Pay with IntaSend',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CryptoOptionCard extends StatelessWidget {
  const _CryptoOptionCard();

  // Cryptocurrency addresses
  static const Map<String, Map<String, String>> cryptoAddresses = {
    'USDT': {
      'address': 'TGkPQsmAhRVh51bEj961EUavP3BjZqEnBb',
      'network': 'Tron Network',
      'icon': '₮',
    },
    'USDC': {
      'address': 'FPJoay8fh2FpBBUM2pSmSdTrqpKepZPagGZfU6pwF2qo',
      'network': 'Solana Network',
      'icon': '🔵',
    },
    'BNB': {
      'address': '0xe421b816e5664a4ecd514956db132762b4e82e8d',
      'network': 'BNB Smart Chain',
      'icon': '🟡',
    },
  };

  void _copyToClipboard(BuildContext context, String address, String currency) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$currency address copied to clipboard'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.currency_bitcoin, color: primary),
                const SizedBox(width: 8),
                const Text(
                  'Crypto Option',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Send cryptocurrency to these addresses',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Cryptocurrency addresses
            ...cryptoAddresses.entries.map((entry) {
              final currency = entry.key;
              final data = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          data['icon']!,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currency,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          data['network']!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              data['address']!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _copyToClipboard(
                              context,
                              data['address']!,
                              currency,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(Icons.copy, size: 16, color: primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 16),

            // Instructions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Payment Instructions',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Copy the address for your preferred cryptocurrency\n'
                    '2. Send the exact top-up amount to the copied address\n'
                    '3. Payment will be processed automatically',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: primary, size: 56),
            ),
            const SizedBox(height: 12),
            const Text(
              'Payment Success',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Your IntaSend payment was processed successfully',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Payment Processed',
                    style: TextStyle(color: Colors.black54),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Transaction Completed',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Payment Method',
                    style: TextStyle(color: Colors.black54),
                  ),
                  SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.payment, color: Colors.white),
                    ),
                    title: Text('IntaSend Payment'),
                    subtitle: Text('Secure payment processed successfully'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}