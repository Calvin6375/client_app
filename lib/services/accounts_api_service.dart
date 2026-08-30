import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pretium/core/constants/cloud_functions_api_config.dart';
import 'package:pretium/core/http/c2b_http_codec.dart';
import 'package:pretium/models/user_accounts.dart';
import 'package:pretium/services/auth_claims_service.dart';
import 'package:pretium/utils/logger.dart';

/// Authenticated client for `GET /api/accounts` (alias `/api/wallets`).
///
/// Uses the same App Check + C2B encryption middleware as other `functions:api`
/// customer routes. UID is taken from the Firebase ID token — never pass another
/// user's id.
class AccountsApiService {
  AccountsApiService({
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
      throw Exception('Invalid accounts API response');
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// Fetches fiat + crypto balances for the signed-in user.
  Future<UserAccounts> fetchAccounts() async {
    final token = await _authClaims.idTokenForApi();
    final uri = CloudFunctionsApiConfig.accountsUri();

    Logger.info('AccountsApiService GET /api/accounts');

    final response = await _http.get(uri, headers: await _headers(token));
    final body = await _decodeJson(response);

    if (response.statusCode != 200 || body['success'] != true) {
      final error = body['error']?.toString() ?? 'Failed to load accounts';
      Logger.error(
        'AccountsApiService failed: HTTP ${response.statusCode} $error',
      );
      throw Exception(error);
    }

    final dataRaw = body['data'];
    if (dataRaw is! Map) {
      throw Exception('Invalid accounts API data');
    }

    final accounts = UserAccounts.fromJson(Map<String, dynamic>.from(dataRaw));
    Logger.success(
      'Accounts loaded: fiat=${accounts.fiatWallets.keys.join(',')} '
      'crypto=${accounts.cryptoWallets.keys.join(',')}',
    );
    return accounts;
  }
}
