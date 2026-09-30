import 'package:flutter_test/flutter_test.dart';
import 'package:pretium/features/topup/models/topup_deposit_country.dart';
import 'package:pretium/features/topup/providers/topup_flow_provider.dart';

void main() {
  group('topupDepositPickerCodes', () {
    test('includes fiat plus USDC, USDT, and BNB', () {
      final codes = topupDepositPickerCodes(apiCodes: ['USD', 'KES', 'GBP']);
      expect(codes, containsAll(['USD', 'KES', 'GBP', 'USDC', 'USDT', 'BNB']));
      expect(
        codes.sublist(codes.length - 3),
        ['USDC', 'USDT', 'BNB'],
      );
    });

    test('does not treat USDC as fiat', () {
      expect(TopupDepositCountry.isAllowedOnDepositSelector('USDC'), isFalse);
      expect(TopupDepositCountry.isCryptoDepositAsset('usdt'), isTrue);
      expect(TopupDepositCountry.isCryptoDepositAsset('BNB'), isTrue);
      expect(TopupDepositCountry.isCryptoDepositAsset('USD'), isFalse);
    });
  });

  group('TopUpFlowState routing', () {
    test('starts with no currency selected', () {
      const state = TopUpFlowState();
      expect(state.hasSelectedCurrency, isFalse);
      expect(state.selectedCurrency, isEmpty);
      expect(state.isCryptoDeposit, isFalse);
    });

    test('crypto currencies skip hosted checkout', () {
      expect(
        const TopUpFlowState(selectedCurrency: 'USDC').isCryptoDeposit,
        isTrue,
      );
      expect(
        const TopUpFlowState(selectedCurrency: 'USDT').isCryptoDeposit,
        isTrue,
      );
      expect(
        const TopUpFlowState(selectedCurrency: 'BNB').isCryptoDeposit,
        isTrue,
      );
      expect(
        const TopUpFlowState(selectedCurrency: 'USD').isCryptoDeposit,
        isFalse,
      );
      expect(
        const TopUpFlowState(selectedCurrency: 'KES').cardMobileMoneyProvider,
        'paystack',
      );
    });
  });
}
