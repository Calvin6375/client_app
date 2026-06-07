class CryptoTransaction {
  const CryptoTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.asset,
    required this.status,
    this.txHash,
    this.circleTransactionId,
    this.toAddress,
    this.fromWalletId,
    this.createdAt,
  });

  final String id;
  final String type;
  final double amount;
  final String asset;
  final String status;
  final String? txHash;
  final String? circleTransactionId;
  final String? toAddress;
  final String? fromWalletId;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isComplete => status == 'complete';
  bool get isFailed => status == 'failed';
  bool get isDeposit => type == 'deposit';
  bool get isSend => type == 'send';

  String get displayTitle {
    if (isDeposit && isComplete) return 'Received $amount $asset';
    if (isSend && isPending) return 'Sending $amount $asset…';
    if (isSend && isComplete) return 'Sent $amount $asset';
    if (isSend && isFailed) return 'Send failed';
    return '$type $amount $asset';
  }

  factory CryptoTransaction.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final raw = json['createdAt'];
    if (raw is String) {
      createdAt = DateTime.tryParse(raw);
    }

    return CryptoTransaction(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      asset: json['asset']?.toString() ?? 'USDC',
      status: json['status']?.toString() ?? '',
      txHash: json['txHash']?.toString(),
      circleTransactionId: json['circleTransactionId']?.toString(),
      toAddress: json['toAddress']?.toString(),
      fromWalletId: json['fromWalletId']?.toString(),
      createdAt: createdAt,
    );
  }
}
