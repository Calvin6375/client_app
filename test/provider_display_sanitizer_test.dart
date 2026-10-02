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
