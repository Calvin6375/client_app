/// Transaction model for API responses
class Transaction {
  final String id;
  final String? type; // 'credit', 'debit', etc.
  final String? status; // 'completed', 'pending', 'failed'
  final double amount;
  final String? currency;
  final String? title;
  final String? subtitle;
  final String? description;
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;

  /// Top-level API keys that are not mapped to dedicated fields (for full display).
  final Map<String, dynamic> extraFields;

  Transaction({
    required this.id,
    this.type,
    this.status,
    required this.amount,
    this.currency,
    this.title,
    this.subtitle,
    this.description,
    this.createdAt,
    this.metadata,
    this.extraFields = const {},
  });

  static const Set<String> _knownJsonKeys = {
    'id',
    'transactionId',
    'transaction_id',
    'type',
    'status',
    'amount',
    'currency',
    'title',
    'subtitle',
    'description',
    'createdAt',
    'created_at',
    'timestamp',
    'updatedAt',
    'updated_at',
    'metadata',
  };

  /// Create Transaction from JSON
  factory Transaction.fromJson(Map<String, dynamic> json) {
    final extras = <String, dynamic>{};
    json.forEach((key, value) {
      if (!_knownJsonKeys.contains(key) && value != null) {
        extras[key] = value;
      }
    });

    return Transaction(
      id: (json['id'] ?? json['transactionId'] ?? json['transaction_id'] ?? '').toString(),
      type: json['type']?.toString(),
      status: json['status']?.toString(),
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      currency: json['currency']?.toString(),
      title: json['title']?.toString(),
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString(),
      createdAt: _parseDateTime(
            json['createdAt'] ??
                json['created_at'] ??
                json['timestamp'] ??
                json['updatedAt'] ??
                json['updated_at'],
          ) ??
          _parseDateTimeFromId(
            (json['id'] ?? json['transactionId'] ?? json['transaction_id'])?.toString(),
          ),
      metadata: _asStringKeyedMap(json['metadata']),
      extraFields: extras,
    );
  }

  /// Convert Transaction to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      'amount': amount,
      if (currency != null) 'currency': currency,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (description != null) 'description': description,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
      ...extraFields,
    };
  }

  /// Check if transaction is a debit (outgoing)
  bool get isDebit => type == 'debit';

  /// Check if transaction is a credit (incoming)
  bool get isCredit => type == 'credit';

  /// Check if transaction is completed
  bool get isCompleted => status == 'completed';

  static Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  /// Parses ISO strings, epoch ms/seconds, and Firestore-style timestamp maps.
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return _dateTimeFromEpochNumber(value);
    if (value is double) return _dateTimeFromEpochNumber(value.round());
    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'];
      if (seconds is num) {
        final nanos = value['_nanoseconds'] ?? value['nanoseconds'] ?? 0;
        final nanoNum = nanos is num ? nanos : 0;
        return DateTime.fromMillisecondsSinceEpoch(
          seconds.round() * 1000 + (nanoNum.round() ~/ 1000000),
          isUtc: true,
        );
      }
    }

    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final asInt = int.tryParse(raw);
    if (asInt != null) return _dateTimeFromEpochNumber(asInt);

    return DateTime.tryParse(raw);
  }

  static DateTime? _dateTimeFromEpochNumber(int value) {
    // Heuristic: 10-digit ≈ seconds, 13-digit ≈ milliseconds.
    if (value.abs() < 100000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  /// IDs like `tx_1783285415814_psvll92co` embed epoch milliseconds.
  static DateTime? _parseDateTimeFromId(String? id) {
    if (id == null || id.isEmpty) return null;
    final match = RegExp(r'(\d{12,14})').firstMatch(id);
    if (match == null) return null;
    return _dateTimeFromEpochNumber(int.parse(match.group(1)!));
  }
}

/// API Response wrapper for transactions
class TransactionsResponse {
  final List<Transaction> transactions;
  final String? nextPageToken; // For pagination
  final int totalCount;

  TransactionsResponse({
    required this.transactions,
    this.nextPageToken,
    this.totalCount = 0,
  });

  factory TransactionsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final transactionsList = data['transactions'] as List<dynamic>? ?? [];

    return TransactionsResponse(
      transactions: transactionsList
          .map((tx) => Transaction.fromJson(tx as Map<String, dynamic>))
          .toList(),
      nextPageToken: data['nextPageToken'] as String?,
      totalCount: (data['totalCount'] as num?)?.toInt() ?? transactionsList.length,
    );
  }
}
