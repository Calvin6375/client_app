import 'package:cloud_functions/cloud_functions.dart';
import 'package:pretium/utils/logger.dart';

/// Result of a successful createSwapOrder call.
class CreateSwapOrderResult {
  final String orderId;
  final double fromAmount;
  final double toAmount;
  final double fee;
  final Map<String, dynamic>? newBalances;

  CreateSwapOrderResult({
    required this.orderId,
    required this.fromAmount,
    required this.toAmount,
    required this.fee,
    this.newBalances,
  });

  factory CreateSwapOrderResult.fromMap(Map<String, dynamic> data) {
    Map<String, dynamic>? newBalances;
    final raw = data['newBalances'];
    if (raw is Map) {
      newBalances = Map<String, dynamic>.from(raw);
    }
    return CreateSwapOrderResult(
      orderId: data['orderId'] as String,
      fromAmount: (data['fromAmount'] as num).toDouble(),
      toAmount: (data['toAmount'] as num).toDouble(),
      fee: (data['fee'] as num?)?.toDouble() ?? 0.0,
      newBalances: newBalances,
    );
  }
}

/// Calls the backend createSwapOrder callable. The backend creates the order
/// and updates balances; the client must not write to the orders collection.
Future<CreateSwapOrderResult> createSwapOrder({
  required String fromCurrency,
  required String toCurrency,
  required double fromAmount,
  required double exchangeRate,
  double? fee,
  double? feeRate,
  double? toAmount,
}) async {
  final callable = FirebaseFunctions.instance.httpsCallable('createSwapOrder');
  final payload = <String, dynamic>{
    'fromCurrency': fromCurrency,
    'toCurrency': toCurrency,
    'fromAmount': fromAmount,
    'exchangeRate': exchangeRate,
  };
  if (fee != null) payload['fee'] = fee;
  if (feeRate != null) payload['feeRate'] = feeRate;
  if (toAmount != null) payload['toAmount'] = toAmount;

  Logger.debug('📤 createSwapOrder callable: $payload');
  final result = await callable.call(payload);
  final data = Map<String, dynamic>.from(result.data as Map);
  Logger.success('📥 createSwapOrder success: orderId=${data['orderId']}');
  return CreateSwapOrderResult.fromMap(data);
}
