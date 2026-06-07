class CryptoSendResult {
  const CryptoSendResult({
    required this.status,
    required this.amount,
    this.circleTransactionId,
    this.txHash,
    this.firestoreTxId,
    this.reservationId,
  });

  final String status;
  final double amount;
  final String? circleTransactionId;
  final String? txHash;
  final String? firestoreTxId;
  final String? reservationId;

  bool get isPending => status == 'pending';

  factory CryptoSendResult.fromJson(Map<String, dynamic> json) {
    return CryptoSendResult(
      status: json['status']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      circleTransactionId: json['circleTransactionId']?.toString(),
      txHash: json['txHash']?.toString(),
      firestoreTxId: json['firestoreTxId']?.toString(),
      reservationId: json['reservationId']?.toString(),
    );
  }
}
