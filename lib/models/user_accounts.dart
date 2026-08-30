import 'package:pretium/models/wallet_model.dart';

/// Parsed `data` payload from `GET /api/accounts` (alias `/api/wallets`).
///
/// Prefer [fiatWallets] / [cryptoWallets] (from `data.fiat` / `data.crypto`) for
/// owned-account lists. Use [fiatBalances] / [cryptoBalances] for lookups of any
/// projected currency code (including zeros).
class UserAccounts {
  const UserAccounts({
    required this.userId,
    required this.fiatWallets,
    required this.cryptoWallets,
    required this.fiatBalances,
    required this.cryptoBalances,
  });

  final String userId;

  /// From `data.fiat` — accounts the server associates with the user.
  final Map<String, Wallet> fiatWallets;

  /// From `data.crypto` — crypto accounts (includes USDC ledger balance).
  final Map<String, Wallet> cryptoWallets;

  /// From `data.balances.fiat` — full projected fiat map (zeros included).
  final Map<String, double> fiatBalances;

  /// From `data.balances.crypto` — full crypto map.
  final Map<String, double> cryptoBalances;

  factory UserAccounts.fromJson(Map<String, dynamic> json) {
    final fiatFromList = _walletsFromAccountList(json['fiat'], isCrypto: false);
    final cryptoFromList =
        _walletsFromAccountList(json['crypto'], isCrypto: true);

    final balancesRaw = json['balances'];
    final balances = balancesRaw is Map
        ? Map<String, dynamic>.from(balancesRaw)
        : <String, dynamic>{};

    final fiatBalances = _balancesMap(balances['fiat']);
    final cryptoBalances = _balancesMap(balances['crypto']);

    return UserAccounts(
      userId: json['userId']?.toString() ?? '',
      fiatWallets: _ownedFromListOrBalances(
        list: fiatFromList,
        balances: fiatBalances,
      ),
      cryptoWallets: _ownedFromListOrBalances(
        list: cryptoFromList,
        balances: cryptoBalances,
      ),
      fiatBalances: fiatBalances,
      cryptoBalances: cryptoBalances,
    );
  }

  Wallet? fiatWallet(String currency) {
    final code = currency.trim().toUpperCase();
    if (code.isEmpty) return null;
    final fromOwned = fiatWallets[code];
    if (fromOwned != null) return fromOwned;
    if (fiatBalances.containsKey(code)) {
      return Wallet(currencyCode: code, balance: fiatBalances[code]!);
    }
    return null;
  }

  Wallet? cryptoWallet(String currency) {
    final code = currency.trim().toUpperCase();
    if (code.isEmpty) return null;
    final fromOwned = cryptoWallets[code];
    if (fromOwned != null) return fromOwned;
    if (cryptoBalances.containsKey(code)) {
      return Wallet(currencyCode: code, balance: cryptoBalances[code]!);
    }
    return null;
  }

  static Map<String, Wallet> _ownedFromListOrBalances({
    required Map<String, Wallet> list,
    required Map<String, double> balances,
  }) {
    if (list.isNotEmpty) return list;
    // Fallback: expose every balance key so UI can still render wallets.
    return {
      for (final e in balances.entries)
        e.key: Wallet(currencyCode: e.key, balance: e.value),
    };
  }

  static Map<String, Wallet> _walletsFromAccountList(
    dynamic raw, {
    required bool isCrypto,
  }) {
    if (raw is! List) return {};
    final result = <String, Wallet>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final code = (map['currency'] ?? map['currencyCode'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      if (code.isEmpty) continue;
      final type = map['type']?.toString().toLowerCase();
      if (type != null &&
          type.isNotEmpty &&
          type != (isCrypto ? 'crypto' : 'fiat')) {
        continue;
      }
      result[code] = Wallet.fromJson({...map, 'currency': code});
    }
    return result;
  }

  static Map<String, double> _balancesMap(dynamic raw) {
    if (raw is! Map) return {};
    final result = <String, double>{};
    for (final entry in raw.entries) {
      final code = entry.key.toString().trim().toUpperCase();
      if (code.isEmpty) continue;
      final value = entry.value;
      if (value is num) {
        result[code] = value.toDouble();
      } else if (value is String) {
        result[code] = double.tryParse(value) ?? 0;
      } else {
        result[code] = 0;
      }
    }
    return result;
  }
}
