class CryptoWalletInfo {
  const CryptoWalletInfo({
    required this.address,
    required this.chain,
    required this.asset,
    this.walletId,
    this.qrDataUrl,
    this.qrPayload,
  });

  final String address;
  final String chain;
  final String asset;
  final String? walletId;
  final String? qrDataUrl;
  final String? qrPayload;

  factory CryptoWalletInfo.fromJson(Map<String, dynamic> json) {
    return CryptoWalletInfo(
      address: json['address']?.toString() ?? '',
      chain: json['chain']?.toString() ?? '',
      asset: json['asset']?.toString() ?? 'USDC',
      walletId: json['walletId']?.toString(),
      qrDataUrl: json['qrDataUrl']?.toString(),
      qrPayload: json['qrPayload']?.toString(),
    );
  }
}
