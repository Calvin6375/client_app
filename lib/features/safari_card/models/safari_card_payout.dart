class SafariCardPayout {
  const SafariCardPayout({
    this.payoutId = '',
    this.clientRequestId,
    required this.status,
    required this.type,
    required this.amount,
    required this.fee,
    required this.totalDebit,
    required this.currency,
    this.merchantName,
    this.mpesaReference,
    this.failureReason,
    this.narrative,
    this.recipient,
    this.completedAt,
  });

  final String payoutId;
  final String? clientRequestId;
  final String status;
  final String type;
  final double amount;
  final double fee;
  final double totalDebit;
  final String currency;
  final String? merchantName;
  final String? mpesaReference;
  final String? failureReason;
  final String? narrative;
  final Map<String, dynamic>? recipient;
  final String? completedAt;

  bool get isTerminal =>
      status == 'SUCCESS' || status == 'FAILED' || status == 'CANCELLED';

  bool get isSuccess => status == 'SUCCESS';

  String get displayName {
    final merchant = merchantName?.trim();
    if (merchant != null && merchant.isNotEmpty) return merchant;
    final recipientName = recipient?['name']?.toString().trim();
    if (recipientName != null && recipientName.isNotEmpty) return recipientName;
    return 'Recipient';
  }

  double get displayDebit => totalDebit > 0 ? totalDebit : amount;

  factory SafariCardPayout.fromJson(Map<String, dynamic> json) {
    return SafariCardPayout(
      payoutId: json['payoutId']?.toString() ?? '',
      clientRequestId: json['clientRequestId']?.toString(),
      status: json['status']?.toString() ?? 'UNKNOWN',
      type: json['type']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      fee: (json['fee'] as num?)?.toDouble() ?? 0,
      totalDebit: (json['totalDebit'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'KES',
      merchantName: json['merchantName']?.toString(),
      mpesaReference: json['mpesaReference']?.toString(),
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
