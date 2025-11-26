import 'package:pretium/features/send_money/screens/payment_method_screen.dart';

class TransactionDetails {
  double amountToSend;
  String fromCurrency;
  double amountToReceive;
  String toCurrency;
  PaymentMethod paymentMethod;
  String recipientFullName;
  String recipientPhoneNumber;
  String? recipientBankName;
  String? recipientAccountNumber;

  TransactionDetails({
    this.amountToSend = 0.0,
    this.fromCurrency = '',
    this.amountToReceive = 0.0,
    this.toCurrency = '',
    this.paymentMethod = PaymentMethod.mobileMoney,
    this.recipientFullName = '',
    this.recipientPhoneNumber = '',
    this.recipientBankName,
    this.recipientAccountNumber,
  });
}
