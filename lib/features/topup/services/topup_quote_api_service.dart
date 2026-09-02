import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pretium/core/constants/cloud_functions_api_config.dart';
import 'package:pretium/core/http/c2b_http_codec.dart';
import 'package:pretium/features/topup/models/topup_quote.dart';
import 'package:pretium/services/auth_claims_service.dart';
import 'package:pretium/utils/logger.dart';

class TopupQuoteApiException implements Exception {
  TopupQuoteApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'TopupQuoteApiException($statusCode): $message';
}

/// Authenticated client for `POST /api/funding/topup/quote`.
///
/// Quote only — does not create a payment. Uses the same App Check + C2B
/// encryption middleware as other `functions:api` customer routes.
class TopupQuoteApiService {
  TopupQuoteApiService({
    http.Client? httpClient,
    AuthClaimsService? authClaims,
  })  : _http = httpClient ?? http.Client(),
        _authClaims = authClaims ?? AuthClaimsService();

  final http.Client _http;
  final AuthClaimsService _authClaims;
  final C2bHttpCodec _codec = C2bHttpCodec.instance;

  Future<Map<String, String>> _headers(String token) {
    return _codec.mergeHeaders({
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    });
  }

  Future<Map<String, dynamic>> _decodeJson(http.Response response) async {
    final plainBody = await _codec.plainResponseBody(response);
    final decoded = json.decode(plainBody);
    if (decoded is! Map) {
      throw TopupQuoteApiException(
        response.statusCode,
        'Invalid topup quote response',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// Fetches a deposit quote for [amount] / [currency].
  Future<TopupQuote> fetchQuote({
    required double amount,
    required String currency,
  }) async {
    final token = await _authClaims.idTokenForApi();
    final uri = CloudFunctionsApiConfig.fundingTopupQuoteUri();
    final payload = <String, dynamic>{
      'amount': amount,
      'currency': currency.trim().toUpperCase(),
    };

    Logger.info(
      'TopupQuoteApiService POST /funding/topup/quote '
      'amount=${payload['amount']} currency=${payload['currency']}',
    );

    final response = await _http.post(
      uri,
      headers: await _headers(token),
      body: await _codec.encodeJsonBody(jsonEncode(payload)),
    );
    final body = await _decodeJson(response);

    if (response.statusCode != 200 || body['success'] != true) {
      final error = body['error']?.toString() ?? 'Failed to load deposit quote';
      Logger.error(
        'TopupQuoteApiService failed: HTTP ${response.statusCode} $error',
      );
      throw TopupQuoteApiException(response.statusCode, error);
    }

    final dataRaw = body['data'];
    if (dataRaw is! Map) {
      throw TopupQuoteApiException(
        response.statusCode,
        'Invalid topup quote data',
      );
    }

    final data = Map<String, dynamic>.from(dataRaw);
    // Prefer request currency/amount when the API omits them on flat fields.
    data.putIfAbsent('currency', () => currency.trim().toUpperCase());
    data.putIfAbsent('amount', () => amount);

    final quote = TopupQuote.fromJson(data);
    Logger.success(
      'Topup quote loaded: deposit=${quote.youDeposit} '
      'fees=${quote.processingFees} pay=${quote.youWillPay} '
      'provider=${quote.checkoutProvider}',
    );
    return quote;
  }
}
