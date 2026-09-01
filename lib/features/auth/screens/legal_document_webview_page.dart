import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/bottom_safe_action_bar.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app legal document viewer. Pops `true` only after the user scrolls to the
/// bottom (or the page fits on screen) and confirms they've read it.
class LegalDocumentWebViewPage extends StatefulWidget {
  const LegalDocumentWebViewPage({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  static const termsOfServiceUrl =
      'https://www.truepay.live/legal/terms-of-service';
  static const privacyPolicyUrl =
      'https://www.truepay.live/legal/privacy-policy';

  @override
  State<LegalDocumentWebViewPage> createState() =>
      _LegalDocumentWebViewPageState();
}

class _LegalDocumentWebViewPageState extends State<LegalDocumentWebViewPage> {
  late final WebViewController _controller;
  var _isLoading = true;
  var _reachedBottom = false;

  static const _scrollChannel = 'ScrollBridge';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        _scrollChannel,
        onMessageReceived: (message) {
          if (message.message == 'bottom' && mounted && !_reachedBottom) {
            setState(() => _reachedBottom = true);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _reachedBottom = false;
              });
            }
          },
          onPageFinished: (_) async {
            if (!mounted) return;
            setState(() => _isLoading = false);
            await _injectScrollListener();
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            // Keep reading inside this document; allow same-host anchors.
            if (uri.scheme != 'http' &&
                uri.scheme != 'https' &&
                uri.scheme != 'about' &&
                uri.scheme != 'data' &&
                uri.scheme != 'blob') {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _injectScrollListener() async {
    await _controller.runJavaScript('''
(function() {
  if (window.__truepayScrollBound) {
    window.__truepayCheckScroll && window.__truepayCheckScroll();
    return;
  }
  window.__truepayScrollBound = true;
  function check() {
    var doc = document.documentElement;
    var body = document.body || doc;
    var scrollTop = window.pageYOffset || doc.scrollTop || body.scrollTop || 0;
    var scrollHeight = Math.max(
      doc.scrollHeight || 0,
      body.scrollHeight || 0,
      doc.offsetHeight || 0,
      body.offsetHeight || 0
    );
    var clientHeight = window.innerHeight || doc.clientHeight || 0;
    if (scrollHeight <= clientHeight + 8 ||
        scrollTop + clientHeight >= scrollHeight - 48) {
      $_scrollChannel.postMessage('bottom');
    }
  }
  window.__truepayCheckScroll = check;
  window.addEventListener('scroll', check, { passive: true });
  window.addEventListener('resize', check);
  setTimeout(check, 100);
  setTimeout(check, 500);
  check();
})();
''');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

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
              ? const ShimmerProgressBar()
              : const SizedBox(height: 2),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: WebViewWidget(controller: _controller)),
          BottomSafeActionBar(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _reachedBottom
                      ? 'You\'ve reached the end of this document.'
                      : 'Scroll to the bottom to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _reachedBottom ? primary : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      disabledForegroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _reachedBottom
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    child: const Text('I have read this'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
