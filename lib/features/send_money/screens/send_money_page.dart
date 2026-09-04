import 'package:flutter/material.dart';
import 'package:pretium/features/send_money/screens/send_money_form_screen.dart';
import 'package:pretium/features/send_money/screens/payment_method_screen.dart';
import 'package:pretium/features/send_money/screens/review_details_screen.dart';
import 'package:pretium/models/transaction_details_model.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/safari_tap/models/safari_tap_payout_quote.dart';
import 'package:pretium/features/safari_tap/services/safari_tap_pay_api_service.dart';
import 'package:pretium/features/safari_tap/services/safari_tap_pay_flow.dart';
import 'package:pretium/features/safari_tap/utils/payout_error_messages.dart';
import 'package:pretium/features/safari_tap/utils/safari_tap_phone.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

enum SendMoneyStep { form, review }

class SendMoneyPage extends StatefulWidget {
  final String? initialFromCurrency;

  const SendMoneyPage({super.key, this.initialFromCurrency});

  @override
  State<SendMoneyPage> createState() => _SendMoneyPageState();
}

class _SendMoneyPageState extends State<SendMoneyPage> {
  SendMoneyStep _step = SendMoneyStep.form;
  late final TransactionDetails _transactionDetails;
  bool _isSubmittingSendMoney = false;
  bool _isValidating = false;
  final SafariTapPayApiService _payApi = SafariTapPayApiService();

  SafariTapPayoutQuote? _quote;
  bool _isLoadingQuote = false;
  String? _quoteError;
  int _quoteRequestId = 0;

  @override
  void initState() {
    super.initState();
    _transactionDetails = TransactionDetails(
      fromCurrency: 'KES',
      toCurrency: 'KES',
    );
  }

  void _updateTransactionDetails(TransactionDetails details) {
    setState(() {
      _transactionDetails.amountToSend = details.amountToSend;
      _transactionDetails.fromCurrency = details.fromCurrency;
      _transactionDetails.amountToReceive = details.amountToReceive;
      _transactionDetails.toCurrency = details.toCurrency;
      _transactionDetails.paymentMethod = details.paymentMethod;
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
        return {
          'type': 'SAFARITAP_WALLET',
          'recipient': {
            'phoneNumber': normalizeKenyaPhone(
              _transactionDetails.recipientPhoneNumber,
            ),
            'name': name,
          },
        };
      case null:
        throw StateError('Payment method is required before validation');
    }
  }

  Map<String, dynamic> _buildPayoutBody(String clientRequestId) {
    final amount = _transactionDetails.amountToSend;
    final name = _transactionDetails.recipientFullName.trim();
    final verifiedName = _transactionDetails.verifiedBeneficiaryName.trim();
    final displayName = verifiedName.isNotEmpty ? verifiedName : name;
    final phone = normalizeKenyaPhone(_transactionDetails.recipientPhoneNumber);

    switch (_transactionDetails.paymentMethod) {
      case PaymentMethod.mobileMoney:
        return {
          'type': 'MPESA_B2C',
          'amount': amount,
          'currency': _transactionDetails.fromCurrency.toUpperCase(),
          'clientRequestId': clientRequestId,
          'recipient': {
            'phoneNumber': phone,
            'name': displayName,
          },
          'narrative': 'SafariTap transfer',
        };
      case PaymentMethod.bank:
        return {
          'type': 'BANK',
          'amount': amount,
          'currency': _transactionDetails.fromCurrency.toUpperCase(),
          'clientRequestId': clientRequestId,
          'recipient': {
            'bankCode': _transactionDetails.recipientBankCode,
            'accountNumber': _transactionDetails.recipientAccountNumber?.trim(),
            'accountName': displayName,
          },
          'narrative': 'SafariTap bank transfer',
        };
      case PaymentMethod.truePay:
        return {
          'type': 'SAFARITAP_WALLET',
          'amount': amount,
          'currency': 'KES',
          'clientRequestId': clientRequestId,
          'recipient': {
            'phoneNumber': phone,
            'name': displayName,
          },
          'narrative': 'SafariTap wallet transfer',
        };
      case null:
        throw StateError('Payment method is required before payout');
    }
  }

  /// Quote body uses the same type/amount/currency/recipient as create payout.
  Map<String, dynamic> _buildQuoteBody() {
    final amount = _transactionDetails.amountToSend;
    final phone = normalizeKenyaPhone(_transactionDetails.recipientPhoneNumber);

    switch (_transactionDetails.paymentMethod) {
      case PaymentMethod.mobileMoney:
        return {
          'type': 'MPESA_B2C',
          'amount': amount,
          'currency': _transactionDetails.fromCurrency.toUpperCase(),
          'recipient': {
            'phoneNumber': phone,
          },
        };
      case PaymentMethod.bank:
        return {
          'type': 'BANK',
          'amount': amount,
          'currency': _transactionDetails.fromCurrency.toUpperCase(),
          'recipient': {
            'bankCode': _transactionDetails.recipientBankCode,
            'accountNumber': _transactionDetails.recipientAccountNumber?.trim(),
          },
        };
      case PaymentMethod.truePay:
        return {
          'type': 'SAFARITAP_WALLET',
          'amount': amount,
          'currency': 'KES',
          'recipient': {
            'phoneNumber': phone,
          },
        };
      case null:
        throw StateError('Payment method is required before quote');
    }
  }

  Future<void> _loadPayoutQuote() async {
    final requestId = ++_quoteRequestId;
    final amount = _transactionDetails.amountToSend;
    final currency = _transactionDetails.fromCurrency.toUpperCase();

    setState(() {
      _isLoadingQuote = true;
      _quoteError = null;
    });

    try {
      final quote = await _payApi.quotePayout(_buildQuoteBody());
      if (!mounted || requestId != _quoteRequestId) return;
      setState(() {
        _quote = quote;
        _isLoadingQuote = false;
        _quoteError = null;
      });
    } catch (e) {
      if (!mounted || requestId != _quoteRequestId) return;
      final message = e is SafariTapPayApiException
          ? safariTapPayoutErrorMessage(e)
          : 'Unable to load transfer quote. Please try again.';
      setState(() {
        _isLoadingQuote = false;
        _quoteError = message;
        _quote = SafariTapPayoutQuote.fallback(
          amount: amount,
          currency: currency,
        );
      });
    }
  }

  Future<bool> _validateBeneficiary() async {
    try {
      final result = await _payApi.validateBeneficiary(_buildValidateBody());
      if (!result.valid) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not verify recipient. Check the details.'),
          ),
        );
        return false;
      }
      // Wallet validate may return a name; MM/Bank IntaSend usually does.
      final resolvedName = result.beneficiaryName.trim();
      setState(() {
        if (resolvedName.isNotEmpty) {
          _transactionDetails.verifiedBeneficiaryName = resolvedName;
          if (_transactionDetails.recipientFullName.trim().isEmpty) {
            _transactionDetails.recipientFullName = resolvedName;
          }
        } else {
          _transactionDetails.verifiedBeneficiaryName =
              _transactionDetails.recipientFullName.trim();
        }
      });
      return true;
    } on SafariTapPayApiException catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(safariTapPayoutErrorMessage(e)),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return false;
    }
  }

  Future<void> _onFormContinue() async {
    if (_isValidating) return;
    setState(() => _isValidating = true);
    try {
      final ok = await _validateBeneficiary();
      if (ok && mounted) {
        setState(() {
          _step = SendMoneyStep.review;
          _quote = null;
          _quoteError = null;
          _isLoadingQuote = true;
        });
        await _loadPayoutQuote();
      }
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  Future<void> _onReviewConfirm() async {
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

        if (_transactionDetails.paymentMethod == PaymentMethod.truePay &&
            _transactionDetails.fromCurrency.toUpperCase() != 'KES') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SafariTap wallet transfers require a KES wallet.'),
            ),
          );
          return;
        }

        if (_transactionDetails.paymentMethod == PaymentMethod.bank &&
            (amount < 100 || amount > 999999)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bank transfers must be between KES 100 and 999,999',
              ),
            ),
          );
          return;
        }

        final clientRequestId = const Uuid().v4();
        final isWallet =
            _transactionDetails.paymentMethod == PaymentMethod.truePay;
        final ok = await runSafariTapPayoutFlow(
          context: context,
          payoutBody: _buildPayoutBody(clientRequestId),
          flowLabel: isWallet ? 'SafariTap wallet' : 'Send money',
          clientRequestId: clientRequestId,
          api: _payApi,
        );
        if (ok && mounted) Navigator.of(context).pop();
      },
    );
  }

  void _previousStep() {
    if (_step == SendMoneyStep.review) {
      _quoteRequestId++;
      setState(() {
        _step = SendMoneyStep.form;
        _isLoadingQuote = false;
        _quoteError = null;
      });
    }
  }

  void _editFromReview() {
    _quoteRequestId++;
    setState(() {
      _step = SendMoneyStep.form;
      _isLoadingQuote = false;
      _quoteError = null;
    });
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case SendMoneyStep.form:
        return SendMoneyFormScreen(
          onContinue: _onFormContinue,
          onUpdate: _updateTransactionDetails,
          initialDetails: _transactionDetails,
          isValidating: _isValidating,
        );
      case SendMoneyStep.review:
        return ReviewDetailsScreen(
          onNext: _onReviewConfirm,
          details: _transactionDetails,
          onEditTransferDetails: _editFromReview,
          onEditRecipientDetails: _editFromReview,
          isSubmitting: _isSubmittingSendMoney,
          quote: _quote,
          isLoadingQuote: _isLoadingQuote,
          quoteError: _quoteError,
          onRetryQuote: _isLoadingQuote ? null : _loadPayoutQuote,
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
        leading: _step == SendMoneyStep.review
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
