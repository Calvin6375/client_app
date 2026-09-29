import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pretium/features/topup/models/create_payment_result.dart';
import 'package:pretium/features/topup/screens/usd_funding_instructions_screen.dart';

void main() {
  group('CreatePaymentResult.fromResponse', () {
    test('A: KES + Paystack + checkoutUrl opens hosted checkout', () {
      final result = CreatePaymentResult.fromResponse({
        'success': true,
        'provider': 'paystack',
        'currency': 'KES',
        'status': 'pending',
        'checkoutUrl': 'https://checkout.paystack.com/abc',
        'url': null,
        'authorization_url': null,
        'invoiceId': 'inv_kes_1',
        'amount': 150,
      });

      expect(result.flow, CreatePaymentFlow.hostedCheckout);
      expect(result.opensHostedCheckout, isTrue);
      expect(result.showsGridUsdInstructions, isFalse);
      expect(result.isError, isFalse);
      expect(result.checkoutUrl, 'https://checkout.paystack.com/abc');
      expect(result.invoiceId, 'inv_kes_1');
      expect(result.isPaymentSettled, isFalse);
    });

    test('B: USD + Grid + null checkoutUrl + instructions is not an error', () {
      final result = CreatePaymentResult.fromResponse(_gridUsdResponse());

      expect(result.isError, isFalse);
      expect(result.error, isNull);
      expect(result.flow, CreatePaymentFlow.gridUsdInstructions);
      expect(result.showsGridUsdInstructions, isTrue);
      expect(result.opensHostedCheckout, isFalse);
      expect(result.checkoutUrl, isNull);
      expect(result.fundingOrderId, 'fund_1790614153519_azi9kmztr');
      expect(result.instructions, hasLength(2));
    });

    test('C: USD + Grid + missing fundingPaymentInstructions is an error', () {
      final result = CreatePaymentResult.fromResponse({
        'success': true,
        'provider': 'grid',
        'currency': 'USD',
        'status': 'pending',
        'checkoutUrl': null,
        'url': null,
        'authorization_url': null,
        'fundingOrderId': 'fund_missing_instr',
        'amount': 6,
      });

      expect(result.flow, CreatePaymentFlow.error);
      expect(result.isError, isTrue);
      expect(
        result.error,
        'Funding instructions were not returned. Please try again.',
      );
      expect(result.showsGridUsdInstructions, isFalse);
    });

    test('D: USD + Grid + pending never reports payment success', () {
      final result = CreatePaymentResult.fromResponse(_gridUsdResponse());

      expect(result.status, 'pending');
      expect(result.isPaymentSettled, isFalse);
      expect(result.flow, isNot(CreatePaymentFlow.hostedCheckout));
    });

    test('E: Grid ACH/WIRE/RTP/FEDNOW rails parse from accountOrWalletInfo', () {
      final result = CreatePaymentResult.fromResponse(_gridUsdResponse());
      final ach = result.instructions.first.account;

      expect(ach.bankName, 'Cross River Bank');
      expect(ach.accountNumber, '2725278113');
      expect(ach.routingNumber, '606418203');
      expect(ach.accountType, 'USD_ACCOUNT');
      expect(ach.reference, '01a0e8e1-3aec-438c-0000-8223756e2878');
      expect(ach.paymentRails, ['ACH', 'WIRE', 'RTP', 'FEDNOW']);
      expect(
        result.instructions.first.instructionsNotes,
        contains('reference code'),
      );
    });

    test('F: Grid SWIFT instruction parses holder, SWIFT, and rails', () {
      final result = CreatePaymentResult.fromResponse(_gridUsdResponse());
      final swift = result.instructions[1].account;

      expect(swift.accountHolderName, 'Ruben Mwachiramba');
      expect(swift.bankName, 'Sandbox Bank');
      expect(swift.country, 'US');
      expect(swift.swiftCode, 'HCBLUSFFXXX');
      expect(swift.accountType, 'SWIFT_ACCOUNT');
      expect(swift.accountNumber, '3436991190');
      expect(swift.paymentRails, ['SWIFT']);
    });

    test('backend success:false stays an error', () {
      final result = CreatePaymentResult.fromResponse({
        'success': false,
        'error': 'Wallet not eligible',
      });
      expect(result.isError, isTrue);
      expect(result.error, 'Wallet not eligible');
    });
  });

  testWidgets('USD funding screen stays pending and shows returned methods',
      (tester) async {
    final result = CreatePaymentResult.fromResponse(_gridUsdResponse());

    await tester.pumpWidget(
      MaterialApp(
        home: UsdFundingInstructionsScreen(result: result),
      ),
    );

    expect(find.text('USD funding'), findsOneWidget);
    expect(
      find.text(
        'Send USD using one of the payment methods below. Your TruePay balance will update after the payment is received and confirmed.',
      ),
      findsOneWidget,
    );
    expect(find.text('pending'), findsOneWidget);
    expect(find.text('fund_1790614153519_azi9kmztr'), findsOneWidget);
    expect(find.text('6.00 USD'), findsOneWidget);
    expect(find.text('ACH · WIRE · RTP · FEDNOW'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('HCBLUSFFXXX'), 200);
    expect(find.text('Payment successful'), findsNothing);
    expect(find.text('No checkout URL returned from server'), findsNothing);
  });
}

Map<String, dynamic> _gridUsdResponse() {
  return {
    'success': true,
    'provider': 'grid',
    'currency': 'USD',
    'status': 'pending',
    'amount': 6,
    'totalToPay': 6,
    'checkoutUrl': null,
    'url': null,
    'authorization_url': null,
    'fundingOrderId': 'fund_1790614153519_azi9kmztr',
    'fundingPaymentInstructions': [
      {
        'accountOrWalletInfo': {
          'reference': '01a0e8e1-3aec-438c-0000-8223756e2878',
          'bankName': 'Cross River Bank',
          'accountNumber': '2725278113',
          'accountType': 'USD_ACCOUNT',
          'routingNumber': '606418203',
          'bankAddress': '885 Teaneck Road, Teaneck, NJ 07666',
          'paymentRails': ['ACH', 'WIRE', 'RTP', 'FEDNOW'],
        },
        'instructionsNotes':
            'Please ensure the reference code is included in the payment memo/description field',
      },
      {
        'accountOrWalletInfo': {
          'accountHolderName': 'Ruben Mwachiramba',
          'bankName': 'Sandbox Bank',
          'country': 'US',
          'swiftCode': 'HCBLUSFFXXX',
          'accountType': 'SWIFT_ACCOUNT',
          'accountNumber': '3436991190',
          'paymentRails': ['SWIFT'],
        },
        'instructionsNotes':
            'Payments are attributed automatically by the destination account; no reference code is required.',
      },
    ],
  };
}
