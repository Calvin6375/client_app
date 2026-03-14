import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:pretium/utils/logger.dart';

/// TransFi Payment API service (standalone from IntaSend).
/// Creates payment invoices via POST /checkout/payment-link/invoice with
/// HMAC-SHA256 signature (method + path + timestamp + body).
class TransFiService {
  static const String defaultBaseUrl = 'https://checkout-server.transfi.com';
  /// Optional base URL for the checkout widget (to open invoice in browser).
  static const String defaultCheckoutWidgetUrl = 'https://checkout-widget.transfi.com';

  final String publicKey;
  final String secretKey;
  final String baseUrl;
  final String checkoutWidgetBaseUrl;

  TransFiService({
    required this.publicKey,
    required this.secretKey,
    this.baseUrl = defaultBaseUrl,
    this.checkoutWidgetBaseUrl = defaultCheckoutWidgetUrl,
  });

  static const String _path = '/checkout/payment-link/invoice';
  static const String _method = 'POST';

  /// Builds HMAC-SHA256 signature: METHOD + PATH + TIMESTAMP + BODY (JSON string, no spaces).
  String _computeSignature(String timestamp, String bodyJson) {
    final signingMessage = _method + _path + timestamp + bodyJson;
    final key = utf8.encode(secretKey);
    final message = utf8.encode(signingMessage);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(message);
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Creates a payment invoice via TransFi API.
  /// Returns map with success, invoiceId, optional invoiceUrl/checkout_url, and error if failed.
  Future<Map<String, dynamic>> createPaymentInvoice({
    required String paymentLinkId,
    required double amount,
    required String currency,
    required String email,
    required String firstName,
    required String lastName,
    String? phone,
    String? phoneCode,
    String? country,
    String? city,
    String? state,
    String? street,
    String? postalCode,
    String? productName,
    String? productDescription,
    String? imageUrl,
    String? successRedirectUrl,
    String? failureRedirectUrl,
    String? customerOrderId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final body = <String, dynamic>{
      'paymentLinkId': paymentLinkId,
      'amount': amount.toStringAsFixed(0),
      'currency': currency.toUpperCase(),
      'productDetails': {
        'name': productName ?? 'Wallet Top Up',
        'description': productDescription ?? 'Top up your wallet',
        'imageUrl': imageUrl ?? '',
      },
      'individual': {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone ?? '',
        'phoneCode': phoneCode ?? '+1',
        'country': country ?? 'US',
        'email': email,
        'address': {
          'city': city ?? '',
          'state': state ?? '',
          'street': street ?? '',
          'postalCode': postalCode ?? '',
        },
      },
      'successRedirectUrl': successRedirectUrl ?? '$checkoutWidgetBaseUrl/checkout/payment-processing',
      'failureRedirectUrl': failureRedirectUrl ?? '$checkoutWidgetBaseUrl/checkout/payment-processing',
      'customerOrderId': customerOrderId ?? 'order-${DateTime.now().millisecondsSinceEpoch}',
    };
    final bodyJson = json.encode(body);
    final signature = _computeSignature(timestamp, bodyJson);

    final url = Uri.parse('$baseUrl$_path');
    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': publicKey,
      'x-timestamp': timestamp,
      'x-signature': signature,
      'X-Api-Version': 'v1',
    };

    Logger.debug('TransFi API Request: $url');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: bodyJson,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        Logger.debug('TransFi API Response: ${response.body}');
        final success = data['success'] == true;
        // API may return invoice in data wrapper or at top level
        final responseData = data['data'] as Map<String, dynamic>? ?? data;
        final invoiceId = responseData['invoiceId']?.toString() ??
            responseData['id']?.toString() ??
            data['invoiceId']?.toString() ??
            data['id']?.toString();
        final amountStr = responseData['amount']?.toString();
        final status = responseData['status']?.toString();

        String? checkoutUrl;
        for (final key in ['invoiceUrl', 'checkoutUrl', 'paymentUrl', 'url']) {
          final v = responseData[key];
          if (v is String && v.isNotEmpty) {
            checkoutUrl = v;
            break;
          }
        }
        if (checkoutUrl == null && invoiceId != null && invoiceId.isNotEmpty) {
          checkoutUrl = '$checkoutWidgetBaseUrl/checkout/invoice/$invoiceId';
        }

        // If we have no way to open checkout, treat as failure so caller can show a clear message
        final effectiveSuccess = success && (checkoutUrl != null && checkoutUrl.isNotEmpty || (invoiceId != null && invoiceId.isNotEmpty));
        if (!effectiveSuccess && success) {
          Logger.warning('TransFi returned success but no invoiceId or checkout URL. Raw response logged above.');
        }
        Logger.success('TransFi invoice created: $invoiceId');

        return {
          'success': effectiveSuccess,
          'invoiceId': invoiceId,
          'checkout_url': checkoutUrl,
          'amount': amountStr,
          'status': status,
          'data': responseData,
        };
      } else {
        Logger.error('TransFi API Error: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Failed to create invoice: ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      Logger.error('TransFi network exception', e);
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Creates invoice and launches checkout URL in browser if available.
  Future<Map<String, dynamic>> createAndLaunchCheckout({
    required String paymentLinkId,
    required double amount,
    required String currency,
    required String email,
    required String firstName,
    required String lastName,
    String? phone,
    String? phoneCode,
    String? country,
    String? city,
    String? state,
    String? street,
    String? postalCode,
    String? successRedirectUrl,
    String? failureRedirectUrl,
    String? customerOrderId,
  }) async {
    final result = await createPaymentInvoice(
      paymentLinkId: paymentLinkId,
      amount: amount,
      currency: currency,
      email: email,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      phoneCode: phoneCode,
      country: country,
      city: city,
      state: state,
      street: street,
      postalCode: postalCode,
      successRedirectUrl: successRedirectUrl,
      failureRedirectUrl: failureRedirectUrl,
      customerOrderId: customerOrderId,
    );

    if (!result['success']) return result;

    final checkoutUrl = result['checkout_url'] as String?;
    if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
      final uri = Uri.parse(checkoutUrl);
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        result['launched'] = launched;
      } catch (e) {
        Logger.warning('TransFi launch failed', e);
        result['launched'] = false;
      }
    } else {
      result['launched'] = false;
    }
    return result;
  }
}
