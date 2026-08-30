import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pretium/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result of comparing the installed app version to the live store listing.
class ForceUpdateCheckResult {
  const ForceUpdateCheckResult({
    required this.updateRequired,
    required this.installedVersion,
    required this.installedBuild,
    this.storeVersion,
    this.storeUrl,
    this.error,
  });

  final bool updateRequired;
  final String installedVersion;
  final String installedBuild;
  final String? storeVersion;
  final Uri? storeUrl;
  final String? error;

  static ForceUpdateCheckResult allow({
    required String installedVersion,
    required String installedBuild,
    String? storeVersion,
    Uri? storeUrl,
    String? error,
  }) {
    return ForceUpdateCheckResult(
      updateRequired: false,
      installedVersion: installedVersion,
      installedBuild: installedBuild,
      storeVersion: storeVersion,
      storeUrl: storeUrl,
      error: error,
    );
  }
}

/// Checks App Store / Play Store for a newer version than the installed build.
///
/// On lookup failure (offline, timeout, app not listed yet), [check] returns
/// [ForceUpdateCheckResult.updateRequired] = false so users are not locked out.
class ForceUpdateService {
  ForceUpdateService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const String androidPackageId = 'com.truepay.safaritap';
  static const String iosBundleId = 'com.truepay.safaritap';

  static const Duration _timeout = Duration(seconds: 8);

  /// Compares installed `versionName` (e.g. `1.0.0` from `1.0.0+22`) to the
  /// store listing. Returns [updateRequired] when the store version is newer.
  Future<ForceUpdateCheckResult> check() async {
    final info = await PackageInfo.fromPlatform();
    final installedVersion = info.version.trim();
    final installedBuild = info.buildNumber.trim();

    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return ForceUpdateCheckResult.allow(
        installedVersion: installedVersion,
        installedBuild: installedBuild,
        error: 'Store check skipped on this platform',
      );
    }

    try {
      final listing = defaultTargetPlatform == TargetPlatform.iOS
          ? await _fetchIosListing()
          : await _fetchAndroidListing();

      if (listing == null) {
        Logger.warning('ForceUpdate: no store listing — allowing app');
        return ForceUpdateCheckResult.allow(
          installedVersion: installedVersion,
          installedBuild: installedBuild,
          error: 'Store listing unavailable',
        );
      }

      final storeVersion = listing.version;
      final required = _isStoreNewer(storeVersion, installedVersion);

      Logger.info(
        'ForceUpdate: installed=$installedVersion+$installedBuild '
        'store=$storeVersion required=$required',
      );

      return ForceUpdateCheckResult(
        updateRequired: required,
        installedVersion: installedVersion,
        installedBuild: installedBuild,
        storeVersion: storeVersion,
        storeUrl: listing.storeUrl,
      );
    } catch (e, st) {
      Logger.warning('ForceUpdate: store check failed — allowing app', e);
      Logger.debug('$st');
      return ForceUpdateCheckResult.allow(
        installedVersion: installedVersion,
        installedBuild: installedBuild,
        error: e.toString(),
      );
    }
  }

  Future<void> openStore(Uri? storeUrl) async {
    final uri = storeUrl ??
        (defaultTargetPlatform == TargetPlatform.iOS
            ? Uri.parse('https://apps.apple.com/search?term=SafariTap')
            : Uri.parse(
                'https://play.google.com/store/apps/details?id=$androidPackageId',
              ));

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      Logger.warning('ForceUpdate: failed to open store $uri');
    }
  }

  Future<_StoreListing?> _fetchIosListing() async {
    final uri = Uri.https('itunes.apple.com', '/lookup', {
      'bundleId': iosBundleId,
      'country': 'us',
    });
    final response = await _http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('iTunes lookup HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body is! Map) return null;
    final results = body['results'];
    if (results is! List || results.isEmpty) return null;

    final first = results.first;
    if (first is! Map) return null;
    final version = first['version']?.toString().trim();
    if (version == null || version.isEmpty) return null;

    final trackViewUrl = first['trackViewUrl']?.toString();
    final trackId = first['trackId'];
    final storeUrl = trackViewUrl != null && trackViewUrl.isNotEmpty
        ? Uri.parse(trackViewUrl)
        : (trackId != null
            ? Uri.parse('https://apps.apple.com/app/id$trackId')
            : null);

    return _StoreListing(version: version, storeUrl: storeUrl);
  }

  Future<_StoreListing?> _fetchAndroidListing() async {
    final uri = Uri.https('play.google.com', '/store/apps/details', {
      'id': androidPackageId,
      'hl': 'en',
      'gl': 'US',
    });
    final response = await _http.get(
      uri,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Play Store HTTP ${response.statusCode}');
    }

    final version = _parsePlayStoreVersion(response.body);
    if (version == null || version.isEmpty) return null;

    return _StoreListing(version: version, storeUrl: uri);
  }

  /// Extracts the published versionName from Play Store HTML / embedded JSON.
  static String? _parsePlayStoreVersion(String html) {
    final patterns = <RegExp>[
      RegExp(r'\[\[\["(\d+\.\d+(?:\.\d+)*)"\]\]'),
      RegExp(r'"softwareVersion"\s*:\s*"(\d+\.\d+(?:\.\d+)*)"'),
      RegExp(
        r'Current Version</div><span[^>]*>\s*(\d+\.\d+(?:\.\d+)*)\s*</span>',
        caseSensitive: false,
      ),
      RegExp(
        r'itemprop="softwareVersion">\s*(\d+\.\d+(?:\.\d+)*)\s*<',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Returns true when [storeVersion] is strictly greater than [installedVersion].
  static bool _isStoreNewer(String storeVersion, String installedVersion) {
    final store = _parseVersionParts(storeVersion);
    final installed = _parseVersionParts(installedVersion);
    final len = store.length > installed.length ? store.length : installed.length;
    for (var i = 0; i < len; i++) {
      final s = i < store.length ? store[i] : 0;
      final c = i < installed.length ? installed[i] : 0;
      if (s > c) return true;
      if (s < c) return false;
    }
    return false;
  }

  static List<int> _parseVersionParts(String version) {
    final cleaned = version.split('+').first.trim();
    if (cleaned.isEmpty) return const [0];
    return cleaned
        .split('.')
        .map((part) => int.tryParse(RegExp(r'\d+').stringMatch(part) ?? '') ?? 0)
        .toList();
  }
}

class _StoreListing {
  const _StoreListing({required this.version, this.storeUrl});

  final String version;
  final Uri? storeUrl;
}
