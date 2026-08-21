import 'package:pretium/features/send_money/screens/payment_method_screen.dart';

class TransactionDetails {
  double amountToSend;
  String fromCurrency;
  double amountToReceive;
  String toCurrency;
  PaymentMethod paymentMethod;
  String recipientFullName;
  String recipientPhoneNumber;
  /// Mobile money network (e.g. Safaricom) when [paymentMethod] is mobile money.
  String recipientMobileNetwork;
  String? recipientBankName;
  String? recipientAccountNumber;
  /// Kenyan bank code from `GET /safari-card/banks` when paying by bank.
  String? recipientBankCode;
  /// Name returned by validate-beneficiary before confirm.
  String verifiedBeneficiaryName;

  TransactionDetails({
    this.amountToSend = 0.0,
    this.fromCurrency = '',
    this.amountToReceive = 0.0,
    this.toCurrency = '',
    this.paymentMethod = PaymentMethod.mobileMoney,
    this.recipientFullName = '',
    this.recipientPhoneNumber = '',
    this.recipientMobileNetwork = '',
    this.recipientBankName,
    this.recipientAccountNumber,
    this.recipientBankCode,
    this.verifiedBeneficiaryName = '',
  });
}
