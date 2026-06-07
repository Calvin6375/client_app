import 'package:pretium/models/transaction_model.dart';
import 'package:pretium/models/wallet_model.dart';

/// Snapshot of wallet lists for restoring [WalletCard] without a network round-trip.
class WalletSessionSnapshot {
  WalletSessionSnapshot({
    required this.fiatWallets,
    required this.availableFiatCurrencies,
    required this.cryptoWallets,
    required this.availableCryptoCurrencies,
    required this.cachedFiatWallet,
    required this.cachedCryptoWallet,
    required this.refreshedAt,
  });

  final Map<String, Wallet> fiatWallets;
  final List<String> availableFiatCurrencies;
  final Map<String, Wallet> cryptoWallets;
  final List<String> availableCryptoCurrencies;
  final Wallet? cachedFiatWallet;
  final Wallet? cachedCryptoWallet;
  final DateTime refreshedAt;

  Wallet? get cryptoWallet {
    if (availableCryptoCurrencies.isEmpty) return null;
    return cryptoWallets[availableCryptoCurrencies.first];
  }
}

/// In-memory dashboard data shared across navigations so returning to home
/// does not re-hit the network while [ttl] is valid. Cleared on sign-out.
class DashboardSessionCache {
  DashboardSessionCache._();
  static final DashboardSessionCache instance = DashboardSessionCache._();

  /// How long cached wallet + recent transactions stay valid without pull-to-refresh.
  static const Duration ttl = Duration(minutes: 5);

  DateTime? _walletAt;
  Map<String, Wallet> _fiatWallets = {};
  List<String> _availableFiatCurrencies = [];
  Map<String, Wallet> _cryptoWallets = {};
  List<String> _availableCryptoCurrencies = [];
  Wallet? _cachedFiatWallet;
  Wallet? _cachedCryptoWallet;

  DateTime? _transactionsAt;
  TransactionsResponse? _recentTransactions;

  bool _walletFresh() =>
      _walletAt != null && DateTime.now().difference(_walletAt!) < ttl;

  bool _transactionsFresh() =>
      _transactionsAt != null && DateTime.now().difference(_transactionsAt!) < ttl;

  /// Restore wallet UI from last successful fetch if still within [ttl].
  WalletSessionSnapshot? readWalletIfFresh() {
    if (!_walletFresh()) return null;
    if (_fiatWallets.isEmpty && _cryptoWallets.isEmpty) return null;
    return WalletSessionSnapshot(
      fiatWallets: Map<String, Wallet>.from(_fiatWallets),
      availableFiatCurrencies: List<String>.from(_availableFiatCurrencies),
      cryptoWallets: Map<String, Wallet>.from(_cryptoWallets),
      availableCryptoCurrencies: List<String>.from(_availableCryptoCurrencies),
      cachedFiatWallet: _cachedFiatWallet,
      cachedCryptoWallet: _cachedCryptoWallet,
      refreshedAt: _walletAt!,
    );
  }

  void recordWalletSnapshot({
    required Map<String, Wallet> fiatWallets,
    required List<String> availableFiatCurrencies,
    required Map<String, Wallet> cryptoWallets,
    required List<String> availableCryptoCurrencies,
    required Wallet? cachedFiatWallet,
    required Wallet? cachedCryptoWallet,
  }) {
    _walletAt = DateTime.now();
    _fiatWallets = Map<String, Wallet>.from(fiatWallets);
    _availableFiatCurrencies = List<String>.from(availableFiatCurrencies);
    _cryptoWallets = Map<String, Wallet>.from(cryptoWallets);
    _availableCryptoCurrencies = List<String>.from(availableCryptoCurrencies);
    _cachedFiatWallet = cachedFiatWallet;
    _cachedCryptoWallet = cachedCryptoWallet;
  }

  void recordTransactions(TransactionsResponse response) {
    _transactionsAt = DateTime.now();
    _recentTransactions = TransactionsResponse(
      transactions: List<Transaction>.from(response.transactions),
      nextPageToken: response.nextPageToken,
      totalCount: response.totalCount,
    );
  }

  TransactionsResponse? copyRecentTransactionsIfFresh() {
    if (!_transactionsFresh() || _recentTransactions == null) return null;
    return TransactionsResponse(
      transactions: List<Transaction>.from(_recentTransactions!.transactions),
      nextPageToken: _recentTransactions!.nextPageToken,
      totalCount: _recentTransactions!.totalCount,
    );
  }

  void clear() {
    _walletAt = null;
    _fiatWallets = {};
    _availableFiatCurrencies = [];
    _cryptoWallets = {};
    _availableCryptoCurrencies = [];
    _cachedFiatWallet = null;
    _cachedCryptoWallet = null;
    _transactionsAt = null;
    _recentTransactions = null;
  }
}
