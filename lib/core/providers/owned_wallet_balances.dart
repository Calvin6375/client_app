import 'package:pretium/services/dashboard_session_cache.dart';

class OwnedWalletBalances {
  const OwnedWalletBalances({
    required this.fiatCodes,
    required this.fiatBalances,
    required this.cryptoCodes,
    required this.allCodes,
    required this.allBalances,
  });

  final List<String> fiatCodes;
  final Map<String, double> fiatBalances;
  final List<String> cryptoCodes;
  final List<String> allCodes;
  final Map<String, double> allBalances;

  static const empty = OwnedWalletBalances(
    fiatCodes: [],
    fiatBalances: {},
    cryptoCodes: [],
    allCodes: [],
    allBalances: {},
  );

  /// Fiat wallets with balance > 0, KES first. Used by Send Money.
  static OwnedWalletBalances fundedFiat(WalletSessionSnapshot? snap) {
    if (snap == null) return empty;
    final codes = <String>{};
    final balances = <String, double>{};
    for (final code in snap.availableFiatCurrencies) {
      final upper = code.toUpperCase();
      if (upper.isEmpty) continue;
      final bal = snap.fiatWallets[upper]?.balance ??
          snap.fiatWallets[code]?.balance ??
          0;
      if (bal <= 0) continue;
      codes.add(upper);
      balances[upper] = bal;
    }
    final ordered = codes.toList()
      ..sort((a, b) {
        if (a == 'KES') return -1;
        if (b == 'KES') return 1;
        return a.compareTo(b);
      });
    return OwnedWalletBalances(
      fiatCodes: ordered,
      fiatBalances: balances,
      cryptoCodes: const [],
      allCodes: ordered,
      allBalances: balances,
    );
  }

  /// Fiat + crypto codes for Exchange.
  static OwnedWalletBalances allFromSnapshot(WalletSessionSnapshot? snap) {
    if (snap == null) return empty;
    final balances = <String, double>{
      for (final e in snap.fiatWallets.entries)
        e.key.toUpperCase(): e.value.balance,
      for (final e in snap.cryptoWallets.entries)
        e.key.toUpperCase(): e.value.balance,
    };
    final codes = <String>{
      ...snap.availableFiatCurrencies.map((c) => c.toUpperCase()),
      ...snap.availableCryptoCurrencies.map((c) => c.toUpperCase()),
    }..removeWhere((c) => c.isEmpty);
    return OwnedWalletBalances(
      fiatCodes: snap.availableFiatCurrencies
          .map((c) => c.toUpperCase())
          .where((c) => c.isNotEmpty)
          .toList(),
      fiatBalances: {
        for (final e in snap.fiatWallets.entries)
          e.key.toUpperCase(): e.value.balance,
      },
      cryptoCodes: snap.availableCryptoCurrencies
          .map((c) => c.toUpperCase())
          .where((c) => c.isNotEmpty)
          .toList(),
      allCodes: codes.toList(),
      allBalances: balances,
    );
  }
}
