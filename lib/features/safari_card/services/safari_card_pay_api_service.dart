import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:pretium/core/constants/cloud_functions_api_config.dart';
import 'package:pretium/core/http/c2b_http_codec.dart';
import 'package:pretium/features/safari_card/models/safari_card_bank.dart';
import 'package:pretium/features/safari_card/models/safari_card_payout.dart';
import 'package:pretium/utils/logger.dart';

class SafariCardPayApiException implements Exception {
  SafariCardPayApiException({
    required this.statusCode,
    this.message,
    this.code,
    this.hint,
    this.tokenDiagnostics,
    this.rawBody,
  });

  final int statusCode;
  final String? message;
  final String? code;
  final String? hint;
  final Map<String, dynamic>? tokenDiagnostics;
  final String? rawBody;

  @override
  String toString() {
    final parts = <String>['SafariCardPayApiException($statusCode', code ?? 'unknown'];
    if (hint != null && hint!.isNotEmpty) parts.add('hint: $hint');
    if (message != null && message!.isNotEmpty) parts.add(message!);
    return '${parts.join(', ')})';
  }
}

/// HTTP client for Safari Card pay/send (`safariCardApi` Cloud Function).
final class SafariCardPayApiService {
  SafariCardPayApiService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;
  final C2bHttpCodec _codec = C2bHttpCodec.instance;

  /// Fresh Firebase ID token for [Authorization: Bearer …] (never App Check / refresh token).
  Future<String> _requireIdToken({bool forceRefresh = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw SafariCardPayApiException(statusCode: 401, code: 'UNAUTHORIZED');
    }

    final idToken = await user.getIdToken(forceRefresh);
    if (idToken == null || idToken.isEmpty) {
      throw SafariCardPayApiException(statusCode: 401, code: 'UNAUTHORIZED');
    }

    Logger.debug(
      'SafariCardPayApi auth uid=${user.uid} tokenLength=${idToken.length} '
      'project=${CloudFunctionsApiConfig.expectedProjectId} refreshed=$forceRefresh',
    );
    return idToken;
  }

  Future<Map<String, String>> _headers({bool forceRefresh = true}) async {
    return _codec.mergeHeaders({
      'Authorization': 'Bearer ${await _requireIdToken(forceRefresh: forceRefresh)}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    });
  }

  SafariCardPayApiException _apiExceptionFromBody(
    int statusCode,
    Map<String, dynamic> body,
    String rawBody,
  ) {
    Map<String, dynamic>? token;
    final rawToken = body['token'];
    if (rawToken is Map) {
      token = Map<String, dynamic>.from(rawToken);
    }

    return SafariCardPayApiException(
      statusCode: statusCode,
      message: body['error']?.toString(),
      code: body['code']?.toString(),
      hint: body['hint']?.toString(),
      tokenDiagnostics: token,
      rawBody: rawBody,
    );
  }

  Future<Map<String, dynamic>> _decodeResponse(
    http.Response response, {
    int expectedStatus = 200,
    bool retryOn401 = true,
    required Future<http.Response> Function({required bool forceRefresh}) send,
  }) async {
    Map<String, dynamic> body;
    try {
      final plainBody = await _codec.plainResponseBody(response);
      final decoded = jsonDecode(plainBody);
      body = decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      body = {};
    }

    if (response.statusCode == 401 && retryOn401) {
      final errorCode = body['code']?.toString();
      Logger.error('SafariCardPayApi 401: ${response.statusCode}');

      // Only refresh Firebase ID token when backend rejects auth — not IntaSend/provider 401s.
      if (errorCode == 'UNAUTHORIZED' || (errorCode == null && body.isEmpty)) {
        Logger.warning('SafariCardPayApi 401 UNAUTHORIZED — refreshing ID token and retrying once');
        final retry = await send(forceRefresh: true);
        return _decodeResponse(
          retry,
          expectedStatus: expectedStatus,
          retryOn401: false,
          send: send,
        );
      }
    }

    if (response.statusCode != expectedStatus || body['success'] != true) {
      if (response.statusCode != 401) {
        Logger.error('SafariCardPayApi ${response.statusCode}');
      }
      throw _apiExceptionFromBody(response.statusCode, body, response.body);
    }

    return body;
  }

  Future<BeneficiaryValidation> validateBeneficiary(
    Map<String, dynamic> body,
  ) async {
    Logger.info('SafariCardPayApi POST validate-beneficiary');
    Future<http.Response> send({required bool forceRefresh}) async => _http.post(
          CloudFunctionsApiConfig.safariCardValidateBeneficiaryUri(),
          headers: await _headers(forceRefresh: forceRefresh),
          body: await _codec.encodeJsonBody(jsonEncode(body)),
        );
    final response = await send(forceRefresh: true);
    final parsed = await _decodeResponse(response, send: send);
    return BeneficiaryValidation.fromJson(
      Map<String, dynamic>.from(parsed['data'] as Map),
    );
  }

  Future<SafariCardPayout> createPayout(Map<String, dynamic> body) async {
    Logger.info('SafariCardPayApi POST /safari-card/payouts');
    Future<http.Response> send({required bool forceRefresh}) async => _http.post(
          CloudFunctionsApiConfig.safariCardPayoutsUri(),
          headers: await _headers(forceRefresh: forceRefresh),
          body: await _codec.encodeJsonBody(jsonEncode(body)),
        );
    final response = await send(forceRefresh: true);
    final parsed = await _decodeResponse(response, expectedStatus: 201, send: send);
    return SafariCardPayout.fromJson(
      Map<String, dynamic>.from(parsed['data'] as Map),
    );
  }

  Future<SafariCardPayout> getPayoutByClientRequestId(String clientRequestId) async {
    Logger.info('SafariCardPayApi GET by-client-request/$clientRequestId');
    Future<http.Response> send({required bool forceRefresh}) async => _http.get(
          CloudFunctionsApiConfig.safariCardPayoutByClientRequestUri(clientRequestId),
          headers: await _headers(forceRefresh: forceRefresh),
        );
    final response = await send(forceRefresh: true);
    final parsed = await _decodeResponse(response, send: send);
    return SafariCardPayout.fromJson(
      Map<String, dynamic>.from(parsed['data'] as Map),
    );
  }

  Future<SafariCardPayout> getPayout(String payoutId) async {
    Future<http.Response> send({required bool forceRefresh}) async => _http.get(
          CloudFunctionsApiConfig.safariCardPayoutUri(payoutId),
          headers: await _headers(forceRefresh: forceRefresh),
        );
    final response = await send(forceRefresh: true);
    final parsed = await _decodeResponse(response, send: send);
    return SafariCardPayout.fromJson(
      Map<String, dynamic>.from(parsed['data'] as Map),
    );
  }

  Future<List<SafariCardPayout>> listPayouts({int limit = 20}) async {
    Future<http.Response> send({required bool forceRefresh}) async => _http.get(
          CloudFunctionsApiConfig.safariCardPayoutsUri(limit: limit),
          headers: await _headers(forceRefresh: forceRefresh),
        );
    final response = await send(forceRefresh: true);
    final parsed = await _decodeResponse(response, send: send);
    final data = parsed['data'];
    if (data is! List) return [];
    return data
        .map((e) => SafariCardPayout.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<SafariCardBank>> listBanks() async {
    Future<http.Response> send({required bool forceRefresh}) async => _http.get(
          CloudFunctionsApiConfig.safariCardBanksUri(),
          headers: await _headers(forceRefresh: forceRefresh),
        );
    final response = await send(forceRefresh: true);
    final parsed = await _decodeResponse(response, send: send);
    final data = parsed['data'];
    if (data is! List) return [];
    return data
        .map((e) => SafariCardBank.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<SafariCardPayout> pollPayoutUntilTerminal(
    String clientRequestId, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 3),
    void Function(SafariCardPayout snapshot)? onUpdate,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final payout = await getPayoutByClientRequestId(clientRequestId);
        onUpdate?.call(payout);
        if (payout.isTerminal) return payout;
      } on SafariCardPayApiException catch (e) {
        if (e.statusCode == 404) {
          // POST may still be in flight — keep polling briefly.
        } else {
          rethrow;
        }
      }
      await Future<void>.delayed(interval);
    }
    throw TimeoutException('Payout still processing');
  }
}
