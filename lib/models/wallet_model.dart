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
    final dynamic balanceValue = json['balance'];
    double parsedBalance;
    if (balanceValue is num) {
      parsedBalance = balanceValue.toDouble();
    } else if (balanceValue is String) {
      parsedBalance = double.tryParse(balanceValue) ?? 0.0;
    } else {
      parsedBalance = 0.0;
    }

    return Wallet(
      currencyCode: (json['currency'] ?? json['currencyCode'] ?? 'KES').toString(),
      balance: parsedBalance,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'currency': currencyCode,
        'balance': balance,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}
