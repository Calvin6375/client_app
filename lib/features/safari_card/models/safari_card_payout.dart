class SafariCardPayout {
  const SafariCardPayout({
    required this.payoutId,
    required this.status,
    required this.type,
    required this.amount,
    required this.fee,
    required this.totalDebit,
    required this.currency,
    this.failureReason,
    this.narrative,
    this.recipient,
    this.completedAt,
  });

  final String payoutId;
  final String status;
  final String type;
  final double amount;
  final double fee;
  final double totalDebit;
  final String currency;
  final String? failureReason;
  final String? narrative;
  final Map<String, dynamic>? recipient;
  final String? completedAt;

  bool get isTerminal =>
      status == 'SUCCESS' || status == 'FAILED' || status == 'CANCELLED';

  bool get isSuccess => status == 'SUCCESS';

  factory SafariCardPayout.fromJson(Map<String, dynamic> json) {
    return SafariCardPayout(
      payoutId: json['payoutId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      type: json['type']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      fee: (json['fee'] as num?)?.toDouble() ?? 0,
      totalDebit: (json['totalDebit'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'KES',
      failureReason: json['failureReason']?.toString(),
      narrative: json['narrative']?.toString(),
      recipient: json['recipient'] is Map
          ? Map<String, dynamic>.from(json['recipient'] as Map)
          : null,
      completedAt: json['completedAt']?.toString(),
    );
  }
}

class BeneficiaryValidation {
  const BeneficiaryValidation({
    required this.valid,
    required this.beneficiaryName,
    this.account,
  });

  final bool valid;
  final String beneficiaryName;
  final String? account;

  bool get hasDisplayName => valid && beneficiaryName.trim().isNotEmpty;

  factory BeneficiaryValidation.fromJson(Map<String, dynamic> json) {
    return BeneficiaryValidation(
      valid: json['valid'] == true,
      beneficiaryName: json['beneficiaryName']?.toString() ?? '',
      account: json['account']?.toString(),
    );
  }
}
