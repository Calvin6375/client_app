class DepositWatchResult {
  DepositWatchResult({
    required this.intentId,
    required this.userId,
    required this.asset,
    required this.network,
    required this.address,
    required this.status,
    required this.expiresAt,
  });

  final String intentId;
  final String userId;
  final String asset;
  final String network;
  final String address;
  final String status;
  final DateTime expiresAt;

  factory DepositWatchResult.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expiresAt']?.toString();
    return DepositWatchResult(
      intentId: json['intentId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      asset: json['asset']?.toString() ?? 'USDC',
      network: json['network']?.toString() ?? 'avalanche-fuji',
      address: json['address']?.toString() ?? '',
      status: json['status']?.toString() ?? 'monitoring',
      expiresAt: expiresRaw != null
          ? DateTime.tryParse(expiresRaw) ??
              DateTime.now().toUtc().add(const Duration(seconds: 60))
          : DateTime.now().toUtc().add(const Duration(seconds: 60)),
    );
  }

  String get networkLabel {
    switch (network) {
      case 'avalanche-fuji':
        return 'Avalanche Fuji';
      default:
        return network;
    }
  }
}
