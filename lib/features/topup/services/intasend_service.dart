import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
  Future<bool> launchCheckout(String checkoutUrl) async {
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
      return checkoutResult;
    }

    // Step 2: Launch checkout URL
    final checkoutUrl = checkoutResult['checkout_url'];
    if (checkoutUrl != null) {
      final launched = await launchCheckout(checkoutUrl);
      
      if (launched) {
        return {
          'success': true,
          'message': 'Checkout launched successfully',
          'checkout_url': checkoutUrl,
          'data': checkoutResult['data'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to launch checkout URL',
          'checkout_url': checkoutUrl,
        };
      }
    }

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