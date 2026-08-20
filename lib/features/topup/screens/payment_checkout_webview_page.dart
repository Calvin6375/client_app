import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/services/payment_callback_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app hosted checkout (Paystack / Transak). Stays inside the app and
/// intercepts payment return URLs so confirmation never depends on Safari.
class PaymentCheckoutWebViewPage extends StatefulWidget {
  const PaymentCheckoutWebViewPage({
    super.key,
    required this.checkoutUrl,
    required this.paymentId,
    this.title = 'Complete payment',
  });

  final String checkoutUrl;
  final String paymentId;
  final String title;

  @override
  State<PaymentCheckoutWebViewPage> createState() =>
      _PaymentCheckoutWebViewPageState();
}

class _PaymentCheckoutWebViewPageState extends State<PaymentCheckoutWebViewPage> {
  late final WebViewController _controller;
  var _isLoading = true;
  var _handledReturn = false;

  static const _webPaymentHosts = {
    'app.truepay.live',
    'localhost',
  };

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && _isPaymentCallback(uri)) {
              _handlePaymentReturn(uri);
              return NavigationDecision.prevent;
            }
            // Keep http(s) checkout inside the WebView; block leaving the app
            // via custom schemes (except our own callback handled above).
            if (uri != null &&
                uri.scheme != 'http' &&
                uri.scheme != 'https' &&
                uri.scheme != 'about' &&
                uri.scheme != 'data' &&
                uri.scheme != 'blob') {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            // Ignore aborted loads from prevented navigations.
            if (error.errorCode == -999) return;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  bool _isPaymentCallback(Uri uri) {
    if (uri.scheme == 'truepay' &&
        uri.host == 'payment' &&
        uri.path == '/callback') {
      return true;
    }
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        _webPaymentHosts.contains(uri.host) &&
        uri.path == '/payment/callback') {
      return true;
    }
    return false;
  }

  Future<void> _handlePaymentReturn(Uri uri) async {
    if (_handledReturn) return;
    _handledReturn = true;

    final reference = uri.queryParameters['reference']?.trim();
    final effectiveRef =
        (reference != null && reference.isNotEmpty) ? reference : widget.paymentId;

    // Successful confirm navigates to home (clears WebView + top-up).
    // On failure, close checkout only so the user stays on deposit.
    var success = false;
    if (effectiveRef.isNotEmpty) {
      success =
          await PaymentCallbackService.instance.onPaymentReturn(effectiveRef);
    }
    if (!success && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _isLoading
              ? LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: colors.background,
                  color: Theme.of(context).colorScheme.primary,
                )
              : const SizedBox(height: 2),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
