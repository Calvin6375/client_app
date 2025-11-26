import 'package:cloud_functions/cloud_functions.dart';
import 'package:pretium/models/payment_model.dart';
import 'package:pretium/utils/logger.dart';

/// Payment service that calls Cloud Functions
/// All payment creation and updates are done server-side
/// Client code MUST NOT write directly to Realtime Database
class PaymentService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Create a payment via Cloud Function
  /// This calls the server-side createPayment function
  Future<Map<String, dynamic>> createPayment({
    required double amount,
    required String currency,
    required String email,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    String? checkoutUrl,
    String? intasendCheckoutId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      Logger.info('Creating payment via Cloud Function');
      
      final callable = _functions.httpsCallable('createPayment');
      
      final result = await callable.call({
        'amount': amount,
        'currency': currency.toUpperCase(),
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (checkoutUrl != null) 'checkoutUrl': checkoutUrl,
        if (intasendCheckoutId != null) 'intasendCheckoutId': intasendCheckoutId,
        if (metadata != null) 'metadata': metadata,
      });
      
      final data = result.data as Map<String, dynamic>;
      Logger.success('Payment created successfully: ${data['paymentId']}');
      
      return {
        'success': true,
        'paymentId': data['paymentId'],
        'checkoutUrl': data['checkoutUrl'],
        'data': data,
      };
    } on FirebaseFunctionsException catch (e) {
      Logger.error('Cloud Function error: ${e.code}', e);
      return {
        'success': false,
        'error': e.message ?? 'Payment creation failed',
        'code': e.code,
      };
    } catch (e) {
      Logger.error('Failed to create payment', e);
      return {
        'success': false,
        'error': 'Unexpected error: $e',
      };
    }
  }

  /// Handle payment webhook via Cloud Function
  /// This is called when IntaSend sends a webhook notification
  Future<Map<String, dynamic>> handlePaymentWebhook({
    required String paymentId,
    required String status,
    String? transactionId,
    Map<String, dynamic>? webhookData,
  }) async {
    try {
      Logger.info('Handling payment webhook via Cloud Function: $paymentId');
      
      final callable = _functions.httpsCallable('handlePaymentWebhook');
      
      final result = await callable.call({
        'paymentId': paymentId,
        'status': status,
        if (transactionId != null) 'transactionId': transactionId,
        if (webhookData != null) 'webhookData': webhookData,
      });
      
      final data = result.data as Map<String, dynamic>;
      Logger.success('Payment webhook handled: $paymentId');
      
      return {
        'success': true,
        'data': data,
      };
    } on FirebaseFunctionsException catch (e) {
      Logger.error('Cloud Function error: ${e.code}', e);
      return {
        'success': false,
        'error': e.message ?? 'Webhook handling failed',
        'code': e.code,
      };
    } catch (e) {
      Logger.error('Failed to handle payment webhook', e);
      return {
        'success': false,
        'error': 'Unexpected error: $e',
      };
    }
  }

  /// Update wallet after payment completion
  /// This is called by Cloud Functions, not directly by client
  /// Included here for reference only
  Future<Map<String, dynamic>> updateWalletAfterPayment({
    required String userId,
    required double amount,
    required String currency,
  }) async {
    try {
      Logger.info('Updating wallet after payment via Cloud Function');
      
      final callable = _functions.httpsCallable('updateWalletAfterPayment');
      
      final result = await callable.call({
        'userId': userId,
        'amount': amount,
        'currency': currency,
      });
      
      final data = result.data as Map<String, dynamic>;
      Logger.success('Wallet updated successfully');
      
      return {
        'success': true,
        'data': data,
      };
    } on FirebaseFunctionsException catch (e) {
      Logger.error('Cloud Function error: ${e.code}', e);
      return {
        'success': false,
        'error': e.message ?? 'Wallet update failed',
        'code': e.code,
      };
    } catch (e) {
      Logger.error('Failed to update wallet', e);
      return {
        'success': false,
        'error': 'Unexpected error: $e',
      };
    }
  }
}

