import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/features/safari_tap/models/safari_tap_payout_quote.dart';
import 'package:pretium/features/safari_tap/services/safari_tap_pay_api_service.dart';
import 'package:pretium/features/safari_tap/utils/payout_error_messages.dart';
import 'package:pretium/features/safari_tap/utils/safari_tap_phone.dart';
import 'package:pretium/features/send_money/screens/payment_method_screen.dart';
import 'package:pretium/models/transaction_details_model.dart';

enum SendMoneyStep { form, review }

class SendMoneyFlowState {
  const SendMoneyFlowState({
    required this.step,
    required this.details,
    this.isSubmitting = false,
    this.isValidating = false,
    this.quote,
    this.isLoadingQuote = false,
    this.quoteError,
  });

  final SendMoneyStep step;
  final TransactionDetails details;
  final bool isSubmitting;
  final bool isValidating;
  final SafariTapPayoutQuote? quote;
  final bool isLoadingQuote;
  final String? quoteError;

  SendMoneyFlowState copyWith({
    SendMoneyStep? step,
    TransactionDetails? details,
    bool? isSubmitting,
    bool? isValidating,
    SafariTapPayoutQuote? quote,
    bool clearQuote = false,
    bool? isLoadingQuote,
    String? quoteError,
    bool clearQuoteError = false,
  }) {
    return SendMoneyFlowState(
      step: step ?? this.step,
      details: details ?? this.details,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isValidating: isValidating ?? this.isValidating,
      quote: clearQuote ? null : (quote ?? this.quote),
      isLoadingQuote: isLoadingQuote ?? this.isLoadingQuote,
      quoteError: clearQuoteError ? null : (quoteError ?? this.quoteError),
    );
  }
}

class SendMoneyFlowNotifier extends AutoDisposeNotifier<SendMoneyFlowState> {
  int _quoteRequestId = 0;

  @override
  SendMoneyFlowState build() {
    return SendMoneyFlowState(
      step: SendMoneyStep.form,
      details: TransactionDetails(fromCurrency: 'KES', toCurrency: 'KES'),
    );
  }

  void updateDetails(TransactionDetails details) {
    final current = state.details;
    current.amountToSend = details.amountToSend;
    current.fromCurrency = details.fromCurrency;
    current.amountToReceive = details.amountToReceive;
    current.toCurrency = details.toCurrency;
    current.paymentMethod = details.paymentMethod;
    current.recipientFullName = details.recipientFullName;
    current.recipientPhoneNumber = details.recipientPhoneNumber;
    current.recipientBankName = details.recipientBankName;
    current.recipientAccountNumber = details.recipientAccountNumber;
    current.recipientBankCode = details.recipientBankCode;
    current.recipientUserId = details.recipientUserId;
    current.recipientMobileNetwork = details.recipientMobileNetwork;
    current.verifiedBeneficiaryName = details.verifiedBeneficiaryName;
    state = state.copyWith(details: current);
  }

  void goToForm() {
    _quoteRequestId++;
    state = state.copyWith(
      step: SendMoneyStep.form,
      isLoadingQuote: false,
      clearQuoteError: true,
    );
  }

  Map<String, dynamic> safariTapWalletRecipient({String? name}) {
    final userId = state.details.recipientUserId?.trim() ?? '';
    if (userId.isNotEmpty) {
      return {
        'userId': userId,
        if (name != null && name.isNotEmpty) 'name': name,
      };
    }
    final phone = normalizeKenyaPhone(state.details.recipientPhoneNumber);
    return {
      'phoneNumber': phone,
      if (name != null && name.isNotEmpty) 'name': name,
    };
  }

  Map<String, dynamic> buildValidateBody() {
    final name = state.details.recipientFullName.trim();
    switch (state.details.paymentMethod) {
      case PaymentMethod.mobileMoney:
        return {
          'type': 'MPESA_B2C',
          'recipient': {
            'phoneNumber':
                normalizeKenyaPhone(state.details.recipientPhoneNumber),
            'name': name,
          },
        };
      case PaymentMethod.bank:
        return {
          'type': 'BANK',
          'recipient': {
            'bankCode': state.details.recipientBankCode,
            'accountNumber': state.details.recipientAccountNumber?.trim(),
            'accountName': name,
          },
        };
      case PaymentMethod.truePay:
        return {
          'type': 'SAFARITAP_WALLET',
          'recipient': safariTapWalletRecipient(name: name),
        };
      case null:
        throw StateError('Payment method is required before validation');
    }
  }

  Map<String, dynamic> buildPayoutBody(String clientRequestId) {
    final amount = state.details.amountToSend;
    final name = state.details.recipientFullName.trim();
    final verifiedName = state.details.verifiedBeneficiaryName.trim();
    final displayName = verifiedName.isNotEmpty ? verifiedName : name;
    final phone = normalizeKenyaPhone(state.details.recipientPhoneNumber);

    switch (state.details.paymentMethod) {
      case PaymentMethod.mobileMoney:
        return {
          'type': 'MPESA_B2C',
          'amount': amount,
          'currency': state.details.fromCurrency.toUpperCase(),
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
          'currency': state.details.fromCurrency.toUpperCase(),
          'clientRequestId': clientRequestId,
          'recipient': {
            'bankCode': state.details.recipientBankCode,
            'accountNumber': state.details.recipientAccountNumber?.trim(),
            'accountName': displayName,
          },
          'narrative': 'SafariTap bank transfer',
        };
      case PaymentMethod.truePay:
        return {
          'type': 'SAFARITAP_WALLET',
          'amount': amount,
          'currency': state.details.fromCurrency.toUpperCase(),
          'clientRequestId': clientRequestId,
          'recipient': safariTapWalletRecipient(name: displayName),
          'narrative': 'SafariTap wallet transfer',
        };
      case null:
        throw StateError('Payment method is required before payout');
    }
  }

  Map<String, dynamic> buildQuoteBody() {
    final amount = state.details.amountToSend;
    final phone = normalizeKenyaPhone(state.details.recipientPhoneNumber);

    switch (state.details.paymentMethod) {
      case PaymentMethod.mobileMoney:
        return {
          'type': 'MPESA_B2C',
          'amount': amount,
          'currency': state.details.fromCurrency.toUpperCase(),
          'recipient': {'phoneNumber': phone},
        };
      case PaymentMethod.bank:
        return {
          'type': 'BANK',
          'amount': amount,
          'currency': state.details.fromCurrency.toUpperCase(),
          'recipient': {
            'bankCode': state.details.recipientBankCode,
            'accountNumber': state.details.recipientAccountNumber?.trim(),
          },
        };
      case PaymentMethod.truePay:
        return {
          'type': 'SAFARITAP_WALLET',
          'amount': amount,
          'currency': state.details.fromCurrency.toUpperCase(),
          'recipient': safariTapWalletRecipient(),
        };
      case null:
        throw StateError('Payment method is required before quote');
    }
  }

  Future<String?> validateBeneficiary() async {
    try {
      final result = await ref
          .read(safariTapPayApiProvider)
          .validateBeneficiary(buildValidateBody());
      if (!result.valid) {
        return 'Could not verify recipient. Check the details.';
      }
      final resolvedName = result.beneficiaryName.trim();
      final details = state.details;
      if (resolvedName.isNotEmpty) {
        details.verifiedBeneficiaryName = resolvedName;
        if (details.recipientFullName.trim().isEmpty) {
          details.recipientFullName = resolvedName;
        }
      } else {
        details.verifiedBeneficiaryName = details.recipientFullName.trim();
      }
      state = state.copyWith(details: details);
      return null;
    } on SafariTapPayApiException catch (e) {
      return safariTapPayoutErrorMessage(e);
    }
  }

  Future<void> loadPayoutQuote() async {
    final requestId = ++_quoteRequestId;
    final amount = state.details.amountToSend;
    final currency = state.details.fromCurrency.toUpperCase();
    state = state.copyWith(isLoadingQuote: true, clearQuoteError: true);

    try {
      final quote =
          await ref.read(safariTapPayApiProvider).quotePayout(buildQuoteBody());
      if (requestId != _quoteRequestId) return;
      state = state.copyWith(
        quote: quote,
        isLoadingQuote: false,
        clearQuoteError: true,
      );
    } catch (e) {
      if (requestId != _quoteRequestId) return;
      final message = e is SafariTapPayApiException
          ? safariTapPayoutErrorMessage(e)
          : 'Unable to load transfer quote. Please try again.';
      state = state.copyWith(
        isLoadingQuote: false,
        quoteError: message,
        quote: SafariTapPayoutQuote.fallback(
          amount: amount,
          currency: currency,
        ),
      );
    }
  }

  Future<String?> continueFromForm() async {
    if (state.isValidating) return null;
    state = state.copyWith(isValidating: true);
    try {
      final error = await validateBeneficiary();
      if (error != null) return error;
      state = state.copyWith(
        step: SendMoneyStep.review,
        clearQuote: true,
        clearQuoteError: true,
        isLoadingQuote: true,
      );
      await loadPayoutQuote();
      return null;
    } finally {
      state = state.copyWith(isValidating: false);
    }
  }

  void setSubmitting(bool value) {
    state = state.copyWith(isSubmitting: value);
  }
}

final sendMoneyFlowProvider =
    AutoDisposeNotifierProvider<SendMoneyFlowNotifier, SendMoneyFlowState>(
  SendMoneyFlowNotifier.new,
);
