/// Wallet model for Realtime Database
class Wallet {
  final String currencyCode;
  final double balance;
  final DateTime? updatedAt;

  Wallet({
    required this.currencyCode,
    required this.balance,
    this.updatedAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    final dynamic balanceValue = json['balance'] ?? json['amount'];
    double parsedBalance;
    if (balanceValue is num) {
      parsedBalance = balanceValue.toDouble();
    } else if (balanceValue is String) {
      parsedBalance = double.tryParse(balanceValue) ?? 0.0;
    } else {
      parsedBalance = 0.0;
    }

    return Wallet(
      currencyCode: (json['currency'] ?? json['currencyCode'] ?? 'USD').toString(),
      balance: parsedBalance,
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is String
              ? DateTime.tryParse(json['updatedAt'].toString())
              : null)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'currency': currencyCode,
        'balance': balance,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  /// Create a copy with updated fields
  Wallet copyWith({
    String? currencyCode,
    double? balance,
    DateTime? updatedAt,
  }) {
    return Wallet(
      currencyCode: currencyCode ?? this.currencyCode,
      balance: balance ?? this.balance,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Wallet(currency: $currencyCode, balance: $balance)';
  }
}
