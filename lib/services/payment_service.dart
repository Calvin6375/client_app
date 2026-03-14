import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretium/utils/logger.dart';

/// Payment service that calls Cloud Functions
/// All payment creation and updates are done server-side
/// Client code MUST NOT write directly to Realtime Database
class PaymentService {
  // Use us-central1 region (default for Firebase Functions)
  // If your functions are deployed to a different region, change this
  // Note: We don't cache the instance to ensure fresh auth tokens
  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  /// Ensure user is authenticated and token is fresh before calling Cloud Function
  Future<void> _ensureAuthenticated() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: 'User must be logged in to create payments',
      );
    }
    
    // Force token refresh to ensure it's valid and propagated
    try {
      await user.getIdToken(true);
      Logger.debug('✅ Auth token refreshed successfully');
      Logger.debug('   User UID: ${user.uid}');
      Logger.debug('   User email: ${user.email ?? 'N/A'}');
    } catch (e) {
      Logger.warning('⚠️ Token refresh warning: $e');
      // Try getting token without force refresh
      try {
        await user.getIdToken();
        Logger.debug('✅ Auth token retrieved (non-forced)');
      } catch (e2) {
        Logger.error('❌ Failed to get auth token', e2);
        throw FirebaseAuthException(
          code: 'unauthenticated',
          message: 'Failed to get authentication token: $e2',
        );
      }
    }
    
    // Longer delay to ensure token propagation on physical devices
    // This is critical - the auth token needs to propagate through Firebase SDK
    await Future.delayed(const Duration(milliseconds: 800));
  }

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
      Logger.info('🚀 ===== CREATING PAYMENT VIA CLOUD FUNCTION =====');
      
      // Ensure user is authenticated and token is fresh
      Logger.info('🔐 Verifying Firebase Auth...');
      await _ensureAuthenticated();
      
      // Verify user is still authenticated after delay
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw FirebaseAuthException(
          code: 'unauthenticated',
          message: 'User authentication lost during token refresh',
        );
      }
      
      Logger.info('📤 Preparing Cloud Function call');
      Logger.info('   Function: createPayment');
      Logger.info('   Region: us-central1');
      Logger.info('   User UID: ${currentUser.uid}');
      Logger.info('   User Email: ${currentUser.email ?? "N/A"}');
      
      // Create a fresh Functions instance for each call to ensure fresh auth context
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable(
        'createPayment',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );
      
      Logger.info('📋 Request payload:');
      Logger.info('   amount: $amount');
      Logger.info('   currency: ${currency.toUpperCase()}');
      Logger.info('   email: $email');
      Logger.info('   firstName: $firstName');
      Logger.info('   lastName: $lastName');
      Logger.info('   phoneNumber: ${phoneNumber ?? "N/A"}');
      Logger.info('   checkoutUrl: ${checkoutUrl ?? "N/A"}');
      Logger.info('   intasendCheckoutId: ${intasendCheckoutId ?? "N/A"}');
      Logger.info('');
      Logger.info('📡 Sending request to Cloud Function...');
      
      final startTime = DateTime.now();
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
      
      final duration = DateTime.now().difference(startTime);
      Logger.success('✅ Cloud Function call completed in ${duration.inMilliseconds}ms');
      
      final data = result.data as Map<String, dynamic>;
      
      // Debug: Log the full response to understand the structure
      Logger.info('📥 Cloud Function response received:');
      Logger.info('   Response keys: ${data.keys.toList()}');
      Logger.debug('   Full response: $data');
      
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
      Logger.error('❌ ===== CLOUD FUNCTION ERROR =====');
      Logger.error('   Error code: ${e.code}');
      Logger.error('   Error message: ${e.message ?? "No message"}');
      Logger.error('   Error details: ${e.details}');
      Logger.error('   Stack trace: ${e.stackTrace}');
      
      // Provide more helpful error messages with diagnostics
      String errorMessage = e.message ?? 'Payment creation failed';
      String diagnosticInfo = '';
      
      if (e.code == 'not-found') {
        errorMessage = 'Payment function not found. Please ensure the Cloud Function "createPayment" is deployed.';
        diagnosticInfo = 'The createPayment Cloud Function may not be deployed. Run: firebase deploy --only functions';
        Logger.warning('⚠️ $diagnosticInfo');
      } else if (e.code == 'unauthenticated') {
        errorMessage = 'Authentication failed. The request was rejected by Firebase.';
        diagnosticInfo = '''
❌ CRITICAL: Firebase Auth token validation failed!

Possible causes:
1. Firebase Auth token missing or invalid
   - Ensure user is logged in
   - Check if auth token refresh succeeded
   - Verify user is authenticated before making the call

2. Token expired or not refreshed
   - Auth tokens expire periodically
   - Ensure token refresh is working correctly

Diagnostic steps:
1. Check if user is logged in
2. Verify Firebase Auth is initialized
3. Check Firebase Console > Functions > Logs for detailed error
4. Try logging out and logging back in
        ''';
        Logger.error(diagnosticInfo);
      } else if (e.code == 'permission-denied') {
        errorMessage = 'Permission denied. You may not have access to create payments.';
        diagnosticInfo = 'Check Firestore security rules and Cloud Function permissions';
        Logger.warning('⚠️ $diagnosticInfo');
      } else if (e.code == 'invalid-argument') {
        errorMessage = 'Invalid payment data: ${e.message ?? "Please check your input"}';
        diagnosticInfo = 'Verify all required fields are provided and valid';
        Logger.warning('⚠️ $diagnosticInfo');
      }
      
      Logger.error('❌ ====================================');
      
      return {
        'success': false,
        'error': errorMessage,
        'code': e.code,
        'diagnostic': diagnosticInfo,
      };
    } catch (e, stackTrace) {
      Logger.error('❌ ===== UNEXPECTED ERROR =====');
      Logger.error('   Error: $e');
      Logger.error('   Stack trace: $stackTrace');
      Logger.error('❌ ============================');
      return {
        'success': false,
        'error': 'Unexpected error: $e',
      };
    }
  }

  /// Handle payment webhook via Cloud Function. Used by the IntaSend flow
  /// (e.g. when the user opens the checkout link or when IntaSend sends
  /// success/failure). See IntaSendService and topup_page.dart.
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

