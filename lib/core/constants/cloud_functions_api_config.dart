import 'package:pretium/firebase_options.dart';

/// Base URL for HTTP Cloud Functions that live under the `api` rewrite.
/// Pattern: `https://<region>-<project-id>.cloudfunctions.net/api`
final class CloudFunctionsApiConfig {
  CloudFunctionsApiConfig._();

  /// Region where `api` functions are deployed (must match Firebase console).
  static const String functionsRegion = 'us-central1';

  static String get baseApiUrl {
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    return 'https://$functionsRegion-$projectId.cloudfunctions.net/api';
  }

  static Uri countriesUri() => Uri.parse('$baseApiUrl/countries');

  /// Customer wallet/account balances (`GET …/api/accounts`).
  /// Alias: [walletsUri] (`GET …/api/wallets`) — same body.
  static Uri accountsUri() => Uri.parse('$baseApiUrl/accounts');

  /// Alias of [accountsUri] — same response body.
  static Uri walletsUri() => Uri.parse('$baseApiUrl/wallets');

  /// Customer self-registration (`POST …/api/register`).
  /// Path must match the deployed HTTP handler; adjust if the backend uses a different route.
  static Uri registerUri() => Uri.parse('$baseApiUrl/register');

  /// Transactions feed HTTP API (`transactionsApi` Cloud Function).
  static String get baseTransactionsApiUrl {
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    return 'https://$functionsRegion-$projectId.cloudfunctions.net/transactionsApi';
  }

  static Uri transactionsUri() => Uri.parse('$baseTransactionsApiUrl/transactions');

  static Uri transactionUri(String transactionId) =>
      Uri.parse('$baseTransactionsApiUrl/transactions/$transactionId');

  /// Circle USDC wallet HTTP API (`cryptoApi` Cloud Function).
  static String get baseCryptoApiUrl {
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    return 'https://$functionsRegion-$projectId.cloudfunctions.net/cryptoApi';
  }

  static Uri cryptoWalletUri() => Uri.parse('$baseCryptoApiUrl/crypto/wallet');

  static Uri cryptoBalanceUri() => Uri.parse('$baseCryptoApiUrl/crypto/balance');

  static Uri cryptoTransactionsUri({int limit = 50}) =>
      Uri.parse('$baseCryptoApiUrl/crypto/transactions?limit=$limit');

  /// SafariTap pay / send HTTP API (`safariCardApi` Cloud Function).
  static String get baseSafariTapApiUrl {
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    return 'https://$functionsRegion-$projectId.cloudfunctions.net/safariCardApi';
  }

  static Uri safariTapValidateBeneficiaryUri() =>
      Uri.parse('$baseSafariTapApiUrl/safari-card/payouts/validate-beneficiary');

  static Uri safariTapPayoutsUri({int? limit}) {
    final base = '$baseSafariTapApiUrl/safari-card/payouts';
    if (limit != null) return Uri.parse('$base?limit=$limit');
    return Uri.parse(base);
  }

  static Uri safariTapPayoutUri(String payoutId) =>
      Uri.parse('$baseSafariTapApiUrl/safari-card/payouts/$payoutId');

  static Uri safariTapPayoutByClientRequestUri(String clientRequestId) =>
      Uri.parse('$baseSafariTapApiUrl/safari-card/payouts/by-client-request/$clientRequestId');

  static Uri safariTapBanksUri() =>
      Uri.parse('$baseSafariTapApiUrl/safari-card/banks');

  static String get expectedProjectId =>
      DefaultFirebaseOptions.currentPlatform.projectId;
}
