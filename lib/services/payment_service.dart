import 'package:cloud_functions/cloud_functions.dart';
import 'package:pretium/models/payment_model.dart';
import 'package:pretium/utils/logger.dart';

/// Payment service that calls Cloud Functions
/// All payment creation and updates are done server-side
/// Client code MUST NOT write directly to Realtime Database
class PaymentService {
  // Use us-central1 region (default for Firebase Functions)
  // If your functions are deployed to a different region, change this
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

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
      
      // Debug: Log the full response to understand the structure
      Logger.info('Cloud Function response: $data');
      
      // Handle different response formats - check both camelCase and snake_case
      // The Cloud Function returns: { success: true, paymentId: "...", checkoutUrl: "...", data: {...} }
      // So paymentId should be at the top level, but also check nested data object as fallback
      String? paymentId;
      
      // First try top-level camelCase
      if (data.containsKey('paymentId') && data['paymentId'] != null) {
        paymentId = data['paymentId'].toString();
      }
      // Then try top-level snake_case
      else if (data.containsKey('payment_id') && data['payment_id'] != null) {
        paymentId = data['payment_id'].toString();
      }
      // Then try nested data object
      else if (data['data'] != null) {
        final nestedData = data['data'] as Map<String, dynamic>?;
        if (nestedData != null) {
          if (nestedData.containsKey('payment_id') && nestedData['payment_id'] != null) {
            paymentId = nestedData['payment_id'].toString();
          } else if (nestedData.containsKey('paymentId') && nestedData['paymentId'] != null) {
            paymentId = nestedData['paymentId'].toString();
          }
        }
      }
      
      // Extract checkoutUrl from response (use different name to avoid conflict with parameter)
      final responseCheckoutUrl = data['checkoutUrl'] as String? ?? 
                                  data['checkout_url'] as String? ??
                                  (data['data'] as Map<String, dynamic>?)?['checkout_url'] as String? ??
                                  (data['data'] as Map<String, dynamic>?)?['checkoutUrl'] as String?;
      
      if (paymentId == null) {
        Logger.error('Payment created but paymentId is null. Full response: $data');
        Logger.error('Available keys in response: ${data.keys.toList()}');
        if (data['data'] != null) {
          final nestedData = data['data'] as Map<String, dynamic>?;
          Logger.error('Nested data keys: ${nestedData?.keys.toList()}');
        }
        return {
          'success': false,
          'error': 'Payment created but payment ID is missing from response',
          'code': 'invalid-response',
          'data': data,
        };
      }
      
      Logger.success('Payment created successfully: $paymentId');
      
      return {
        'success': true,
        'paymentId': paymentId,
        'checkoutUrl': responseCheckoutUrl ?? checkoutUrl, // Use response value or fallback to parameter
        'data': data,
      };
    } on FirebaseFunctionsException catch (e) {
      Logger.error('Cloud Function error: ${e.code}', e);
      
      // Provide more helpful error messages
      String errorMessage = e.message ?? 'Payment creation failed';
      if (e.code == 'not-found') {
        errorMessage = 'Payment function not found. Please ensure the Cloud Function "createPayment" is deployed.';
        Logger.warning('The createPayment Cloud Function may not be deployed. Run: firebase deploy --only functions');
      } else if (e.code == 'unauthenticated') {
        errorMessage = 'Authentication required. Please log in and try again.';
      } else if (e.code == 'permission-denied') {
        errorMessage = 'Permission denied. You may not have access to create payments.';
      } else if (e.code == 'invalid-argument') {
        errorMessage = 'Invalid payment data: ${e.message ?? "Please check your input"}';
      }
      
      return {
        'success': false,
        'error': errorMessage,
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

