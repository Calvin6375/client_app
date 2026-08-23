import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pretium/core/constants/cloud_functions_api_config.dart';
import 'package:pretium/core/http/c2b_http_codec.dart';
import 'package:pretium/models/transaction_model.dart';
import 'package:pretium/services/auth_claims_service.dart';
import 'package:pretium/utils/logger.dart';

/// Service for fetching transactions from the Cloud Functions API
///
/// Endpoint: `transactionsApi/transactions`
class TransactionsService {
  final AuthClaimsService _authClaims = AuthClaimsService();
  final C2bHttpCodec _codec = C2bHttpCodec.instance;

  /// Default limit when not specified (matches backend default).
  static const int defaultLimit = 50;

  /// Maximum limit allowed by the transactions API.
  static const int maxLimit = 100;

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
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid transactions API response');
    }
    return decoded;
  }

  /// Get transactions with optional filters and pagination
  Future<TransactionsResponse> getTransactions({
    int? limit,
    String? source,
    String? startAfter,
    String? type,
    String? status,
  }) async {
    try {
      final token = await _authClaims.idTokenForApi();

      final effectiveLimit = limit != null
          ? (limit > maxLimit ? maxLimit : limit)
          : null;

      final queryParams = <String, String>{};
      if (effectiveLimit != null) queryParams['limit'] = effectiveLimit.toString();
      if (source != null) queryParams['source'] = source;
      if (startAfter != null) queryParams['startAfter'] = startAfter;
      if (type != null) queryParams['type'] = type;
      if (status != null) queryParams['status'] = status;

      final uri = CloudFunctionsApiConfig.transactionsUri()
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      Logger.info('Fetching transactions from API: $uri');

      final response = await http.get(uri, headers: await _headers(token));

      if (response.statusCode == 200) {
        final jsonData = await _decodeJson(response);
        Logger.debug(
          'transactionsApi list raw response:\n'
          '${const JsonEncoder.withIndent('  ').convert(jsonData)}',
        );
        final transactionsResponse = TransactionsResponse.fromJson(jsonData);

        Logger.success(
          'Transactions fetched successfully: ${transactionsResponse.transactions.length} transactions',
        );

        return transactionsResponse;
      } else {
        Logger.error(
          'Failed to fetch transactions',
          Exception('HTTP ${response.statusCode}'),
        );
        throw Exception('Failed to fetch transactions: HTTP ${response.statusCode}');
      }
    } catch (e) {
      Logger.error('Error fetching transactions', e);
      rethrow;
    }
  }

  /// Get all transactions (first page)
  Future<TransactionsResponse> getAllTransactions({int limit = 50, String? startAfter}) {
    return getTransactions(limit: limit, startAfter: startAfter);
  }

  /// Get only credit transactions
  Future<TransactionsResponse> getCreditTransactions({
    int limit = 50,
    String? startAfter,
  }) {
    return getTransactions(type: 'credit', limit: limit, startAfter: startAfter);
  }

  /// Get only debit transactions
  Future<TransactionsResponse> getDebitTransactions({
    int limit = 50,
    String? startAfter,
  }) {
    return getTransactions(type: 'debit', limit: limit, startAfter: startAfter);
  }

  /// Get pending transactions
  Future<TransactionsResponse> getPendingTransactions({
    int limit = 50,
    String? startAfter,
  }) {
    return getTransactions(status: 'pending', limit: limit, startAfter: startAfter);
  }

  /// Get completed transactions
  Future<TransactionsResponse> getCompletedTransactions({
    int limit = 50,
    String? startAfter,
  }) {
    return getTransactions(status: 'completed', limit: limit, startAfter: startAfter);
  }

  /// Get transactions from Firestore only
  Future<TransactionsResponse> getFirestoreTransactions({
    int limit = 50,
    String? startAfter,
  }) {
    return getTransactions(
      source: 'firestore',
      limit: limit,
      startAfter: startAfter,
    );
  }

  /// Fetch a single transaction by ID.
  Future<Transaction> getTransaction(String transactionId) async {
    try {
      final token = await _authClaims.idTokenForApi();
      final uri = CloudFunctionsApiConfig.transactionUri(transactionId);

      Logger.info('Fetching transaction from API: $uri');

      final response = await http.get(uri, headers: await _headers(token));

      if (response.statusCode == 200) {
        final jsonData = await _decodeJson(response);
        Logger.debug(
          'transactionsApi single raw response ($transactionId):\n'
          '${const JsonEncoder.withIndent('  ').convert(jsonData)}',
        );
        final data = jsonData['data'] as Map<String, dynamic>? ?? jsonData;
        return Transaction.fromJson(data);
      }

      Logger.error(
        'Failed to fetch transaction $transactionId',
        Exception('HTTP ${response.statusCode}'),
      );
      throw Exception('Failed to fetch transaction: HTTP ${response.statusCode}');
    } catch (e) {
      Logger.error('Error fetching transaction', e);
      rethrow;
    }
  }
}
