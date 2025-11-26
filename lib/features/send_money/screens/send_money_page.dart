import 'package:flutter/material.dart';
import 'package:pretium/features/send_money/screens/send_amount_screen.dart';
import 'package:pretium/features/send_money/screens/payment_method_screen.dart';
import 'package:pretium/features/send_money/screens/review_details_screen.dart';
import 'package:pretium/features/send_money/screens/recipient_details_screen.dart';
import 'package:pretium/models/transaction_details_model.dart';

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

  void _nextStep() {
    setState(() {
      if (_step == SendMoneyStep.amount) {
        _step = SendMoneyStep.payment;
      } else if (_step == SendMoneyStep.recipientDetails) {
        _step = SendMoneyStep.review;
      } else if (_step == SendMoneyStep.review) {
        // TODO: Finalize transaction
        Navigator.of(context).pop();
      }
    });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Money'),
        leading: _step != SendMoneyStep.amount
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _previousStep)
            : null,
      ),
      body: _buildCurrentStep(),
    );
  }
}
