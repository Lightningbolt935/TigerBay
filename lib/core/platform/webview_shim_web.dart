/// Web implementation of the WebView facade.
///
/// `package:webview_flutter` has no web backend, so on the web we cannot
/// render a nested, scriptable browser surface. Instead this stub keeps the
/// exact same API surface (so no call site changes) and surfaces a branded
/// hand-off panel that opens the venue booking page in a new browser tab.
/// This is both more reliable than an iframe (many booking providers send
/// `X-Frame-Options: DENY`) and a better mobile-web experience.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';

// ── Value types mirroring package:webview_flutter ───────────────────────────

enum JavaScriptMode { unrestricted, restricted }

enum NavigationDecision { navigate, prevent, reload }

class NavigationRequest {
  const NavigationRequest(this.url);

  /// The real plugin exposes the navigation target as a [String].
  final String url;
}

class WebResourceRequest {
  const WebResourceRequest(this.uri);

  final Uri uri;
}

class HttpResponse {
  const HttpResponse({this.statusCode});

  final int? statusCode;
}

class WebResourceResponse {
  const WebResourceResponse({this.response, this.request});

  final HttpResponse? response;
  final WebResourceRequest? request;
}

class WebResourceError {
  const WebResourceError({required this.errorCode, required this.description});

  final int errorCode;
  final String description;
}

class NavigationDelegate {
  const NavigationDelegate({
    this.onPageStarted,
    this.onPageFinished,
    this.onProgress,
    this.onNavigationRequest,
    this.onUrlChange,
    this.onHttpError,
    this.onWebResourceError,
  });

  final void Function(String url)? onPageStarted;
  final void Function(String url)? onPageFinished;
  final void Function(int progress)? onProgress;
  final NavigationDecision Function(NavigationRequest request)? onNavigationRequest;
  final void Function(Uri url)? onUrlChange;
  final void Function(WebResourceResponse error)? onHttpError;
  final void Function(WebResourceError error)? onWebResourceError;
}

// ── Controller ───────────────────────────────────────────────────────────────

class WebViewController {
  WebViewController();

  NavigationDelegate? _delegate;
  Uri? _currentUrl;

  /// URL most recently handed to [loadRequest]; used by [WebViewWidget] to
  /// build the external hand-off panel.
  Uri? get currentUrl => _currentUrl;

  Future<WebViewController> setJavaScriptMode(JavaScriptMode mode) async => this;

  Future<bool> setBackgroundColor(Color color) async => true;

  Future<WebViewController> setNavigationDelegate(NavigationDelegate delegate) async {
    _delegate = delegate;
    return this;
  }

  Future<void> loadRequest(Uri uri) async {
    _currentUrl = uri;
    final delegate = _delegate;

    delegate?.onPageStarted?.call(uri.toString());
    delegate?.onProgress?.call(100);

    final decision = delegate?.onNavigationRequest?.call(NavigationRequest(uri.toString()));
    if (decision == NavigationDecision.prevent) return;

    // There is no in-page document to settle, so report the hand-off as ready
    // straight away. This clears the caller's loading overlay.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    delegate?.onPageFinished?.call(uri.toString());
  }

  Future<void> reload() async {
    final uri = _currentUrl;
    if (uri != null) await loadRequest(uri);
  }

  /// Script injection is not possible without a nested browsing context.
  Future<String> runJavaScript(String javascript) async => '';
}

// ── Widget ───────────────────────────────────────────────────────────────────

class WebViewWidget extends StatelessWidget {
  const WebViewWidget({super.key, required this.controller});

  final WebViewController controller;

  Future<void> _open(BuildContext context) async {
    final url = controller.currentUrl;
    if (url == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && messenger != null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not open the booking page.')),
        );
      }
    } catch (e) {
      debugPrint('[WebViewShim] Failed to open booking page: $e');
      if (messenger != null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not open the booking page.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = controller.currentUrl;

    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.open_in_new_rounded,
                  size: 36,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Complete Your Reservation',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.brandBlack,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'For your security, our booking partner opens in a separate '
                'window. Your details are sent straight to them.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B6B70),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: url == null ? null : () => _open(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandBlack,
                    foregroundColor: AppColors.gold,
                    disabledBackgroundColor: const Color(0xFFE4E4E6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.event_available_rounded, size: 19),
                  label: const Text(
                    'Open Booking Page',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
              if (url != null) ...[
                const SizedBox(height: 16),
                Text(
                  url.host,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF9A9AA0),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
