import 'package:pretium/features/safari_tap/services/safari_tap_pay_api_service.dart';

String safariTapPayoutErrorMessage(SafariTapPayApiException error) {
  final code = error.code ?? '';
  final raw = error.message?.trim();
  final hint = error.hint?.trim();
  if (hint != null && hint.isNotEmpty) return hint;

  return switch (code) {
    'UNAUTHORIZED' => raw?.isNotEmpty == true
        ? raw!
        : 'Please sign in again to continue.',
    'INSUFFICIENT_BALANCE' =>
      'Insufficient KES balance. Reduce the amount or top up your wallet.',
    'INVALID_PHONE_NUMBER' => 'Enter a valid M-Pesa phone number (07… or 2547…).',
    'RECIPIENT_NOT_FOUND' =>
      'No SafariTap user found for that phone number. Ask them to sign up first.',
    'SELF_TRANSFER' => 'You can’t send money to your own SafariTap wallet.',
    'INVALID_PAYBILL_REFERENCE' =>
      'Enter a valid PayBill account reference (1–20 characters).',
    'INVALID_BANK_ACCOUNT' => 'Check the bank account details and try again.',
    'INVALID_AMOUNT' => raw ?? 'Enter a valid amount.',
    'VALIDATION_FAILED' => raw ?? 'Check the details and try again.',
    'UNSUPPORTED_PAYOUT_TYPE' => 'This payment type is not supported.',
    'NOT_FOUND' => 'Payment not found.',
    'PROVIDER_ERROR' || 'PAYOUT_FAILED' => _providerErrorMessage(raw, error),
    _ => raw ?? 'Something went wrong. Please try again.',
  };
}

String _providerErrorMessage(String? raw, SafariTapPayApiException error) {
  if (raw != null &&
      raw.toLowerCase().contains('intasend') &&
      raw.toLowerCase().contains('authenticating')) {
    return 'Payment provider is not configured on the server. Please try again later or contact support.';
  }
  return raw ?? 'Payment could not be completed. Please try again.';
}
