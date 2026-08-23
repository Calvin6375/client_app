/// Removes third-party payment provider names from user-visible copy.
class ProviderDisplaySanitizer {
  ProviderDisplaySanitizer._();

  static const _providerPattern =
      r'paystack|transak|transack|intasend|inta[\s-]?send|transfi';

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
        final humanized = reconType.replaceAll('_', ' ').trim();
        return sanitize(humanized);
    }
  }

  /// Returns true when [key] is an internal provider identifier field.
  static bool isHiddenMetadataKey(String key) {
    final normalized = key.trim().toLowerCase();
    const hidden = {
      'provider',
      'paymentprovider',
      'payment_provider',
      'fundingprovider',
      'funding_provider',
      'checkoutprovider',
      'checkout_provider',
      'paystackreference',
      'paystack_reference',
      'transakreference',
      'transak_reference',
      'intasendcheckoutid',
      'intasend_checkout_id',
    };
    return hidden.contains(normalized.replaceAll('.', '').replaceAll('_', '')) ||
        normalized.contains('paystack') ||
        normalized.contains('transak') ||
        normalized.contains('intasend');
  }
}
