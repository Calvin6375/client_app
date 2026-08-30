import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretium/models/user_accounts.dart';
import 'package:pretium/models/wallet_model.dart';
import 'package:pretium/services/accounts_api_service.dart';
import 'package:pretium/utils/logger.dart';

/// Repository for customer wallet / account balances.
///
/// Balances come from `GET /api/accounts` (Firestore + USDC ledger on the
/// server). The client must not read or write RTDB `wallet/{uid}/…` for the
/// wallet list. Circle deposit address / QR still uses [CryptoApiService.getWallet].
///
/// [uid] arguments on methods are ignored for the network call (token subject);
/// they remain for call-site compatibility and optional mismatch checks.
class WalletRepository {
  WalletRepository({AccountsApiService? accountsApi})
      : _accountsApi = accountsApi ?? AccountsApiService();

  final AccountsApiService _accountsApi;

  static UserAccounts? _cache;
  static DateTime? _cacheAt;
  static Future<UserAccounts>? _inFlight;
  static const Duration _cacheTtl = Duration(seconds: 20);

  /// Drops the shared in-memory accounts cache (call on sign-out).
  static void clearCache() {
    _cache = null;
    _cacheAt = null;
    _inFlight = null;
  }

  /// Single fetch of all fiat + crypto accounts for the signed-in user.
  Future<UserAccounts> fetchAccounts({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cache != null &&
        _cacheAt != null &&
        now.difference(_cacheAt!) < _cacheTtl) {
      return _cache!;
    }

    if (!forceRefresh && _inFlight != null) {
      return _inFlight!;
    }

    final future = _accountsApi.fetchAccounts();
    _inFlight = future;
    try {
      final accounts = await future;
      _cache = accounts;
      _cacheAt = DateTime.now();
      return accounts;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  void _warnIfUidMismatch(String uid) {
    final current = FirebaseAuth.instance.currentUser?.uid;
    if (current != null &&
        uid.isNotEmpty &&
        uid != current) {
      Logger.warning(
        'WalletRepository: ignoring mismatched uid=$uid (token uid=$current)',
      );
    }
  }

  /// Owned fiat accounts from `data.fiat` (falls back to `balances.fiat`).
  Future<Map<String, Wallet>> listOwnedFiatWallets(String uid) async {
    _warnIfUidMismatch(uid);
    final accounts = await fetchAccounts();
    return Map<String, Wallet>.from(accounts.fiatWallets);
  }

  /// Owned crypto accounts from `data.crypto` (falls back to `balances.crypto`).
  Future<Map<String, Wallet>> listOwnedCryptoWallets(String uid) async {
    _warnIfUidMismatch(uid);
    final accounts = await fetchAccounts();
    return Map<String, Wallet>.from(accounts.cryptoWallets);
  }

  /// Fiat balance for [currency] from the accounts payload.
  Future<Wallet?> getWalletBalance(String uid, {String currency = 'USD'}) async {
    _warnIfUidMismatch(uid);
    try {
      final accounts = await fetchAccounts();
      return accounts.fiatWallet(currency);
    } catch (e) {
      Logger.error('Failed to get wallet balance', e);
      rethrow;
    }
  }

  /// Crypto balance for [currencyCode]. Returns a zero wallet when missing.
  Future<Wallet?> getCryptoWalletBalance(String uid, String currencyCode) async {
    _warnIfUidMismatch(uid);
    try {
      final accounts = await fetchAccounts();
      return accounts.cryptoWallet(currencyCode) ??
          Wallet(currencyCode: currencyCode.toUpperCase(), balance: 0);
    } catch (e) {
      Logger.error('Failed to get crypto wallet balance', e);
      return Wallet(currencyCode: currencyCode.toUpperCase(), balance: 0);
    }
  }

  /// One-shot stream of fiat balance (no RTDB). Prefer [getWalletBalance].
  Stream<Wallet?> streamWalletBalance(String uid, {String currency = 'USD'}) {
    return Stream.fromFuture(getWalletBalance(uid, currency: currency));
  }

  /// One-shot stream of crypto balance (no RTDB). Prefer [getCryptoWalletBalance]
  /// or pull-to-refresh via [fetchAccounts].
  Stream<Wallet?> streamCryptoWalletBalance(String uid, String currencyCode) {
    return Stream.fromFuture(getCryptoWalletBalance(uid, currencyCode));
  }
}
