import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:pretium/models/wallet_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pretium/services/firebase_payment_service.dart';

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

  /// Fetch latest wallet balance for a given userId from backend
  /// Returns a default wallet with 0.00 balance if no data exists
  Future<Wallet> fetchWalletBalance(String userId) async {
    final authUserId = FirebaseAuth.instance.currentUser!.uid;
    print('📡 Reading wallet balance for auth user: $authUserId (param: $userId)');

    try {
      // Match the database rules structure: wallet/{userId}/balance
      final balanceRef = FirebaseDatabase.instance.ref().child('wallet/$authUserId/balance');
      final snapshot = await balanceRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        print('✅ Wallet balance snapshot: $data');
        return Wallet.fromJson(data);
      }

      // Return default wallet if no data exists (wallet not initialized yet)
      print('ℹ️ No wallet balance data for user: $authUserId - returning default wallet');
      return Wallet(currencyCode: 'KES', balance: 0.0);
    } catch (e) {
      // On permission errors or other exceptions, return default wallet
      print('⚠️ Error fetching wallet balance: $e - returning default wallet');
      return Wallet(currencyCode: 'KES', balance: 0.0);
    }
  }


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
    print('📡 IntaSend API Request:');
    print('  URL: $url');
    print('  Method: POST');
    print('  Headers: $headers');
    print('  Body: $requestBody');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: requestBody,
      );

      // Log response details
      print('📨 IntaSend API Response:');
      print('  Status Code: ${response.statusCode}');
      print('  Headers: ${response.headers}');
      print('  Raw Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final checkoutUrl = responseData['url'] ?? responseData['checkout_url'];
        
        print('✅ Checkout created successfully:');
        print('  Checkout URL: $checkoutUrl');
        print('  Response Data: $responseData');
        
        return {
          'success': true,
          'data': responseData,
          'checkout_url': checkoutUrl,
        };
      } else {
        print('❌ IntaSend API Error:');
        print('  Status: ${response.statusCode}');
        print('  Body: ${response.body}');
        
        return {
          'success': false,
          'error': 'Failed to create checkout: ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      print('🚨 Network Exception: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Launch the checkout URL in browser
  Future<bool> launchCheckout(String checkoutUrl, {String? paymentId}) async {
    print('🚀 Attempting to launch checkout URL: $checkoutUrl');
    
    final uri = Uri.parse(checkoutUrl);
    print('  Parsed URI: $uri');
    print('  URI scheme: ${uri.scheme}');
    print('  URI host: ${uri.host}');
    
    try {
      final canLaunch = await canLaunchUrl(uri);
      print('  Can launch URL: $canLaunch');
      
      if (canLaunch) {
        print('  Launching with LaunchMode.externalApplication...');
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        print('  Launch result: $launched');
        
        // Update Firebase if payment ID is provided and launch was successful
        if (launched && paymentId != null) {
          await FirebasePaymentService.markPaymentLinkOpened(
            paymentId: paymentId,
            additionalData: {
              'launch_method': 'manual_retry',
              'user_agent': 'mobile_app',
            },
          );
        }
        
        return launched;
      } else {
        print('  ❌ Cannot launch URL - trying alternative modes...');
        
        // Try with different launch modes
        try {
          print('  Trying LaunchMode.platformDefault...');
          final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          print('  Platform default launch result: $launched');
          return launched;
        } catch (e2) {
          print('  🚨 Platform default failed: $e2');
          
          try {
            print('  Trying LaunchMode.inAppBrowserView...');
            final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
            print('  In-app browser launch result: $launched');
            return launched;
          } catch (e3) {
            print('  🚨 In-app browser failed: $e3');
          }
        }
      }
    } catch (e) {
      print('  🚨 Launch exception: $e');
    }
    
    print('  ❌ All launch attempts failed');
    return false;
  }

  /// Complete payment flow - create checkout and launch URL
  Future<Map<String, dynamic>> processPayment({
    required double amount,
    required String email,
    required String currency,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    Map<String, dynamic>? metadata,
  }) async {
    // Generate unique payment ID
    final paymentId = FirebasePaymentService.generatePaymentId();
    print('🆔 Generated Payment ID: $paymentId');
    
    // Step 1: Create checkout session
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
      // Store failed payment initiation
      await FirebasePaymentService.markPaymentFailed(
        paymentId: paymentId,
        errorReason: 'Checkout creation failed',
        errorDetails: checkoutResult,
      );
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
      // Step 2: Store payment initiation in Firebase
      print('💾 Storing payment initiation in Firebase...');
      final storeResult = await FirebasePaymentService.storePaymentInitiation(
        paymentId: paymentId,
        amount: amount,
        currency: currency,
        email: email,
        firstName: firstName ?? '',
        lastName: lastName ?? '',
        checkoutUrl: checkoutUrl,
        intaSendCheckoutId: intaSendCheckoutId,
        additionalData: {
          'phone_number': phoneNumber,
          'intasend_response': responseData,
          'test_mode': isTestMode,
          if (metadata != null) 'custom_metadata': metadata,
        },
      );
      
      if (storeResult['success']) {
        print('✅ Payment data stored successfully in Firebase');
      } else {
        print('⚠️ Warning: Failed to store payment data: ${storeResult['error']}');
      }
      
      // Step 3: Launch checkout URL
      final launched = await launchCheckout(checkoutUrl);
      
      if (launched) {
        // Step 4: Mark payment link as opened in Firebase
        print('🔗 Updating payment status to "link_opened" in Firebase...');
        await FirebasePaymentService.markPaymentLinkOpened(
          paymentId: paymentId,
          additionalData: {
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
        // User can copy and open manually
        print('⚠️ Launch failed, but checkout URL is available for manual use');
        
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

    // No checkout URL received - mark as failed
    await FirebasePaymentService.markPaymentFailed(
      paymentId: paymentId,
      errorReason: 'No checkout URL received from IntaSend',
      errorDetails: checkoutResult,
    );
    
    return {
      'success': false,
      'error': 'No checkout URL received from IntaSend',
      'payment_id': paymentId,
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