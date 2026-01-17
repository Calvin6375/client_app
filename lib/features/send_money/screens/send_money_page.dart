import 'package:flutter/material.dart';
import 'package:pretium/features/send_money/screens/send_amount_screen.dart';
import 'package:pretium/features/send_money/screens/payment_method_screen.dart';
import 'package:pretium/features/send_money/screens/review_details_screen.dart';
import 'package:pretium/features/send_money/screens/recipient_details_screen.dart';
import 'package:pretium/models/transaction_details_model.dart';
import 'package:pretium/services/order_service.dart';
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
  final OrderService _orderService = OrderService();
  
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
    setState(() {
      if (_step == SendMoneyStep.amount) {
        _step = SendMoneyStep.payment;
      } else if (_step == SendMoneyStep.recipientDetails) {
        _step = SendMoneyStep.review;
      } else if (_step == SendMoneyStep.review) {
        // Create order when transaction is finalized
        _createSendMoneyOrder();
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _createSendMoneyOrder() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _transactionDetails.amountToSend > 0) {
        await _orderService.createOrder(
          userId: user.uid,
          amount: _transactionDetails.amountToSend,
          currency: _transactionDetails.fromCurrency,
          orderType: 'send_money',
          metadata: {
            'fromCurrency': _transactionDetails.fromCurrency,
            'toCurrency': _transactionDetails.toCurrency,
            'amountToReceive': _transactionDetails.amountToReceive,
            'recipientFullName': _transactionDetails.recipientFullName,
            'recipientPhoneNumber': _transactionDetails.recipientPhoneNumber,
            'paymentMethod': _transactionDetails.paymentMethod.toString(),
            if (_transactionDetails.recipientBankName != null)
              'recipientBankName': _transactionDetails.recipientBankName,
            if (_transactionDetails.recipientAccountNumber != null)
              'recipientAccountNumber': _transactionDetails.recipientAccountNumber,
          },
        );
        print('✅ Send money order created in Firestore');
      }
    } catch (e) {
      print('⚠️ Failed to create send money order: $e');
      // Don't block the transaction flow if order creation fails
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
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    
    return Scaffold(
      backgroundColor: colors.background, // Theme-aware background
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparent AppBar
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
