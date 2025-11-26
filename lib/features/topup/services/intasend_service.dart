import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:pretium/services/payment_service.dart';
import 'package:pretium/utils/logger.dart';

/// Custom IntaSend service using HTTP API calls
/// This replaces the problematic intasend_flutter plugin
class IntaSendService {
  static const String _baseUrlTest = 'https://sandbox.intasend.com/api/v1';
  static const String _baseUrlLive = 'https://payment.intasend.com/api/v1';

  final String publicKey;
  final bool isTestMode;

  IntaSendService({
    required this.publicKey,
    this.isTestMode = true,
  });

  String get _baseUrl => isTestMode ? _baseUrlTest : _baseUrlLive;

  // NOTE: Wallet balance fetching has been moved to WalletRepository
  // Use WalletRepository.streamWalletBalance() or getWalletBalance() instead


  /// Create a checkout session using IntaSend API
  Future<Map<String, dynamic>> createCheckout({
    required double amount,
    required String email,
    required String currency,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    Map<String, dynamic>? metadata,
  }) async {
    final url = Uri.parse('$_baseUrl/checkout/');
    
    final body = {
      'public_key': publicKey,
      'amount': amount,
      'currency': currency.toUpperCase(),
      'email': email,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (metadata != null) 'metadata': metadata,
    };

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final requestBody = json.encode(body);

    // Log request details
    Logger.debug('IntaSend API Request: $url');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final checkoutUrl = responseData['url'] ?? responseData['checkout_url'];
        
        Logger.success('IntaSend checkout created: $checkoutUrl');
        
        return {
          'success': true,
          'data': responseData,
          'checkout_url': checkoutUrl,
        };
      } else {
        Logger.error('IntaSend API Error: ${response.statusCode}');
        
        return {
          'success': false,
          'error': 'Failed to create checkout: ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      Logger.error('Network Exception in IntaSend', e);
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Launch the checkout URL in browser
  Future<bool> launchCheckout(String checkoutUrl, {String? paymentId}) async {
    Logger.debug('Launching checkout URL: $checkoutUrl');
    
    final uri = Uri.parse(checkoutUrl);
    
    try {
      final canLaunch = await canLaunchUrl(uri);
      
      if (canLaunch) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        // Update payment status via Cloud Function if payment ID is provided
        if (launched && paymentId != null) {
          final paymentService = PaymentService();
          await paymentService.handlePaymentWebhook(
            paymentId: paymentId,
            status: 'link_opened',
            webhookData: {
              'launch_method': 'manual_retry',
              'user_agent': 'mobile_app',
            },
          );
        }
        
        return launched;
      } else {
        // Try alternative launch modes
        try {
          return await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (e2) {
          Logger.warning('Platform default launch failed', e2);
          try {
            return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          } catch (e3) {
            Logger.warning('In-app browser launch failed', e3);
          }
        }
      }
    } catch (e) {
      Logger.error('Launch exception', e);
    }
    
    return false;
  }

  /// Complete payment flow - create checkout and launch URL
  /// Uses Cloud Functions for payment creation (secure server-side)
  Future<Map<String, dynamic>> processPayment({
    required double amount,
    required String email,
    required String currency,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    Map<String, dynamic>? metadata,
  }) async {
    final paymentService = PaymentService();
    
    // Step 1: Create IntaSend checkout session
    Logger.info('Creating IntaSend checkout session');
    final checkoutResult = await createCheckout(
      amount: amount,
      email: email,
      currency: currency,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      metadata: metadata,
    );

    if (!checkoutResult['success']) {
      Logger.error('IntaSend checkout creation failed');
      return checkoutResult;
    }

    final checkoutUrl = checkoutResult['checkout_url'];
    final responseData = checkoutResult['data'];
    
    // Extract IntaSend checkout ID from response
    String intaSendCheckoutId = '';
    if (responseData != null) {
      intaSendCheckoutId = responseData['id']?.toString() ?? 
                          responseData['checkout_id']?.toString() ??
                          responseData['reference']?.toString() ?? 
                          'unknown';
    }
    
    if (checkoutUrl != null) {
      // Step 2: Create payment via Cloud Function (server-side)
      Logger.info('Creating payment via Cloud Function');
      final paymentResult = await paymentService.createPayment(
        amount: amount,
        currency: currency,
        email: email,
        firstName: firstName ?? '',
        lastName: lastName ?? '',
        phoneNumber: phoneNumber,
        checkoutUrl: checkoutUrl,
        intasendCheckoutId: intaSendCheckoutId,
        metadata: {
          'intasend_response': responseData,
          'test_mode': isTestMode,
          if (metadata != null) ...metadata,
        },
      );
      
      if (!paymentResult['success']) {
        Logger.error('Payment creation failed: ${paymentResult['error']}');
        return {
          'success': false,
          'error': paymentResult['error'] ?? 'Failed to create payment',
          'checkout_url': checkoutUrl,
        };
      }
      
      final paymentId = paymentResult['paymentId'] as String;
      Logger.success('Payment created: $paymentId');
      
      // Step 3: Launch checkout URL
      final launched = await launchCheckout(checkoutUrl, paymentId: paymentId);
      
      if (launched) {
        // Step 4: Mark payment link as opened via Cloud Function
        Logger.info('Marking payment link as opened');
        await paymentService.handlePaymentWebhook(
          paymentId: paymentId,
          status: 'link_opened',
          webhookData: {
            'launch_method': 'automatic',
            'user_agent': 'mobile_app',
          },
        );
        
        return {
          'success': true,
          'message': 'Checkout launched successfully',
          'checkout_url': checkoutUrl,
          'payment_id': paymentId,
          'data': checkoutResult['data'],
        };
      } else {
        // Even if launch failed, we still have a valid checkout URL
        Logger.warning('Launch failed, but checkout URL is available');
        
        return {
          'success': true, // Still success because checkout was created
          'message': 'Checkout URL created (manual launch required)',
          'checkout_url': checkoutUrl,
          'payment_id': paymentId,
          'launch_failed': true,
          'data': checkoutResult['data'],
        };
      }
    }

    Logger.error('No checkout URL received from IntaSend');
    return {
      'success': false,
      'error': 'No checkout URL received from IntaSend',
    };
  }

  /// Check payment status (for webhook verification)
  Future<Map<String, dynamic>> checkPaymentStatus(String checkoutId) async {
    final url = Uri.parse('$_baseUrl/checkout/$checkoutId/');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $publicKey',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to check status: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}