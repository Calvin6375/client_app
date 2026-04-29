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
}
