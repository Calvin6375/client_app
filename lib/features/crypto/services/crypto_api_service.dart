import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:pretium/core/constants/cloud_functions_api_config.dart';
import 'package:pretium/features/crypto/models/crypto_send_result.dart';
import 'package:pretium/features/crypto/models/crypto_transaction.dart';
import 'package:pretium/features/crypto/models/crypto_wallet_info.dart';
import 'package:pretium/utils/logger.dart';

class CryptoApiException implements Exception {
  CryptoApiException(this.statusCode, this.message);
  final int statusCode;
  final String? message;

  @override
  String toString() => 'CryptoApiException($statusCode): $message';
}

/// HTTP client for Circle USDC endpoints (`cryptoApi` Cloud Function).
final class CryptoApiService {
  CryptoApiService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<String> _requireIdToken({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw CryptoApiException(401, 'Not signed in');
    }
    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw CryptoApiException(401, 'Missing ID token');
    }
    return token;
  }

  Future<Map<String, String>> _headers({String? idempotencyKey}) async {
    final headers = {
      'Authorization': 'Bearer ${await _requireIdToken()}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (idempotencyKey != null) {
      headers['X-Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  Future<Map<String, dynamic>> _decodeResponse(http.Response response) async {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      body = {};
    }

    if (response.statusCode == 401) {
      throw CryptoApiException(401, body['error']?.toString() ?? 'Unauthorized');
    }

    if (response.statusCode != 200 || body['success'] != true) {
      throw CryptoApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Request failed',
      );
    }

    return body;
  }

  Future<CryptoWalletInfo> getWallet() async {
    Logger.info('CryptoApiService GET /crypto/wallet');
    final response = await _http.get(
      CloudFunctionsApiConfig.cryptoWalletUri(),
      headers: await _headers(),
    );
    final body = await _decodeResponse(response);
    return CryptoWalletInfo.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  Future<double> getBalance() async {
    Logger.info('CryptoApiService GET /crypto/balance');
    final response = await _http.get(
      CloudFunctionsApiConfig.cryptoBalanceUri(),
      headers: await _headers(),
    );
    final body = await _decodeResponse(response);
    final data = Map<String, dynamic>.from(body['data'] as Map);
    return (data['USDC'] as num?)?.toDouble() ?? 0;
  }

  Future<List<CryptoTransaction>> getTransactions({int limit = 50}) async {
    Logger.info('CryptoApiService GET /crypto/transactions?limit=$limit');
    final response = await _http.get(
      CloudFunctionsApiConfig.cryptoTransactionsUri(limit: limit),
      headers: await _headers(),
    );
    final body = await _decodeResponse(response);
    final data = Map<String, dynamic>.from(body['data'] as Map);
    final list = data['transactions'] as List<dynamic>? ?? [];
    return list
        .map((e) => CryptoTransaction.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CryptoSendResult> sendUsdc({
    required String toAddress,
    required double amount,
    required String idempotencyKey,
  }) async {
    Logger.info('CryptoApiService POST /crypto/send amount=$amount');
    final response = await _http.post(
      CloudFunctionsApiConfig.cryptoSendUri(),
      headers: await _headers(idempotencyKey: idempotencyKey),
      body: jsonEncode({'toAddress': toAddress, 'amount': amount}),
    );
    final body = await _decodeResponse(response);
    return CryptoSendResult.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }
}
