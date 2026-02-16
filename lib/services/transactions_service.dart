import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretium/models/transaction_model.dart';
import 'package:pretium/utils/logger.dart';

/// Service for fetching transactions from the Cloud Functions API
/// 
/// Endpoint: https://us-central1-truepay-72060.cloudfunctions.net/transactionsApi/transactions
class TransactionsService {
  static const String _baseUrl = 
      'https://us-central1-truepay-72060.cloudfunctions.net/transactionsApi/transactions';

  /// Default limit when not specified (matches backend default).
  static const int defaultLimit = 50;

  /// Maximum limit allowed by the transactions API.
  static const int maxLimit = 100;

  /// Get transactions with optional filters and pagination
  /// 
  /// Parameters:
  /// - [limit]: Number of results (default: 50, max: 100). Capped at [maxLimit] on the frontend.
  /// - [source]: "firestore", "realtime", or "both" (default: "both")
  /// - [startAfter]: Transaction ID for pagination
  /// - [type]: Filter by type: "credit", "debit", etc.
  /// - [status]: Filter by status: "completed", "pending", "failed"
  /// 
  /// Example:
  /// ```dart
  /// // Get first 50 transactions
  /// final response = await TransactionsService().getTransactions(limit: 50);
  /// 
  /// // Get only credits
  /// final credits = await TransactionsService().getTransactions(type: 'credit');
  /// 
  /// // Pagination
  /// final nextPage = await TransactionsService().getTransactions(
  ///   limit: 50,
  ///   startAfter: 'tx_previous_id',
  /// );
  /// ```
  Future<TransactionsResponse> getTransactions({
    int? limit,
    String? source,
    String? startAfter,
    String? type,
    String? status,
  }) async {
    try {
      // Get Firebase Auth token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final token = await user.getIdToken();
      if (token == null || token.isEmpty) {
        throw Exception('Failed to get authentication token');
      }

      // Cap limit to API maximum
      final effectiveLimit = limit != null
          ? (limit > maxLimit ? maxLimit : limit)
          : null;

      // Build query parameters
      final queryParams = <String, String>{};
      if (effectiveLimit != null) queryParams['limit'] = effectiveLimit.toString();
      if (source != null) queryParams['source'] = source;
      if (startAfter != null) queryParams['startAfter'] = startAfter;
      if (type != null) queryParams['type'] = type;
      if (status != null) queryParams['status'] = status;

      // Build URI
      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      Logger.info('Fetching transactions from API: $uri');

      // Make GET request
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final transactionsResponse = TransactionsResponse.fromJson(jsonData);
        
        Logger.success(
          'Transactions fetched successfully: ${transactionsResponse.transactions.length} transactions',
        );
        
        return transactionsResponse;
      } else {
        Logger.error(
          'Failed to fetch transactions',
          Exception('HTTP ${response.statusCode}: ${response.body}'),
        );
        throw Exception('Failed to fetch transactions: HTTP ${response.statusCode}');
      }
    } catch (e) {
      Logger.error('Error fetching transactions', e);
      rethrow;
    }
  }

  /// Get all transactions (first page)
  Future<TransactionsResponse> getAllTransactions({int limit = 50}) {
    return getTransactions(limit: limit);
  }

  /// Get only credit transactions
  Future<TransactionsResponse> getCreditTransactions({int limit = 50}) {
    return getTransactions(type: 'credit', limit: limit);
  }

  /// Get only debit transactions
  Future<TransactionsResponse> getDebitTransactions({int limit = 50}) {
    return getTransactions(type: 'debit', limit: limit);
  }

  /// Get pending transactions
  Future<TransactionsResponse> getPendingTransactions({int limit = 50}) {
    return getTransactions(status: 'pending', limit: limit);
  }

  /// Get completed transactions
  Future<TransactionsResponse> getCompletedTransactions({int limit = 50}) {
    return getTransactions(status: 'completed', limit: limit);
  }

  /// Get transactions from Firestore only
  Future<TransactionsResponse> getFirestoreTransactions({int limit = 50}) {
    return getTransactions(source: 'firestore', limit: limit);
  }
}
