import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:pretium/services/payment_service.dart';
import 'package:pretium/utils/logger.dart';

/// Paystack / Transak C2B return handling via deep link only:
/// - Native: `truepay://payment/callback?reference=fund_…`
/// - Web/PWA: `https://app.truepay.live/payment/callback?reference=fund_…`
///
/// Confirmation is triggered exclusively from [app_links] (cold start + stream).
/// Do not also call [onPaymentReturn] from app resume, launchUrl callbacks, or manual UI buttons.
class PaymentCallbackService {
  PaymentCallbackService._();
  static final PaymentCallbackService instance = PaymentCallbackService._();

  static const Set<String> _webPaymentHosts = {
    'app.truepay.live',
    'localhost',
  };

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Ensures [handlePaymentWebhook] runs at most once per funding reference per app session.
  final Set<String> _confirmedRefs = {};

  Future<void> initialize({required GlobalKey<NavigatorState> navigatorKey}) async {
    _navigatorKey = navigatorKey;

    _linkSubscription ??= _appLinks.uriLinkStream.listen(_onDeepLink);

    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      await _onDeepLink(initial);
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }

  bool _isPaymentCallback(Uri uri) {
    // Native custom scheme: truepay://payment/callback
    if (uri.scheme == 'truepay' &&
        uri.host == 'payment' &&
        uri.path == '/callback') {
      return true;
    }

    // HTTPS return URL for Flutter Web / installed PWA (Firebase Hosting rewrite → index.html)
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        _webPaymentHosts.contains(uri.host) &&
        uri.path == '/payment/callback') {
      return true;
    }

    return false;
  }

  Future<void> _onDeepLink(Uri uri) async {
    if (!_isPaymentCallback(uri)) return;

    final reference = uri.queryParameters['reference'];
    if (reference == null || reference.isEmpty) return;

    await onPaymentReturn(reference);
  }

  /// Idempotent confirm/poll for a funding reference (fund_…) from Paystack or Transak.
  Future<void> onPaymentReturn(String reference) async {
    if (reference.isEmpty || _confirmedRefs.contains(reference)) {
      if (reference.isNotEmpty && _confirmedRefs.contains(reference)) {
        Logger.debug('Skipping duplicate payment confirm: $reference');
      }
      return;
    }
    _confirmedRefs.add(reference);

    Logger.info('Confirming payment via deep link: $reference');

    final paymentService = PaymentService();
    final result = await paymentService.handlePaymentWebhook(invoiceId: reference);

    DashboardSessionCache.instance.clear();

    final context = _navigatorKey?.currentContext;
    if (context == null || !context.mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment confirmed. Your wallet balance will update shortly.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']?.toString() ?? 'Could not confirm payment'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
