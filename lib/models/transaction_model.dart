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
  });

  /// Create Transaction from JSON
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? json['transactionId'] ?? '',
      type: json['type'] as String?,
      status: json['status'] as String?,
      amount: (json['amount'] is num) 
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      currency: json['currency'] as String?,
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is DateTime
              ? json['createdAt'] as DateTime
              : DateTime.tryParse(json['createdAt'].toString()))
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
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
    };
  }

  /// Check if transaction is a debit (outgoing)
  bool get isDebit => type == 'debit';

  /// Check if transaction is a credit (incoming)
  bool get isCredit => type == 'credit';

  /// Check if transaction is completed
  bool get isCompleted => status == 'completed';
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
