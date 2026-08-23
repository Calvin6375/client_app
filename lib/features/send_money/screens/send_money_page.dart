import 'package:flutter/material.dart';
import 'package:pretium/features/send_money/screens/send_amount_screen.dart';
import 'package:pretium/features/send_money/screens/payment_method_screen.dart';
import 'package:pretium/features/send_money/screens/review_details_screen.dart';
import 'package:pretium/features/send_money/screens/recipient_details_screen.dart';
import 'package:pretium/models/transaction_details_model.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/safari_card/services/safari_card_pay_api_service.dart';
import 'package:pretium/features/safari_card/services/safari_card_pay_flow.dart';
import 'package:pretium/features/safari_card/utils/payout_error_messages.dart';
import 'package:pretium/features/safari_card/utils/safari_card_phone.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

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
  final SafariCardPayApiService _payApi = SafariCardPayApiService();

  @override
  void initState() {
    super.initState();
    _transactionDetails = TransactionDetails(
      fromCurrency: 'KES',
      toCurrency: 'KES',
    );
  }

  void _onPaymentMethodSelected(PaymentMethod method) {
    setState(() {
      _transactionDetails.paymentMethod = method;
      _transactionDetails.verifiedBeneficiaryName = '';
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
      _transactionDetails.recipientBankCode = details.recipientBankCode;
      _transactionDetails.recipientMobileNetwork = details.recipientMobileNetwork;
      _transactionDetails.verifiedBeneficiaryName = details.verifiedBeneficiaryName;
    });
  }

  Map<String, dynamic> _buildValidateBody() {
    final name = _transactionDetails.recipientFullName.trim();
    switch (_transactionDetails.paymentMethod) {
      case PaymentMethod.mobileMoney:
        return {
          'type': 'MPESA_B2C',
          'recipient': {
            'phoneNumber': normalizeKenyaPhone(_transactionDetails.recipientPhoneNumber),
            'name': name,
          },
        };
      case PaymentMethod.bank:
        return {
          'type': 'BANK',
          'recipient': {
            'bankCode': _transactionDetails.recipientBankCode,
            'accountNumber': _transactionDetails.recipientAccountNumber?.trim(),
            'accountName': name,
          },
        };
      case PaymentMethod.truePay:
        throw StateError('SafariTap-to-SafariTap is not supported for Kenya payouts');
    }
  }

  Map<String, dynamic> _buildPayoutBody(String clientRequestId) {
    final amount = _transactionDetails.amountToSend;
    final name = _transactionDetails.recipientFullName.trim();
    final verifiedName = _transactionDetails.verifiedBeneficiaryName.trim();
    final displayName = verifiedName.isNotEmpty ? verifiedName : name;

    switch (_transactionDetails.paymentMethod) {
      case PaymentMethod.mobileMoney:
        return {
          'type': 'MPESA_B2C',
          'amount': amount,
          'currency': 'KES',
          'clientRequestId': clientRequestId,
          'recipient': {
            'phoneNumber': normalizeKenyaPhone(_transactionDetails.recipientPhoneNumber),
            'name': displayName,
          },
          'narrative': 'Safari Card transfer',
        };
      case PaymentMethod.bank:
        return {
          'type': 'BANK',
          'amount': amount,
          'currency': 'KES',
          'clientRequestId': clientRequestId,
          'recipient': {
            'bankCode': _transactionDetails.recipientBankCode,
            'accountNumber': _transactionDetails.recipientAccountNumber?.trim(),
            'accountName': displayName,
          },
          'narrative': 'Safari Card bank transfer',
        };
      case PaymentMethod.truePay:
        throw StateError('SafariTap-to-SafariTap is not supported for Kenya payouts');
    }
  }

  Future<bool> _validateBeneficiary() async {
    try {
      final result = await _payApi.validateBeneficiary(_buildValidateBody());
      if (!result.hasDisplayName) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not verify recipient. Check the details.')),
        );
        return false;
      }
      setState(() {
        _transactionDetails.verifiedBeneficiaryName = result.beneficiaryName;
        if (_transactionDetails.recipientFullName.trim().isEmpty) {
          _transactionDetails.recipientFullName = result.beneficiaryName;
        }
      });
      return true;
    } on SafariCardPayApiException catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(safariCardPayoutErrorMessage(e)),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return false;
    }
  }

  void _nextStep() async {
    if (_step == SendMoneyStep.amount) {
      setState(() => _step = SendMoneyStep.payment);
    } else if (_step == SendMoneyStep.recipientDetails) {
      final ok = await _validateBeneficiary();
      if (ok && mounted) setState(() => _step = SendMoneyStep.review);
    } else if (_step == SendMoneyStep.review) {
      await runGuardedAsync(
        this,
        isSubmitting: () => _isSubmittingSendMoney,
        setSubmitting: (value) => setState(() => _isSubmittingSendMoney = value),
        action: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please sign in to send money')),
            );
            return;
          }

          final amount = _transactionDetails.amountToSend;
          if (amount <= 0) return;

          if (_transactionDetails.paymentMethod == PaymentMethod.bank &&
              (amount < 100 || amount > 999999)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bank transfers must be between KES 100 and 999,999')),
            );
            return;
          }

          final clientRequestId = const Uuid().v4();
          final ok = await runSafariCardPayoutFlow(
            context: context,
            payoutBody: _buildPayoutBody(clientRequestId),
            flowLabel: 'Send money',
            clientRequestId: clientRequestId,
            api: _payApi,
          );
          if (ok && mounted) Navigator.of(context).pop();
        },
      );
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
          onUpdate: _updateTransactionDetails,
          initialDetails: _transactionDetails,
          kenyaOnly: true,
        );
      case SendMoneyStep.payment:
        return PaymentMethodScreen(onNext: _onPaymentMethodSelected, kenyaOnly: true);
      case SendMoneyStep.recipientDetails:
        return RecipientDetailsScreen(
          paymentMethod: _transactionDetails.paymentMethod,
          onNext: _nextStep,
          onUpdate: _updateTransactionDetails,
          initialDetails: _transactionDetails,
          kenyaOnly: true,
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
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.transparent : primary.withValues(alpha: 0.08),
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
