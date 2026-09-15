import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:pretium/core/constants/cloud_functions_api_config.dart';
import 'package:pretium/core/http/c2b_http_codec.dart';
import 'package:pretium/features/crypto/models/crypto_transaction.dart';
import 'package:pretium/features/crypto/models/crypto_wallet_info.dart';
import 'package:pretium/features/crypto/models/crypto_wallet_status.dart';
import 'package:pretium/features/crypto/models/deposit_watch_result.dart';
import 'package:pretium/services/auth_claims_service.dart';
import 'package:pretium/utils/logger.dart';

class CryptoApiException implements Exception {
  CryptoApiException(this.statusCode, this.message);
  final int statusCode;
  final String? message;

  @override
  String toString() => 'CryptoApiException($statusCode): $message';
}

/// HTTP client for `cryptoApi` Cloud Function (USDC ledger + Turnkey deposit watch).
final class CryptoApiService {
  CryptoApiService({http.Client? httpClient, AuthClaimsService? authClaims})
      : _http = httpClient ?? http.Client(),
        _authClaims = authClaims ?? AuthClaimsService();

  final http.Client _http;
  final AuthClaimsService _authClaims;
  final C2bHttpCodec _codec = C2bHttpCodec.instance;

  Future<String> _requireIdToken({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        final user = FirebaseAuth.instance.currentUser;
        await user?.getIdToken(true);
      }
      return await _authClaims.idTokenForApi(forceRefreshIfStale: !forceRefresh);
    } on FirebaseAuthException {
      throw CryptoApiException(401, 'Not signed in');
    }
  }

  Future<Map<String, String>> _headers({String? idempotencyKey}) async {
    final headers = await _codec.mergeHeaders({
      'Authorization': 'Bearer ${await _requireIdToken()}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    });
    if (idempotencyKey != null) {
      headers['X-Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  Future<Map<String, dynamic>> _decodeResponse(http.Response response) async {
    Map<String, dynamic> body;
    try {
      final plainBody = await _codec.plainResponseBody(response);
      final decoded = jsonDecode(plainBody);
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

  /// Circle wallet path — do **not** use for USDC top-up (can still return Circle).
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

  Map<String, dynamic> _payloadMap(Map<String, dynamic> body) {
    if (body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return body;
  }

  /// Read-only. Never creates a Fuji or mainnet wallet. uid from the token.
  Future<CryptoWalletStatus> getWalletStatus() async {
    Logger.info('CryptoApiService GET /crypto/wallet/status');
    final response = await _http.get(
      CloudFunctionsApiConfig.cryptoWalletStatusUri(),
      headers: await _headers(),
    );
    final body = await _decodeResponse(response);
    return CryptoWalletStatus.fromJson(_payloadMap(body));
  }

  /// Creates the production (mainnet) USDC address. Do not send `userId`.
  Future<void> createProductionWallet() async {
    Logger.info('CryptoApiService POST /crypto/wallet/production');
    final response = await _http.post(
      CloudFunctionsApiConfig.cryptoWalletProductionUri(),
      headers: await _headers(),
      body: await _codec.encodeJsonBody('{}'),
    );
    if (response.statusCode == 401) {
      throw CryptoApiException(401, 'Unauthorized');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      Map<String, dynamic> body = {};
      try {
        final plain = await _codec.plainResponseBody(response);
        final decoded = jsonDecode(plain);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {}
      throw CryptoApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Failed to create production wallet',
      );
    }
  }

  /// GET /crypto/wallet/status, then POST /crypto/wallet/production only if
  /// [CryptoWalletStatus.shouldCreateMainnet] (not [CryptoWalletStatus.onTestnet]).
  Future<CryptoWalletStatus> ensureProductionWallet() async {
    var status = await getWalletStatus();
    if (status.shouldCreateMainnet) {
      await createProductionWallet();
      status = await getWalletStatus();
    }
    return status;
  }

  /// Status first; create mainnet only when [CryptoWalletStatus.shouldCreateMainnet].
  /// Then watch that production address.
  Future<DepositWatchResult> prepareUsdcTopUp() async {
    final status = await ensureProductionWallet();
    return startUsdcDepositWatch(network: status.preferredWatchNetwork);
  }

  /// Starts (or resumes) backend deposit monitoring. Same address is reused.
  /// Auth uid is taken from the Firebase token — do not send `userId`.
  Future<DepositWatchResult> startUsdcDepositWatch({
    String network = 'avalanche-fuji',
  }) async {
    Logger.info('CryptoApiService POST /crypto/deposit/watch network=$network');
    final payload = jsonEncode({
      'asset': 'USDC',
      'network': network,
    });
    final response = await _http.post(
      CloudFunctionsApiConfig.cryptoDepositWatchUri(),
      headers: await _headers(),
      body: await _codec.encodeJsonBody(payload),
    );
    final body = await _decodeResponse(response);
    final payloadMap = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body;
    return DepositWatchResult.fromJson(payloadMap);
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
}
