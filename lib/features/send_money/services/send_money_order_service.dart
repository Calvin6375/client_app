import 'package:cloud_functions/cloud_functions.dart';
import 'package:pretium/utils/logger.dart';

/// Result of a successful createSendMoneyOrder call.
class CreateSendMoneyOrderResult {
  final String orderId;
  final double amount;
  final String currency;
  final String recipientUserId;
  final Map<String, dynamic>? senderNewBalances;
  final Map<String, dynamic>? recipientNewBalances;

  CreateSendMoneyOrderResult({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.recipientUserId,
    this.senderNewBalances,
    this.recipientNewBalances,
  });

  factory CreateSendMoneyOrderResult.fromMap(Map<String, dynamic> data) {
    Map<String, dynamic>? senderNewBalances;
    Map<String, dynamic>? recipientNewBalances;
    final rawSender = data['senderNewBalances'];
    if (rawSender is Map) {
      senderNewBalances = Map<String, dynamic>.from(rawSender);
    }
    final rawRecipient = data['recipientNewBalances'];
    if (rawRecipient is Map) {
      recipientNewBalances = Map<String, dynamic>.from(rawRecipient);
    }
    return CreateSendMoneyOrderResult(
      orderId: data['orderId'] as String,
      amount: (data['amount'] as num).toDouble(),
      currency: data['currency'] as String,
      recipientUserId: data['recipientUserId'] as String,
      senderNewBalances: senderNewBalances,
      recipientNewBalances: recipientNewBalances,
    );
  }
}

/// Calls the backend createSendMoneyOrder callable. The backend creates the
/// order and updates both users' balances; the client must not write to the
/// orders collection.
Future<CreateSendMoneyOrderResult> createSendMoneyOrder({
  String? recipientUserId,
  String? recipientPhoneNumber,
  required double amount,
  required String currency,
  String? note,
}) async {
  if (recipientUserId == null && recipientPhoneNumber == null) {
    throw ArgumentError(
      'Either recipientUserId or recipientPhoneNumber is required',
    );
  }
  final callable =
      FirebaseFunctions.instance.httpsCallable('createSendMoneyOrder');
  final payload = <String, dynamic>{
    'amount': amount,
    'currency': currency,
  };
  if (recipientUserId != null) payload['recipientUserId'] = recipientUserId;
  if (recipientPhoneNumber != null) {
    payload['recipientPhoneNumber'] = recipientPhoneNumber;
  }
  if (note != null) payload['note'] = note;

  Logger.debug('📤 createSendMoneyOrder callable: $payload');
  final result = await callable.call(payload);
  final data = Map<String, dynamic>.from(result.data as Map);
  Logger.success('📥 createSendMoneyOrder success: orderId=${data['orderId']}');
  return CreateSendMoneyOrderResult.fromMap(data);
}
