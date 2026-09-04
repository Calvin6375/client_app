import 'package:pretium/features/safari_tap/services/safari_tap_pay_api_service.dart';

/// User-facing SafariTap / send / pay error copy.
///
/// Never surfaces payment-processor brand names (IntaSend, Paystack, etc.).
String safariTapPayoutErrorMessage(SafariTapPayApiException error) {
  final code = error.code ?? '';
  final raw = error.message?.trim();
  final hint = _sanitizeUserText(error.hint?.trim());

  // Prefer a clean hint only when it does not leak provider branding.
  if (hint != null && hint.isNotEmpty && !_looksLikeProviderLeak(hint)) {
    return hint;
  }

  return switch (code) {
    'UNAUTHORIZED' => 'Please sign in again to continue.',
    'INSUFFICIENT_BALANCE' =>
      'Insufficient KES balance. Reduce the amount or top up your wallet.',
    'INVALID_PHONE_NUMBER' => 'Enter a valid M-Pesa phone number (07… or 2547…).',
    'RECIPIENT_NOT_FOUND' =>
      'No SafariTap user found for that phone number. Ask them to sign up first.',
    'SELF_TRANSFER' => 'You can’t send money to your own SafariTap wallet.',
    'INVALID_PAYBILL_REFERENCE' =>
      'Enter a valid PayBill account reference (1–20 characters).',
    'INVALID_BANK_ACCOUNT' ||
    'INVALID_TILL' ||
    'INVALID_ACCOUNT' =>
      'Couldn’t verify this till number. Check the number and try again.',
    'INVALID_AMOUNT' => _safeRaw(raw) ?? 'Enter a valid amount.',
    'VALIDATION_FAILED' => _validationFailedMessage(raw),
    'UNSUPPORTED_PAYOUT_TYPE' => 'This payment type is not supported.',
    'NOT_FOUND' => 'Payment not found.',
    'PROVIDER_AUTH_ERROR' =>
      'Payments are temporarily unavailable. Please try again later.',
    'PROVIDER_ERROR' || 'PAYOUT_FAILED' => _providerErrorMessage(raw),
    _ => _genericOrMappedRaw(raw),
  };
}

String _validationFailedMessage(String? raw) {
  if (_isInvalidAccountOrTill(raw)) {
    return 'Couldn’t verify this till number. Check the number and try again.';
  }
  return _safeRaw(raw) ?? 'Check the details and try again.';
}

String _providerErrorMessage(String? raw) {
  if (_isInvalidAccountOrTill(raw)) {
    return 'Couldn’t verify this till number. Check the number and try again.';
  }
  if (_isProviderAuthFailure(raw)) {
    return 'Payments are temporarily unavailable. Please try again later.';
  }
  return 'Payment could not be completed. Please try again.';
}

String _genericOrMappedRaw(String? raw) {
  if (_isInvalidAccountOrTill(raw)) {
    return 'Couldn’t verify this till number. Check the number and try again.';
  }
  if (_isProviderAuthFailure(raw)) {
    return 'Payments are temporarily unavailable. Please try again later.';
  }
  return _safeRaw(raw) ?? 'Something went wrong. Please try again.';
}

bool _isInvalidAccountOrTill(String? raw) {
  if (raw == null || raw.isEmpty) return false;
  final lower = raw.toLowerCase();
  return lower.contains('invalid request or account number') ||
      lower.contains('invalid account') ||
      lower.contains('invalid till') ||
      lower.contains('account number') ||
      (lower.contains('till') && lower.contains('invalid'));
}

bool _isProviderAuthFailure(String? raw) {
  if (raw == null || raw.isEmpty) return false;
  final lower = raw.toLowerCase();
  return lower.contains('authenticating') ||
      lower.contains('authentication failed') ||
      lower.contains('api keys') ||
      lower.contains('misconfigured');
}

/// Returns [raw] only when it is safe to show end users.
String? _safeRaw(String? raw) {
  final cleaned = _sanitizeUserText(raw);
  if (cleaned == null || cleaned.isEmpty) return null;
  if (_looksLikeProviderLeak(cleaned)) return null;
  return cleaned;
}

bool _looksLikeProviderLeak(String text) {
  final lower = text.toLowerCase();
  const brands = [
    'intasend',
    'paystack',
    'transak',
    'intatransfer',
    'flutterwave',
    'stripe',
  ];
  for (final brand in brands) {
    if (lower.contains(brand)) return true;
  }
  // "API error (400): …" style provider dumps
  if (RegExp(r'api error\s*\(\d+\)', caseSensitive: false).hasMatch(text)) {
    return true;
  }
  return false;
}

String? _sanitizeUserText(String? text) {
  if (text == null) return null;
  var cleaned = text.trim();
  if (cleaned.isEmpty) return null;

  // Strip common provider brand tokens if a hint otherwise looks usable.
  const brands = [
    'IntaSend',
    'intasend',
    'Paystack',
    'paystack',
    'Transak',
    'transak',
  ];
  for (final brand in brands) {
    cleaned = cleaned.replaceAll(brand, 'payment provider');
  }
  cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return cleaned.isEmpty ? null : cleaned;
}
