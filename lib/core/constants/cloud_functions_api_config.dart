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

  /// Customer self-registration (`POST …/api/register`).
  /// Path must match the deployed HTTP handler; adjust if the backend uses a different route.
  static Uri registerUri() => Uri.parse('$baseApiUrl/register');

  /// Circle USDC wallet HTTP API (`cryptoApi` Cloud Function).
  static String get baseCryptoApiUrl {
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    return 'https://$functionsRegion-$projectId.cloudfunctions.net/cryptoApi';
  }

  static Uri cryptoWalletUri() => Uri.parse('$baseCryptoApiUrl/crypto/wallet');

  static Uri cryptoBalanceUri() => Uri.parse('$baseCryptoApiUrl/crypto/balance');

  static Uri cryptoTransactionsUri({int limit = 50}) =>
      Uri.parse('$baseCryptoApiUrl/crypto/transactions?limit=$limit');

  static Uri cryptoSendUri() => Uri.parse('$baseCryptoApiUrl/crypto/send');
}
