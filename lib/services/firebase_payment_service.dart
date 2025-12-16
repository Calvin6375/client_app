// DEPRECATED: This file is kept for backward compatibility only
// 
// ⚠️ SECURITY WARNING: This service allows client-side writes to Firebase
// which is a security risk. All payment operations should use:
// - PaymentService (calls Cloud Functions)
// - PaymentRepository (read-only streams)
//
// This file will be removed in a future version.
// Please migrate to the new architecture.

import 'package:pretium/utils/logger.dart';

/// @deprecated Use PaymentService and PaymentRepository instead
/// This class is deprecated and will be removed
@Deprecated('Use PaymentService and PaymentRepository instead')
class FirebasePaymentService {
  // All methods have been moved to:
  // - PaymentService.createPayment() - for creating payments via Cloud Functions
  // - PaymentRepository.streamUserPayments() - for reading payments
  // - PaymentRepository.getPaymentById() - for getting a specific payment
  
  @Deprecated('Use PaymentService.createPayment() instead')
  static Future<Map<String, dynamic>> storePaymentInitiation({
    required String paymentId,
    required double amount,
    required String currency,
    required String email,
    required String firstName,
    required String lastName,
    required String checkoutUrl,
    required String intaSendCheckoutId,
    Map<String, dynamic>? additionalData,
  }) async {
    Logger.warning('storePaymentInitiation is deprecated. Use PaymentService.createPayment() instead');
    throw UnimplementedError('Use PaymentService.createPayment() instead');
  }

  @Deprecated('Use PaymentService.handlePaymentWebhook() instead')
  static Future<Map<String, dynamic>> markPaymentLinkOpened({
    required String paymentId,
    Map<String, dynamic>? additionalData,
  }) async {
    Logger.warning('markPaymentLinkOpened is deprecated. Use PaymentService.handlePaymentWebhook() instead');
    throw UnimplementedError('Use PaymentService.handlePaymentWebhook() instead');
  }

  @Deprecated('Use PaymentService.handlePaymentWebhook() instead')
  static Future<Map<String, dynamic>> markPaymentCompleted({
    required String paymentId,
    String? transactionId,
    Map<String, dynamic>? paymentDetails,
  }) async {
    Logger.warning('markPaymentCompleted is deprecated. Use PaymentService.handlePaymentWebhook() instead');
    throw UnimplementedError('Use PaymentService.handlePaymentWebhook() instead');
  }

  @Deprecated('Use PaymentService.handlePaymentWebhook() instead')
  static Future<Map<String, dynamic>> markPaymentFailed({
    required String paymentId,
    String? errorReason,
    Map<String, dynamic>? errorDetails,
  }) async {
    Logger.warning('markPaymentFailed is deprecated. Use PaymentService.handlePaymentWebhook() instead');
    throw UnimplementedError('Use PaymentService.handlePaymentWebhook() instead');
  }

  @Deprecated('Use PaymentRepository.getPaymentById() instead')
  static Future<Map<String, dynamic>?> getPaymentById(String paymentId) async {
    Logger.warning('getPaymentById is deprecated. Use PaymentRepository.getPaymentById() instead');
    throw UnimplementedError('Use PaymentRepository.getPaymentById() instead');
  }

  @Deprecated('Use PaymentRepository.streamUserPayments() instead')
  static Future<List<Map<String, dynamic>>> getUserPayments({int? limit}) async {
    Logger.warning('getUserPayments is deprecated. Use PaymentRepository.streamUserPayments() instead');
    throw UnimplementedError('Use PaymentRepository.streamUserPayments() instead');
  }

  @Deprecated('Payment IDs are now generated server-side via Cloud Functions')
  static String generatePaymentId() {
    Logger.warning('generatePaymentId is deprecated. Payment IDs are generated server-side');
    throw UnimplementedError('Payment IDs are generated server-side via Cloud Functions');
  }
}
