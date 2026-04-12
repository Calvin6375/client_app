import 'package:flutter/material.dart';
import 'package:pretium/features/send_money/screens/send_amount_screen.dart';
import 'package:pretium/features/send_money/screens/payment_method_screen.dart';
import 'package:pretium/features/send_money/screens/review_details_screen.dart';
import 'package:pretium/features/send_money/screens/recipient_details_screen.dart';
import 'package:pretium/models/transaction_details_model.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/services/payment_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Maps UI payment method to [createDirectPayout] `payoutMethod` (server expects `bank` | `mobile_money`).
String? _sendMoneyPayoutMethodApi(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.mobileMoney:
      return 'mobile_money';
    case PaymentMethod.bank:
      return 'bank';
    case PaymentMethod.truePay:
      return null;
  }
}

String _sendMoneyPayoutNote(TransactionDetails d) {
  final name = d.recipientFullName.trim();
  final network = d.recipientMobileNetwork.trim();
  final parts = <String>[
    if (name.isNotEmpty) 'To: $name',
    '${d.amountToSend.toStringAsFixed(2)} ${d.fromCurrency} → ${d.amountToReceive.toStringAsFixed(2)} ${d.toCurrency}',
    'Method: ${d.paymentMethod.name}',
    if (network.isNotEmpty) 'Mobile network: $network',
  ];
  return parts.join(' · ');
}

Map<String, dynamic> _sendMoneyPayoutMetadata(TransactionDetails d) {
  final meta = <String, dynamic>{
    'flow': 'send_money',
    'recipientFullName': d.recipientFullName.trim(),
    'recipientPhoneNumber': d.recipientPhoneNumber.trim(),
    'fromCurrency': d.fromCurrency,
    'toCurrency': d.toCurrency,
    'amountToSend': d.amountToSend,
    'amountToReceive': d.amountToReceive,
    'paymentMethod': d.paymentMethod.name,
  };
  final network = d.recipientMobileNetwork.trim();
  if (network.isNotEmpty) {
    meta['mobileNetwork'] = network;
  }
  final bank = d.recipientBankName?.trim();
  if (bank != null && bank.isNotEmpty) {
    meta['recipientBankName'] = bank;
  }
  final acct = d.recipientAccountNumber?.trim();
  if (acct != null && acct.isNotEmpty) {
    meta['recipientAccountNumber'] = acct;
  }
  return meta;
}

enum SendMoneyStep { amount, payment, recipientDetails, review }

class SendMoneyPage extends StatefulWidget {
  final String? initialFromCurrency;
  
  const SendMoneyPage({super.key, this.initialFromCurrency});

  @override
  State<SendMoneyPage> createState() => _SendMoneyPageState();
}

class _SendMoneyPageState extends State<SendMoneyPage> {
  SendMoneyStep _step = SendMoneyStep.amount;
  late final TransactionDetails _transactionDetails;
  bool _isSubmittingSendMoney = false;
  
  @override
  void initState() {
    super.initState();
    // Initialize with currency from parameter or defaults
    _transactionDetails = TransactionDetails(
      fromCurrency: widget.initialFromCurrency ?? 'USD',
      toCurrency: widget.initialFromCurrency == 'USD' ? 'USDT' : 'USD',
    );
  }

  void _onPaymentMethodSelected(PaymentMethod method) {
    setState(() {
      _transactionDetails.paymentMethod = method;
      _step = SendMoneyStep.recipientDetails;
    });
  }

  void _updateTransactionDetails(TransactionDetails details) {
    setState(() {
      _transactionDetails.amountToSend = details.amountToSend;
      _transactionDetails.fromCurrency = details.fromCurrency;
      _transactionDetails.amountToReceive = details.amountToReceive;
      _transactionDetails.toCurrency = details.toCurrency;
      _transactionDetails.recipientFullName = details.recipientFullName;
      _transactionDetails.recipientPhoneNumber = details.recipientPhoneNumber;
      _transactionDetails.recipientBankName = details.recipientBankName;
      _transactionDetails.recipientAccountNumber = details.recipientAccountNumber;
      _transactionDetails.recipientMobileNetwork = details.recipientMobileNetwork;
    });
  }

  void _nextStep() async {
    if (_step == SendMoneyStep.amount) {
      setState(() => _step = SendMoneyStep.payment);
    } else if (_step == SendMoneyStep.recipientDetails) {
      setState(() => _step = SendMoneyStep.review);
    } else if (_step == SendMoneyStep.review) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to send money')),
        );
        return;
      }
      final amount = _transactionDetails.amountToSend;
      if (amount <= 0) return;
      final phone = _transactionDetails.recipientPhoneNumber.trim();
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipient phone number is required')),
        );
        return;
      }

      setState(() => _isSubmittingSendMoney = true);
      try {
        final paymentService = PaymentService();
        final phoneE164 = phone.startsWith('+') ? phone : '+$phone';
        final result = await paymentService.createDirectPayout(
          amount: amount,
          currency: _transactionDetails.fromCurrency,
          phoneNumber: phoneE164,
          note: _sendMoneyPayoutNote(_transactionDetails),
          payoutMethod: _sendMoneyPayoutMethodApi(_transactionDetails.paymentMethod),
          metadata: _sendMoneyPayoutMetadata(_transactionDetails),
        );
        if (!mounted) return;
        setState(() => _isSubmittingSendMoney = false);
        if (result['success'] != true) {
          final code = result['code']?.toString();
          final raw = result['error']?.toString() ?? 'Payout failed';
          final message = switch (code) {
            'unauthenticated' => 'Please sign in to send money.',
            'invalid-argument' => raw,
            'not-found' => 'Recipient not found. Please check the phone number.',
            'failed-precondition' =>
              'Insufficient balance. You don\'t have enough funds to send this amount.',
            'internal' => 'Something went wrong. Please try again.',
            _ => raw,
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
          );
          return;
        }
        final cur = result['currency']?.toString() ?? _transactionDetails.fromCurrency;
        final amt = result['amount'];
        final amtStr = amt is num ? amt.toString() : amount.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payout submitted: $amtStr $cur'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.of(context).pop();
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSubmittingSendMoney = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Send money failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _previousStep() {
    setState(() {
      if (_step == SendMoneyStep.payment) {
        _step = SendMoneyStep.amount;
      } else if (_step == SendMoneyStep.recipientDetails) {
        _step = SendMoneyStep.payment;
      } else if (_step == SendMoneyStep.review) {
        _step = SendMoneyStep.recipientDetails;
      }
    });
  }

  void _goToStep(SendMoneyStep step) {
    setState(() => _step = step);
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case SendMoneyStep.amount:
        return SendAmountScreen(
          onNext: _nextStep,
          onUpdate: (details) => _updateTransactionDetails(details),
          initialDetails: _transactionDetails,
        );
      case SendMoneyStep.payment:
        return PaymentMethodScreen(onNext: _onPaymentMethodSelected);
      case SendMoneyStep.recipientDetails:
        return RecipientDetailsScreen(
          paymentMethod: _transactionDetails.paymentMethod,
          onNext: _nextStep,
          onUpdate: (details) => _updateTransactionDetails(details),
          initialDetails: _transactionDetails,
        );
      case SendMoneyStep.review:
        return ReviewDetailsScreen(
          onNext: _nextStep,
          details: _transactionDetails,
          onEditTransferDetails: () => _goToStep(SendMoneyStep.amount),
          onEditRecipientDetails: () => _goToStep(SendMoneyStep.recipientDetails),
          isSubmitting: _isSubmittingSendMoney,
        );
    }
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
            : primary.withOpacity(0.08), // Light mint tint (8% opacity) for light mode
        elevation: 0,
        title: Text('Send Money', style: TextStyle(color: colors.textPrimary)),
        iconTheme: IconThemeData(color: colors.textPrimary),
        leading: _step != SendMoneyStep.amount
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                onPressed: _previousStep,
              )
            : null,
      ),
      body: _buildCurrentStep(),
    );
  }
}
