class CryptoWalletEndpoint {
  const CryptoWalletEndpoint({
    required this.network,
    required this.address,
    required this.status,
  });

  final String network;
  final String address;
  final String status;

  factory CryptoWalletEndpoint.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CryptoWalletEndpoint(
        network: '',
        address: '',
        status: '',
      );
    }
    return CryptoWalletEndpoint(
      network: json['network']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }

  bool get hasAddress => address.trim().isNotEmpty;
}

class CryptoWalletStatus {
  const CryptoWalletStatus({
    required this.userId,
    required this.onTestnet,
    required this.hasMainnet,
    required this.shouldCreateMainnet,
    this.testnet,
    this.mainnet,
  });

  final String userId;
  final bool onTestnet;
  final bool hasMainnet;
  final bool shouldCreateMainnet;
  final CryptoWalletEndpoint? testnet;
  final CryptoWalletEndpoint? mainnet;

  factory CryptoWalletStatus.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    return CryptoWalletStatus(
      userId: json['userId']?.toString() ?? '',
      onTestnet: json['onTestnet'] == true,
      hasMainnet: json['hasMainnet'] == true,
      shouldCreateMainnet: json['shouldCreateMainnet'] == true,
      testnet: json['testnet'] == null
          ? null
          : CryptoWalletEndpoint.fromJson(asMap(json['testnet'])),
      mainnet: json['mainnet'] == null
          ? null
          : CryptoWalletEndpoint.fromJson(asMap(json['mainnet'])),
    );
  }

  /// Network to watch after production is ensured.
  /// Fuji leftover (`onTestnet`) does not mean we should watch testnet.
  String get preferredWatchNetwork {
    final main = mainnet?.network.trim();
    if (main != null && main.isNotEmpty) return main;
    if (hasMainnet || !shouldCreateMainnet) return 'avalanche';
    final test = testnet?.network.trim();
    if (test != null && test.isNotEmpty) return test;
    return 'avalanche-fuji';
  }
}
