import 'package:pretium/utils/provider_display_sanitizer.dart';

/// Transaction model for API responses.
class Transaction {
  final String id;
  final String? type;
  final String? status;
  final double amount;
  final String? currency;
  final String? title;
  final String? subtitle;
  final String? description;
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;

  /// Normalized presentation fields from transactionsApi.
  final String? displayName;
  final String? label;
  final String? direction;
  final double? signedAmount;
  final String? reconType;
  final String? source;
  final double? previousBalance;
  final double? newBalance;
  final Map<String, dynamic>? recipient;

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
    this.displayName,
    this.label,
    this.direction,
    this.signedAmount,
    this.reconType,
    this.source,
    this.previousBalance,
    this.newBalance,
    this.recipient,
    this.extraFields = const {},
  });

  static const Set<String> _knownJsonKeys = {
    'id',
    'transactionId',
    'transaction_id',
    'userId',
    'user_id',
    'type',
    'status',
    'amount',
    'signedAmount',
    'direction',
    'currency',
    'title',
    'subtitle',
    'label',
    'displayName',
    'description',
    'reconType',
    'source',
    'previousBalance',
    'newBalance',
    'createdAt',
    'created_at',
    'timestamp',
    'updatedAt',
    'updated_at',
    'metadata',
    'recipient',
  };

  /// Create Transaction from JSON
  factory Transaction.fromJson(Map<String, dynamic> json) {
    final extras = <String, dynamic>{};
    json.forEach((key, value) {
      if (!_knownJsonKeys.contains(key) && value != null) {
        extras[key] = value;
      }
    });

    final parsedDirection = json['direction']?.toString().toLowerCase();
    final parsedSignedAmount = _parseDouble(json['signedAmount']);
    final parsedAmount = _parseDouble(json['amount']) ?? 0.0;

    return Transaction(
      id: (json['id'] ?? json['transactionId'] ?? json['transaction_id'] ?? '')
          .toString(),
      type: json['type']?.toString(),
      status: json['status']?.toString(),
      amount: parsedAmount.abs(),
      currency: json['currency']?.toString(),
      title: json['title']?.toString(),
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString(),
      displayName: json['displayName']?.toString(),
      label: json['label']?.toString(),
      direction: parsedDirection,
      signedAmount: parsedSignedAmount,
      reconType: json['reconType']?.toString(),
      source: json['source']?.toString(),
      previousBalance: _parseDouble(json['previousBalance']),
      newBalance: _parseDouble(json['newBalance']),
      recipient: _parseRecipientMap(json) ??
          _parseRecipientMap(json['metadata'] as Map<String, dynamic>?),
      createdAt: _parseDateTime(
            json['createdAt'] ??
                json['created_at'] ??
                json['timestamp'] ??
                json['updatedAt'] ??
                json['updated_at'],
          ) ??
          _parseDateTimeFromId(
            (json['id'] ?? json['transactionId'] ?? json['transaction_id'])
                ?.toString(),
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
      if (signedAmount != null) 'signedAmount': signedAmount,
      if (direction != null) 'direction': direction,
      if (currency != null) 'currency': currency,
      if (displayName != null) 'displayName': displayName,
      if (label != null) 'label': label,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (description != null) 'description': description,
      if (reconType != null) 'reconType': reconType,
      if (source != null) 'source': source,
      if (previousBalance != null) 'previousBalance': previousBalance,
      if (newBalance != null) 'newBalance': newBalance,
      if (recipient != null) 'recipient': recipient,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
      ...extraFields,
    };
  }

  /// Primary list title — prefer API [displayName], without provider names.
  String get displayTitle {
    for (final candidate in [displayName, label, title]) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        final sanitized = ProviderDisplaySanitizer.sanitize(candidate);
        if (sanitized.isNotEmpty) return sanitized;
      }
    }

    final fromRecon = ProviderDisplaySanitizer.labelFromReconType(
      reconType ?? type,
      isDebit: isDebit,
    );
    if (fromRecon.isNotEmpty) return fromRecon;

    return isDebit ? 'Sent' : 'Received';
  }

  /// Secondary line under the title in compact lists.
  String listSubtitle({String fallbackCurrency = 'KES'}) {
    for (final candidate in [subtitle, description]) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        final sanitized = ProviderDisplaySanitizer.sanitize(candidate);
        if (sanitized.isNotEmpty) return sanitized;
      }
    }

    final parts = <String>[];
    final statusLabel = statusDisplay;
    if (statusLabel.isNotEmpty) parts.add(statusLabel);
    final cur = currency ?? fallbackCurrency;
    if (cur.isNotEmpty) parts.add(cur);
    return parts.join(' · ');
  }

  /// Signed amount for +/- display. Positive = credit, negative = debit.
  double get signedAmountValue {
    if (signedAmount != null && signedAmount != 0) return signedAmount!;
    return isDebit ? -amount.abs() : amount.abs();
  }

  String formattedSignedAmount({String? currencyOverride}) {
    final cur = currencyOverride ?? currency ?? 'KES';
    final signed = signedAmountValue;
    final prefix = signed >= 0 ? '+' : '-';
    return '$prefix$cur ${signed.abs().toStringAsFixed(2)}';
  }

  String get statusDisplay {
    final raw = status?.trim();
    if (raw == null || raw.isEmpty) return 'Completed';
    if (raw.length == 1) return raw.toUpperCase();
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

  String get directionLabel =>
      isDebit ? 'Debit (outgoing)' : 'Credit (incoming)';

  /// Check if transaction is a debit (outgoing)
  bool get isDebit {
    if (direction != null) {
      return direction!.toLowerCase() == 'debit';
    }
    if (signedAmount != null && signedAmount != 0) {
      return signedAmount! < 0;
    }
    final normalizedType = type?.toLowerCase();
    if (normalizedType == 'debit') return true;
    if (normalizedType == 'credit') return false;

    const debitTypes = {
      'merchant_payment',
      'withdraw',
      'withdrawal',
      'payout',
      'send',
      'payment',
    };
    if (normalizedType != null && debitTypes.contains(normalizedType)) {
      return true;
    }

    final metaType = metadata?['type']?.toString().toLowerCase();
    if (metaType == 'send') return true;
    if (metaType == 'receive') return false;

    return false;
  }

  /// Check if transaction is a credit (incoming)
  bool get isCredit => !isDebit;

  /// Check if transaction is completed
  bool get isCompleted {
    final s = status?.toLowerCase();
    return s == 'completed' || s == 'success';
  }

  static Map<String, dynamic>? _parseRecipientMap(dynamic source) {
    if (source is! Map) return null;
    final raw = source['recipient'];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

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
  final String? nextPageToken;
  final int totalCount;
  final bool hasMore;
  final List<String> sources;

  TransactionsResponse({
    required this.transactions,
    this.nextPageToken,
    this.totalCount = 0,
    this.hasMore = false,
    this.sources = const [],
  });

  factory TransactionsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final transactionsList = data['transactions'] as List<dynamic>? ?? [];
    final pagination = data['pagination'] as Map<String, dynamic>?;
    final rawSources = data['sources'];

    return TransactionsResponse(
      transactions: transactionsList
          .map((tx) => Transaction.fromJson(tx as Map<String, dynamic>))
          .toList(),
      nextPageToken: pagination?['startAfter'] as String? ??
          data['nextPageToken'] as String?,
      totalCount: (pagination?['count'] as num?)?.toInt() ??
          (data['totalCount'] as num?)?.toInt() ??
          transactionsList.length,
      hasMore: pagination?['hasMore'] as bool? ?? false,
      sources: rawSources is List
          ? rawSources.map((s) => s.toString()).toList()
          : const [],
    );
  }
}
