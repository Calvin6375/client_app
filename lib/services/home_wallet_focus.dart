/// One-shot request to land on a specific home wallet after a success flow.
class HomeWalletFocus {
  HomeWalletFocus._();

  static HomeWalletFocusRequest? _pending;

  static void showCryptoWallet({String currency = 'USDC'}) {
    _pending = HomeWalletFocusRequest(
      walletTab: 1,
      cryptoCurrency: currency.toUpperCase(),
    );
  }

  static HomeWalletFocusRequest? peek() => _pending;

  static HomeWalletFocusRequest? take() {
    final pending = _pending;
    _pending = null;
    return pending;
  }
}

class HomeWalletFocusRequest {
  const HomeWalletFocusRequest({
    required this.walletTab,
    this.cryptoCurrency,
  });

  /// `0` fiat, `1` crypto.
  final int walletTab;
  final String? cryptoCurrency;
}
