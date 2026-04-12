import 'package:pretium/models/transaction_model.dart';
import 'package:pretium/models/wallet_model.dart';

/// Snapshot of wallet lists for restoring [WalletCard] without a network round-trip.
class WalletSessionSnapshot {
  WalletSessionSnapshot({
    required this.fiatWallets,
    required this.availableFiatCurrencies,
    required this.cryptoWallet,
    required this.cachedFiatWallet,
    required this.cachedCryptoWallet,
    required this.refreshedAt,
  });

  final Map<String, Wallet> fiatWallets;
  final List<String> availableFiatCurrencies;
  final Wallet? cryptoWallet;
  final Wallet? cachedFiatWallet;
  final Wallet? cachedCryptoWallet;
  final DateTime refreshedAt;
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
  Wallet? _cryptoWallet;
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
    if (_fiatWallets.isEmpty && _cryptoWallet == null) return null;
    return WalletSessionSnapshot(
      fiatWallets: Map<String, Wallet>.from(_fiatWallets),
      availableFiatCurrencies: List<String>.from(_availableFiatCurrencies),
      cryptoWallet: _cryptoWallet,
      cachedFiatWallet: _cachedFiatWallet,
      cachedCryptoWallet: _cachedCryptoWallet,
      refreshedAt: _walletAt!,
    );
  }

  void recordWalletSnapshot({
    required Map<String, Wallet> fiatWallets,
    required List<String> availableFiatCurrencies,
    required Wallet? cryptoWallet,
    required Wallet? cachedFiatWallet,
    required Wallet? cachedCryptoWallet,
  }) {
    _walletAt = DateTime.now();
    _fiatWallets = Map<String, Wallet>.from(fiatWallets);
    _availableFiatCurrencies = List<String>.from(availableFiatCurrencies);
    _cryptoWallet = cryptoWallet;
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
    _cryptoWallet = null;
    _cachedFiatWallet = null;
    _cachedCryptoWallet = null;
    _transactionsAt = null;
    _recentTransactions = null;
  }
}
