import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/features/safari_tap/models/safari_tap_payout_quote.dart';
import 'package:pretium/features/safari_tap/services/safari_tap_pay_api_service.dart';
import 'package:pretium/features/safari_tap/utils/payout_error_messages.dart';

enum KenyaPayKind { payBill, buyGoods, pochi, truePay }

enum KenyaPayStep { form, review }

class KenyaPayFlowState {
  const KenyaPayFlowState({
    this.step = KenyaPayStep.form,
    this.quote,
    this.isLoadingQuote = false,
    this.quoteError,
    this.beneficiaryName,
    this.validationLoading = false,
    this.validationError,
  });

  final KenyaPayStep step;
  final SafariTapPayoutQuote? quote;
  final bool isLoadingQuote;
  final String? quoteError;
  final String? beneficiaryName;
  final bool validationLoading;
  final String? validationError;

  bool get isValidated =>
      beneficiaryName != null && beneficiaryName!.trim().isNotEmpty;

  KenyaPayFlowState copyWith({
    KenyaPayStep? step,
    SafariTapPayoutQuote? quote,
    bool clearQuote = false,
    bool? isLoadingQuote,
    String? quoteError,
    bool clearQuoteError = false,
    String? beneficiaryName,
    bool clearBeneficiary = false,
    bool? validationLoading,
    String? validationError,
    bool clearValidationError = false,
  }) {
    return KenyaPayFlowState(
      step: step ?? this.step,
      quote: clearQuote ? null : (quote ?? this.quote),
      isLoadingQuote: isLoadingQuote ?? this.isLoadingQuote,
      quoteError: clearQuoteError ? null : (quoteError ?? this.quoteError),
      beneficiaryName:
          clearBeneficiary ? null : (beneficiaryName ?? this.beneficiaryName),
      validationLoading: validationLoading ?? this.validationLoading,
      validationError: clearValidationError
          ? null
          : (validationError ?? this.validationError),
    );
  }
}

class KenyaPayFlowNotifier
    extends AutoDisposeFamilyNotifier<KenyaPayFlowState, KenyaPayKind> {
  int _quoteRequestId = 0;

  @override
  KenyaPayFlowState build(KenyaPayKind arg) => const KenyaPayFlowState();

  void clearValidation() {
    state = state.copyWith(
      clearBeneficiary: true,
      clearValidationError: true,
    );
  }

  void goToForm() {
    _quoteRequestId++;
    state = state.copyWith(
      step: KenyaPayStep.form,
      isLoadingQuote: false,
      clearQuoteError: true,
    );
  }

  void goToReview() {
    state = state.copyWith(
      step: KenyaPayStep.review,
      clearQuote: true,
      clearQuoteError: true,
      isLoadingQuote: true,
    );
  }

  void applyValidation({
    String? beneficiaryName,
    bool clearBeneficiary = false,
    String? validationError,
    bool clearValidationError = false,
    bool? validationLoading,
  }) {
    state = state.copyWith(
      beneficiaryName: beneficiaryName,
      clearBeneficiary: clearBeneficiary,
      validationError: validationError,
      clearValidationError: clearValidationError,
      validationLoading: validationLoading,
    );
  }

  Future<bool> validateTruePay(Map<String, dynamic> body) async {
    state = state.copyWith(
      validationLoading: true,
      clearValidationError: true,
    );
    try {
      final result =
          await ref.read(safariTapPayApiProvider).validateBeneficiary(body);
      if (!result.valid) {
        state = state.copyWith(
          validationLoading: false,
          validationError: 'Could not verify this merchant',
        );
        return false;
      }
      final name = result.beneficiaryName.trim();
      state = state.copyWith(
        validationLoading: false,
        beneficiaryName: name.isNotEmpty ? name : state.beneficiaryName,
      );
      return true;
    } on SafariTapPayApiException catch (e) {
      state = state.copyWith(
        validationLoading: false,
        validationError: safariTapPayoutErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> validate(Map<String, dynamic> body) async {
    state = state.copyWith(
      validationLoading: true,
      clearValidationError: true,
      clearBeneficiary: true,
    );
    try {
      final result =
          await ref.read(safariTapPayApiProvider).validateBeneficiary(body);
      if (!result.hasDisplayName) {
        state = state.copyWith(
          validationLoading: false,
          validationError: 'Could not verify recipient',
        );
        return false;
      }
      state = state.copyWith(
        validationLoading: false,
        beneficiaryName: result.beneficiaryName,
        clearValidationError: true,
      );
      return true;
    } on SafariTapPayApiException catch (e) {
      state = state.copyWith(
        validationLoading: false,
        validationError: safariTapPayoutErrorMessage(e),
      );
      return false;
    }
  }

  Future<void> loadQuote(
    Map<String, dynamic> body, {
    required double amount,
    required String currency,
  }) async {
    final requestId = ++_quoteRequestId;
    state = state.copyWith(isLoadingQuote: true, clearQuoteError: true);
    try {
      final quote =
          await ref.read(safariTapPayApiProvider).quotePayout(body);
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
          : 'Unable to load payment quote. Please try again.';
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
}

final kenyaPayFlowProvider = AutoDisposeNotifierProvider.family<
    KenyaPayFlowNotifier, KenyaPayFlowState, KenyaPayKind>(
  KenyaPayFlowNotifier.new,
);
