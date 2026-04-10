import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:pretium/features/send_money/screens/send_amount_screen.dart';
import 'package:pretium/features/send_money/screens/payment_method_screen.dart';
import 'package:pretium/features/send_money/screens/review_details_screen.dart';
import 'package:pretium/features/send_money/screens/recipient_details_screen.dart';
import 'package:pretium/features/send_money/services/send_money_order_service.dart';
import 'package:pretium/models/transaction_details_model.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        final result = await createSendMoneyOrder(
          recipientPhoneNumber: phone.startsWith('+') ? phone : '+$phone',
          amount: amount,
          currency: _transactionDetails.fromCurrency,
          note: null,
        );
        if (!mounted) return;
        setState(() => _isSubmittingSendMoney = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent ${result.amount} ${result.currency} successfully'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.of(context).pop();
      } on FirebaseFunctionsException catch (e) {
        if (!mounted) return;
        setState(() => _isSubmittingSendMoney = false);
        final message = switch (e.code) {
          'unauthenticated' => 'Please sign in to send money.',
          'invalid-argument' => 'Invalid request. You cannot send to yourself.',
          'not-found' => 'Recipient not found. Please check the phone number.',
          'failed-precondition' => 'Insufficient balance. You don\'t have enough funds to send this amount.',
          'internal' => 'Something went wrong. Please try again.',
          _ => 'Send money failed. Please try again.',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
        );
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
