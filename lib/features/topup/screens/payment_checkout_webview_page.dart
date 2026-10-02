import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/services/payment_callback_service.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// In-app hosted checkout (Paystack / Transak / Crossmint). Stays inside the app and
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
  WebViewController? _controller;
  var _isLoading = true;
  var _handledReturn = false;
  var _cameraDenied = false;
  var _webLaunchFailed = false;
  double _webViewCssWidth = 0;

  static const _webPaymentHosts = {
    'app.truepay.live',
    'localhost',
  };

  /// Viewport only — do not reset iframe height or global box-sizing.
  /// Those rules clipped Crossmint/Persona (two-column forms, iframe KYC).
  String _responsiveJs(double cssWidth) {
    final width = cssWidth.isFinite && cssWidth > 0 ? cssWidth.round() : 390;
    return '''
(function () {
  var w = $width;
  function applyViewport() {
    var root = document.head || document.documentElement;
    if (!root) return;
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.setAttribute('name', 'viewport');
      root.appendChild(meta);
    }
    meta.setAttribute(
      'content',
      'width=' + w + ', initial-scale=1, minimum-scale=1, maximum-scale=5, user-scalable=yes, viewport-fit=cover'
    );
    var style = document.getElementById('safaritap-checkout-mq');
    if (!style) {
      style = document.createElement('style');
      style.id = 'safaritap-checkout-mq';
      root.appendChild(style);
    }
    style.textContent = [
      'html, body { width: 100% !important; max-width: 100% !important; min-width: 0 !important; margin: 0 !important; padding: 0 !important; overflow-x: auto !important; overflow-y: auto !important; -webkit-text-size-adjust: 100%; }',
      'body { left: 0 !important; }',
      '@media (max-width: ' + w + 'px) {',
      '  #root, #__next, #app, main, [data-testid="checkout"] { width: 100% !important; max-width: 100% !important; min-width: 0 !important; }',
      '}'
    ].join('\\n');
    document.querySelectorAll('iframe').forEach(function (frame) {
      frame.style.maxWidth = '100%';
      frame.style.minWidth = '0';
      frame.style.width = '100%';
      frame.style.marginLeft = '0';
    });
    try { window.scrollTo(0, window.scrollY || 0); } catch (e) {}
  }
  applyViewport();
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', applyViewport);
  }
})();
''';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startCheckout());
    });
  }

  Future<void> _startCheckout() async {
    if (kIsWeb) {
      await _openExternalCheckout();
      return;
    }
    _controller = _createController();
    if (mounted) setState(() {});
    await _preparePermissionsAndLoad();
  }

  Future<void> _openExternalCheckout() async {
    final uri = Uri.tryParse(widget.checkoutUrl);
    var opened = false;
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _webLaunchFailed = !opened;
    });
  }

  WebViewController _createController() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (request) {
        request.grant();
      },
    );

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
            unawaited(_injectResponsiveLayout());
          },
          onPageFinished: (_) {
            unawaited(_injectResponsiveLayout());
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && _isPaymentCallback(uri)) {
              _handlePaymentReturn(uri);
              return NavigationDecision.prevent;
            }
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
            if (error.errorCode == -999) return;
          },
        ),
      );

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
      platform.setOnShowFileSelector(_pickAndroidCaptureFiles);
      unawaited(platform.setUseWideViewPort(true));
      unawaited(platform.enableZoom(true));
    }
    if (platform is WebKitWebViewController) {
      unawaited(platform.setAllowsBackForwardNavigationGestures(true));
      unawaited(platform.enableZoom(true));
    }

    return controller;
  }

  Future<List<String>> _pickAndroidCaptureFiles(FileSelectorParams params) async {
    final wantsVideo = params.acceptTypes.any((type) => type.contains('video'));
    if (wantsVideo) return const <String>[];

    final source =
        params.isCaptureEnabled ? ImageSource.camera : ImageSource.gallery;
    final file = await ImagePicker().pickImage(
      source: source,
      requestFullMetadata: false,
    );
    if (file == null) return const <String>[];
    return <String>[Uri.file(file.path).toString()];
  }

  Future<void> _preparePermissionsAndLoad() async {
    final allowed = await _requestCameraAccess();
    if (!mounted) return;
    if (!allowed) {
      setState(() => _cameraDenied = true);
    }
    await _controller?.loadRequest(Uri.parse(widget.checkoutUrl));
  }

  Future<bool> _requestCameraAccess() async {
    if (kIsWeb) return true;
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobile) return true;

    final camera = await Permission.camera.request();
    await Permission.microphone.request();
    return camera.isGranted;
  }

  Future<void> _injectResponsiveLayout() async {
    final controller = _controller;
    final width = _webViewCssWidth;
    if (controller == null || width <= 0) return;
    try {
      await controller.runJavaScript(_responsiveJs(width));
    } catch (_) {}
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
    final media = MediaQuery.of(context);
    final compact = media.size.width < 360 || media.size.height < 700;
    final titleSize = compact ? 15.0 : 16.0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        toolbarHeight: compact ? 48 : kToolbarHeight,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: titleSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _isLoading
              ? const ShimmerProgressBar()
              : const SizedBox(height: 2),
        ),
      ),
        body: SafeArea(
          top: false,
          child: kIsWeb
              ? _buildWebCheckoutBody(colors, compact)
              : _buildNativeCheckoutBody(colors, media, compact),
        ),
    );
  }

  Widget _buildWebCheckoutBody(AppThemeColors colors, bool compact) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 20 : 32, 24, compact ? 20 : 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.open_in_new, size: 40, color: primary),
          const SizedBox(height: 16),
          Text(
            _webLaunchFailed
                ? 'Could not open checkout automatically'
                : 'Checkout opened in a new tab',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Card payment and identity verification cannot run inside this page on web. '
            'Finish checkout in the new tab. When you are done, return here — your balance will update.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _webLaunchFailed = false;
              });
              unawaited(_openExternalCheckout());
            },
            child: const Text('Open checkout'),
          ),
        ],
      ),
    );
  }

  Widget _buildNativeCheckoutBody(
    AppThemeColors colors,
    MediaQueryData media,
    bool compact,
  ) {
    final controller = _controller;
    return Column(
      children: [
        if (_cameraDenied)
          Material(
            color: colors.surfaceVariant,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: media.size.width < 360 ? 12 : 16,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(Icons.videocam_off, color: colors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Camera access is required to verify your identity. Enable it in Settings.',
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const TextButton(
                    onPressed: openAppSettings,
                    child: Text('Settings'),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: controller == null
              ? const Center(child: ShimmerBusyIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final nextWidth = constraints.maxWidth;
                    if (nextWidth > 0 &&
                        (nextWidth - _webViewCssWidth).abs() > 0.5) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _webViewCssWidth = nextWidth;
                        unawaited(_injectResponsiveLayout());
                      });
                    }
                    return ColoredBox(
                      color: Colors.white,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: WebViewWidget(controller: controller),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
