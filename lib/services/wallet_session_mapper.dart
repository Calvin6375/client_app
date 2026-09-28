import 'package:pretium/models/user_accounts.dart';
import 'package:pretium/models/wallet_model.dart';
import 'package:pretium/services/dashboard_session_cache.dart';

/// Builds the home/session wallet snapshot from `GET /api/accounts`.
class WalletSessionMapper {
  WalletSessionMapper._();

  static const Set<String> alwaysVisibleFiat = {'KES', 'USD'};
  static const Set<String> alwaysVisibleCrypto = {'USDT', 'USDC'};

  static WalletSessionSnapshot fromAccounts(UserAccounts accounts) {
    final fiatWallets = <String, Wallet>{
      ...accounts.fiatWallets,
      for (final e in accounts.fiatBalances.entries)
        if (!accounts.fiatWallets.containsKey(e.key))
          e.key: Wallet(currencyCode: e.key, balance: e.value),
    };
    for (final code in alwaysVisibleFiat) {
      fiatWallets.putIfAbsent(
        code,
        () =>
            accounts.fiatWallet(code) ?? Wallet(currencyCode: code, balance: 0),
      );
    }

    final availableFiat = fiatWallets.entries
        .where((e) => _showFiat(e.key, e.value.balance))
        .map((e) => e.key)
        .toList();
    final orderedFiat = _withKesFirst(availableFiat);

    final cryptoWallets = <String, Wallet>{
      for (final code in alwaysVisibleCrypto)
        code: accounts.cryptoWallet(code) ??
            Wallet(currencyCode: code, balance: 0),
      ...accounts.cryptoWallets,
    };
    final availableCrypto = cryptoWallets.entries
        .where((e) => _showCrypto(e.key, e.value.balance))
        .map((e) => e.key)
        .toList();
    if (!availableCrypto.contains('USDT')) availableCrypto.insert(0, 'USDT');
    if (!availableCrypto.contains('USDC')) availableCrypto.add('USDC');

    return WalletSessionSnapshot(
      fiatWallets: fiatWallets,
      availableFiatCurrencies: orderedFiat,
      cryptoWallets: cryptoWallets,
      availableCryptoCurrencies: availableCrypto,
      cachedFiatWallet: fiatWallets[
              orderedFiat.isNotEmpty ? orderedFiat.first : 'USD'] ??
          Wallet(currencyCode: 'USD', balance: 0),
      cachedCryptoWallet:
          cryptoWallets['USDT'] ?? Wallet(currencyCode: 'USDT', balance: 0),
      refreshedAt: DateTime.now(),
    );
  }

  static bool _showFiat(String code, double balance) {
    final upper = code.trim().toUpperCase();
    if (alwaysVisibleFiat.contains(upper)) return true;
    return balance > 0;
  }

  static bool _showCrypto(String code, double balance) {
    final upper = code.trim().toUpperCase();
    if (alwaysVisibleCrypto.contains(upper)) return true;
    return balance > 0;
  }

  static List<String> _withKesFirst(List<String> currencies) {
    if (!currencies.contains('KES')) return List<String>.from(currencies);
    return ['KES', ...currencies.where((c) => c != 'KES')];
  }
}
