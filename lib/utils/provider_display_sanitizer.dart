/// Removes third-party payment provider names from user-visible copy.
class ProviderDisplaySanitizer {
  ProviderDisplaySanitizer._();

  static const _providerPattern =
      r'paylio|paystack|transak|transack|intasend|inta[\s-]?send|transfi|crossmint|persona|grid|circle|onramp';

  static final RegExp _parentheticalProvider = RegExp(
    r'\s*\([^)]*(?:' + _providerPattern + r')[^)]*\)',
    caseSensitive: false,
  );

  static final RegExp _inlineProvider = RegExp(
    _providerPattern,
    caseSensitive: false,
  );

  static final RegExp _trailingProvider = RegExp(
    r'\s*[-–—]\s*(?:' + _providerPattern + r')\s*$',
    caseSensitive: false,
  );

  static final RegExp _leadingViaProvider = RegExp(
    r'^(?:via|through|with|using)\s+(?:' + _providerPattern + r')\s*[-–—]?\s*',
    caseSensitive: false,
  );

  static final RegExp _multiSpace = RegExp(r'\s{2,}');
  static final RegExp _emptyParens = RegExp(r'\(\s*\)');

  /// Strips provider names and tidies spacing/punctuation.
  static String sanitize(String? value) {
    if (value == null) return '';
    var text = value.trim();
    if (text.isEmpty) return '';

    text = text.replaceAll(_parentheticalProvider, '');
    text = text.replaceAll(_trailingProvider, '');
    text = text.replaceAll(_leadingViaProvider, '');
    text = text.replaceAll(_inlineProvider, '');
    text = text.replaceAll(_emptyParens, '');
    text = text.replaceAll(_multiSpace, ' ');
    text = text.replaceAll(RegExp(r'\s+([,.;:])'), r'$1');
    text = text.trim().replaceAll(RegExp(r'^[-–—,\s]+|[-–—,\s]+$'), '');

    return text.trim();
  }

  /// Maps backend recon slugs to neutral customer-facing labels.
  static String labelFromReconType(String? reconType, {required bool isDebit}) {
    if (reconType == null || reconType.trim().isEmpty) return '';
    switch (reconType.trim().toLowerCase()) {
      case 'funding_paystack':
      case 'funding_transak':
      case 'funding_crossmint':
      case 'funding_paylio':
      case 'topup_intasend':
      case 'funding':
      case 'topup':
      case 'direct_topup':
        return 'Wallet top-up';
      case 'merchant_payment':
        return 'Merchant payment';
      case 'send':
      case 'send_money':
        return 'Send money';
      case 'receive':
      case 'money_received':
        return 'Money received';
      case 'withdraw':
      case 'withdrawal':
      case 'payout':
        return 'Withdrawal';
      case 'swap':
        return 'Currency swap';
      default:
        final lower = reconType.trim().toLowerCase();
        if (lower.startsWith('funding') ||
            lower.contains('topup') ||
            lower.contains('top_up') ||
            lower.contains('paylio')) {
          return 'Wallet top-up';
        }
        final humanized = reconType.replaceAll('_', ' ').trim();
        return sanitize(humanized);
    }
  }

  /// Returns true when [key] is an internal provider / checkout field.
  static bool isHiddenMetadataKey(String key) {
    final normalized = _normalizeKey(key);
    if (normalized.isEmpty) return false;
    const hidden = {
      'provider',
      'paymentprovider',
      'fundingprovider',
      'checkoutprovider',
      'checkout',
      'checkouturl',
      'checkouturi',
      'checkoutlink',
      'hostedcheckouturl',
      'payurl',
      'paymenturl',
      'reference',
      'referenceid',
      'providerreference',
      'paystackreference',
      'transakreference',
      'intasendcheckoutid',
      'correlationid',
      'passfeetocustomer',
      'passfeestocustomer',
      'providerfee',
      'providerfees',
      'providerfeeamount',
      'settlementcoin',
      'settlementasset',
      'settlementcurrency',
      'customerpayamount',
      'customerpay',
      'feeamount',
      'processingfee',
      'processorfee',
    };
    if (hidden.contains(normalized)) return true;
    if (normalized.contains('paylio')) return true;
    if (normalized.contains('paystack')) return true;
    if (normalized.contains('transak')) return true;
    if (normalized.contains('intasend')) return true;
    if (normalized.contains('crossmint')) return true;
    if (normalized.contains('checkout')) return true;
    if (normalized.contains('settlementcoin') ||
        normalized.contains('settlementasset')) {
      return true;
    }
    if (normalized.contains('providerfee')) return true;
    if (normalized.contains('passfee')) return true;
    return false;
  }

  /// Values that leak processor rails: checkout URLs, order ids, partner names.
  static bool isProcessorInternalValue(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return true;
    }
    if (lower.startsWith('corr_') || lower.startsWith('funding_order')) {
      return true;
    }
    return _inlineProvider.hasMatch(text);
  }

  static String _normalizeKey(String key) =>
      key.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Safe copy for payment-failure dialogs. Never forward raw backend or
  /// processor messages (HTTP codes, staging URLs, partner names).
  static const genericPaymentFailure =
      'We couldn’t complete this payment right now. Please try again later.';

  static String userFacingPaymentError(String? raw) {
    final text = (raw ?? '').trim().toLowerCase();
    if (text.isEmpty) return genericPaymentFailure;

    if (text.contains('unauthenticated') ||
        text.contains('authentication failed') ||
        text.contains('sign in') ||
        text.contains('logged in')) {
      return 'Please sign in again and try again.';
    }
    if (text.contains('network') ||
        text.contains('socket') ||
        text.contains('timed out') ||
        text.contains('timeout') ||
        text.contains('connection')) {
      return 'Check your connection and try again.';
    }

    return genericPaymentFailure;
  }
}
