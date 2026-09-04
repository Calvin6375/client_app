import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:pretium/core/constants/cloud_functions_api_config.dart';
import 'package:pretium/core/http/c2b_http_codec.dart';
import 'package:pretium/features/safari_tap/models/safari_tap_bank.dart';
import 'package:pretium/features/safari_tap/models/safari_tap_payout.dart';
import 'package:pretium/features/safari_tap/models/safari_tap_payout_quote.dart';
import 'package:pretium/utils/logger.dart';

class SafariTapPayApiException implements Exception {
  SafariTapPayApiException({
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
    final parts = <String>['SafariTapPayApiException($statusCode', code ?? 'unknown'];
    if (hint != null && hint!.isNotEmpty) parts.add('hint: $hint');
    if (message != null && message!.isNotEmpty) parts.add(message!);
    return '${parts.join(', ')})';
  }
}

/// HTTP client for SafariTap pay/send (`safariCardApi` Cloud Function).
final class SafariTapPayApiService {
  SafariTapPayApiService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;
  final C2bHttpCodec _codec = C2bHttpCodec.instance;

  /// Fresh Firebase ID token for [Authorization: Bearer …] (never App Check / refresh token).
  Future<String> _requireIdToken({bool forceRefresh = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw SafariTapPayApiException(statusCode: 401, code: 'UNAUTHORIZED');
    }

    final idToken = await user.getIdToken(forceRefresh);
    if (idToken == null || idToken.isEmpty) {
      throw SafariTapPayApiException(statusCode: 401, code: 'UNAUTHORIZED');
    }

    Logger.debug(
      'SafariTapPayApi auth uid=${user.uid} tokenLength=${idToken.length} '
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

  SafariTapPayApiException _apiExceptionFromBody(
    int statusCode,
    Map<String, dynamic> body,
    String rawBody,
  ) {
    Map<String, dynamic>? token;
    final rawToken = body['token'];
    if (rawToken is Map) {
      token = Map<String, dynamic>.from(rawToken);
    }

    return SafariTapPayApiException(
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
      Logger.error('SafariTapPayApi 401: ${response.statusCode}');

      // Only refresh Firebase ID token when backend rejects auth — not IntaSend/provider 401s.
      if (errorCode == 'UNAUTHORIZED' || (errorCode == null && body.isEmpty)) {
        Logger.warning('SafariTapPayApi 401 UNAUTHORIZED — refreshing ID token and retrying once');
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
        Logger.error('SafariTapPayApi ${response.statusCode}');
      }
      throw _apiExceptionFromBody(response.statusCode, body, response.body);
    }

    return body;
  }

  Future<BeneficiaryValidation> validateBeneficiary(
    Map<String, dynamic> body,
  ) async {
    Logger.info('SafariTapPayApi POST validate-beneficiary');
    Future<http.Response> send({required bool forceRefresh}) async => _http.post(
          CloudFunctionsApiConfig.safariTapValidateBeneficiaryUri(),
          headers: await _headers(forceRefresh: forceRefresh),
          body: await _codec.encodeJsonBody(jsonEncode(body)),
        );
    final response = await send(forceRefresh: true);
    final parsed = await _decodeResponse(response, send: send);
    return BeneficiaryValidation.fromJson(
      Map<String, dynamic>.from(parsed['data'] as Map),
    );
  }

  /// Fee quote only — does not create a payout.
  Future<SafariTapPayoutQuote> quotePayout(Map<String, dynamic> body) async {
    Logger.info(
      'SafariTapPayApi POST /safari-card/payouts/quote '
      'type=${body['type']} amount=${body['amount']} currency=${body['currency']}',
    );
    Future<http.Response> send({required bool forceRefresh}) async => _http.post(
          CloudFunctionsApiConfig.safariTapPayoutsQuoteUri(),
          headers: await _headers(forceRefresh: forceRefresh),
          body: await _codec.encodeJsonBody(jsonEncode(body)),
        );
    final response = await send(forceRefresh: true);
    final parsed = await _decodeResponse(response, send: send);
    final data = Map<String, dynamic>.from(parsed['data'] as Map);
    data.putIfAbsent('amount', () => body['amount']);
    data.putIfAbsent('currency', () => body['currency']);
    final quote = SafariTapPayoutQuote.fromJson(data);
    Logger.success(
      'SafariTap payout quote: send=${quote.youSend} '
      'arto=${quote.artoFees} pay=${quote.youWillPay}',
    );
    return quote;
  }

  Future<SafariTapPayout> createPayout(Map<String, dynamic> body) async {
    Logger.info('SafariTapPayApi POST /safari-card/payouts');
    Future<http.Response> send({required bool forceRefresh}) async => _http.post(
          CloudFunctionsApiConfig.safariTapPayoutsUri(),
          headers: await _headers(forceRefresh: forceRefresh),
          body: await _codec.encodeJsonBody(jsonEncode(body)),
        );
    final response = await send(forceRefresh: true);
    final parsed = await _decodeResponse(response, expectedStatus: 201, send: send);
    return SafariTapPayout.fromJson(
      Map<String, dynamic>.from(parsed['data'] as Map),
    );
  }

  Future<SafariTapPayout> getPayoutByClientRequestId(String clientRequestId) async {
    Logger.info('SafariTapPayApi GET by-client-request/$clientRequestId');
    Future<http.Response> send({required bool forceRefresh}) async => _http.get(
          CloudFunctionsApiConfig.safariTapPayoutByClientRequestUri(clientRequestId),
          headers: await _headers(forceRefresh: forceRefresh),
        );
    final response = await send(forceRefresh: true);
    final parsed = await _decodeResponse(response, send: send);
    return SafariTapPayout.fromJson(
      Map<String, dynamic>.from(parsed['data'] as Map),
    );
  }

  Future<SafariTapPayout> getPayout(String payoutId) async {
    Future<http.Response> send({required bool forceRefresh}) async => _http.get(
          CloudFunctionsApiConfig.safariTapPayoutUri(payoutId),
          headers: await _headers(forceRefresh: forceRefresh),
        );
    final response = await send(forceRefresh: true);
    final parsed = await _decodeResponse(response, send: send);
    return SafariTapPayout.fromJson(
      Map<String, dynamic>.from(parsed['data'] as Map),
    );
  }

  Future<List<SafariTapPayout>> listPayouts({int limit = 20}) async {
    Future<http.Response> send({required bool forceRefresh}) async => _http.get(
          CloudFunctionsApiConfig.safariTapPayoutsUri(limit: limit),
          headers: await _headers(forceRefresh: forceRefresh),
        );
    final response = await send(forceRefresh: true);
    final parsed = await _decodeResponse(response, send: send);
    final data = parsed['data'];
    if (data is! List) return [];
    return data
        .map((e) => SafariTapPayout.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<SafariTapBank>> listBanks() async {
    Future<http.Response> send({required bool forceRefresh}) async => _http.get(
          CloudFunctionsApiConfig.safariTapBanksUri(),
          headers: await _headers(forceRefresh: forceRefresh),
        );
    final response = await send(forceRefresh: true);
    final parsed = await _decodeResponse(response, send: send);
    final data = parsed['data'];
    if (data is! List) return [];
    return data
        .map((e) => SafariTapBank.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<SafariTapPayout> pollPayoutUntilTerminal(
    String clientRequestId, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 3),
    void Function(SafariTapPayout snapshot)? onUpdate,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final payout = await getPayoutByClientRequestId(clientRequestId);
        onUpdate?.call(payout);
        if (payout.isTerminal) return payout;
      } on SafariTapPayApiException catch (e) {
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
