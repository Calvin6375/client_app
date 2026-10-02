import 'package:flutter_test/flutter_test.dart';
import 'package:pretium/utils/provider_display_sanitizer.dart';

void main() {
  test('payment errors never show processor or backend details', () {
    expect(
      ProviderDisplaySanitizer.userFacingPaymentError(
        'Crossmint 400: Onramp is not yet enabled for production use in this project. You can start testing in staging.crossmint.com.',
      ),
      ProviderDisplaySanitizer.genericPaymentFailure,
    );
    expect(
      ProviderDisplaySanitizer.userFacingPaymentError('No checkout URL returned from server'),
      ProviderDisplaySanitizer.genericPaymentFailure,
    );
    expect(
      ProviderDisplaySanitizer.userFacingPaymentError(null),
      ProviderDisplaySanitizer.genericPaymentFailure,
    );
  });

  test('strips paylio and other processors from titles', () {
    expect(
      ProviderDisplaySanitizer.sanitize('Wallet top-up (paylio)'),
      'Wallet top-up',
    );
    expect(
      ProviderDisplaySanitizer.sanitize('funding paylio'),
      'funding',
    );
    expect(
      ProviderDisplaySanitizer.labelFromReconType(
        'funding_paylio',
        isDebit: false,
      ),
      'Wallet top-up',
    );
  });

  test('hides checkout, fees, settlement, and processor references', () {
    expect(ProviderDisplaySanitizer.isHiddenMetadataKey('checkoutUrl'), isTrue);
    expect(ProviderDisplaySanitizer.isHiddenMetadataKey('Checkout Url'), isTrue);
    expect(ProviderDisplaySanitizer.isHiddenMetadataKey('reference'), isTrue);
    expect(
      ProviderDisplaySanitizer.isHiddenMetadataKey('passFeeToCustomer'),
      isTrue,
    );
    expect(ProviderDisplaySanitizer.isHiddenMetadataKey('providerFee'), isTrue);
    expect(
      ProviderDisplaySanitizer.isHiddenMetadataKey('settlementCoin'),
      isTrue,
    );
    expect(
      ProviderDisplaySanitizer.isHiddenMetadataKey('customerPayAmount'),
      isTrue,
    );
    expect(ProviderDisplaySanitizer.isHiddenMetadataKey('feeAmount'), isTrue);
    expect(
      ProviderDisplaySanitizer.isProcessorInternalValue(
        'https://paylio.org/pay/abc',
      ),
      isTrue,
    );
    expect(
      ProviderDisplaySanitizer.isProcessorInternalValue(
        'funding_order_fund_1790967354043_nf290jyz',
      ),
      isTrue,
    );
    expect(
      ProviderDisplaySanitizer.isProcessorInternalValue(
        'corr_dad8341a-0e29-4911-8687-2ee789fafe7',
      ),
      isTrue,
    );
  });

  test('auth and network still get a short generic prompt', () {
    expect(
      ProviderDisplaySanitizer.userFacingPaymentError('unauthenticated'),
      'Please sign in again and try again.',
    );
    expect(
      ProviderDisplaySanitizer.userFacingPaymentError('SocketException: timed out'),
      'Check your connection and try again.',
    );
  });
}
