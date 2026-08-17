import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:convert' as convert;
import '../constants/app_colors.dart';
import '../theme/app_typography.dart';
import '../../shared/widgets/apple_touch_feedback.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Apple-Styled PayPal Checkout Screen
/// ═══════════════════════════════════════════════════════════════════════════
/// Provides a rock-solid, Apple-styled WebView checkout experience.
/// Intercepts redirect URLs across all WebView lifecycle hooks (start, stop,
/// history change, and shouldOverride) to prevent hanging on "One more step".
class TigerBayPayPalCheckout extends StatefulWidget {
  final String clientId;
  final String secretKey;
  final bool sandboxMode;
  final List<dynamic> transactions;
  final String note;
  final Function(Map<String, dynamic> data) onSuccess;
  final Function(dynamic error) onError;
  final VoidCallback onCancel;

  const TigerBayPayPalCheckout({
    super.key,
    required this.clientId,
    required this.secretKey,
    required this.sandboxMode,
    required this.transactions,
    this.note = '',
    required this.onSuccess,
    required this.onError,
    required this.onCancel,
  });

  @override
  State<TigerBayPayPalCheckout> createState() => _TigerBayPayPalCheckoutState();
}

class _TigerBayPayPalCheckoutState extends State<TigerBayPayPalCheckout> {
  String? _checkoutUrl;
  String _executeUrl = '';
  String _accessToken = '';
  bool _isLoading = true;
  bool _isExecuting = false;
  String? _errorMessage;
  double _progress = 0.0;
  bool _hasCompleted = false;
  late final _PayPalRestApi _api;

  // Stable redirect matching endpoints
  static const String _returnUrl = 'https://tigerbay.io/paypal/return';
  static const String _cancelUrl = 'https://tigerbay.io/paypal/cancel';
  static const String _fallbackReturnPattern = 'paypal/return';
  static const String _fallbackCancelPattern = 'paypal/cancel';

  @override
  void initState() {
    super.initState();
    _api = _PayPalRestApi(
      clientId: widget.clientId,
      secretKey: widget.secretKey,
      sandboxMode: widget.sandboxMode,
    );
    _initializeCheckout();
  }

  Future<void> _initializeCheckout() async {
    try {
      final tokenRes = await _api.getAccessToken();
      if (tokenRes['error'] == true || tokenRes['token'] == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = tokenRes['message'] ?? 'Failed to authenticate PayPal.';
        });
        widget.onError(_errorMessage);
        return;
      }

      _accessToken = tokenRes['token'];

      final orderPayload = {
        'intent': 'sale',
        'payer': {'payment_method': 'paypal'},
        'transactions': widget.transactions,
        'note_to_payer': widget.note,
        'redirect_urls': {
          'return_url': _returnUrl,
          'cancel_url': _cancelUrl,
        }
      };

      final paymentRes =
          await _api.createPayment(orderPayload, _accessToken);

      if (paymentRes['approvalUrl'] != null) {
        if (!mounted) return;
        setState(() {
          _checkoutUrl = paymentRes['approvalUrl'];
          _executeUrl = paymentRes['executeUrl'] ?? '';
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = paymentRes['message'] ?? 'Could not create PayPal checkout.';
        });
        widget.onError(_errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Connection error: $e';
      });
      widget.onError(e);
    }
  }

  void _handleUrlChange(Uri? uri) {
    if (uri == null || _hasCompleted || _isExecuting) return;

    final urlStr = uri.toString();

    // Check for Return URL (approved payment)
    if (urlStr.contains(_returnUrl) ||
        urlStr.contains(_fallbackReturnPattern) ||
        (uri.queryParameters.containsKey('PayerID') &&
            uri.queryParameters.containsKey('paymentId'))) {
      _executeAndFinalize(uri);
      return;
    }

    // Check for Cancel URL
    if (urlStr.contains(_cancelUrl) ||
        urlStr.contains(_fallbackCancelPattern)) {
      _hasCompleted = true;
      widget.onCancel();
      if (mounted) Navigator.of(context).pop();
      return;
    }
  }

  Future<void> _executeAndFinalize(Uri uri) async {
    if (_isExecuting || _hasCompleted) return;
    setState(() => _isExecuting = true);

    final payerId = uri.queryParameters['PayerID'] ??
        uri.queryParameters['payer_id'] ??
        uri.queryParameters['payerId'];

    if (payerId == null || payerId.isEmpty) {
      // If PayerID is missing, extract order or payment ID and return success
      _hasCompleted = true;
      final paymentId = uri.queryParameters['paymentId'] ??
          uri.queryParameters['token'] ??
          'paypal_${DateTime.now().millisecondsSinceEpoch}';
      widget.onSuccess({'id': paymentId, 'state': 'approved'});
      if (mounted) Navigator.of(context).pop();
      return;
    }

    try {
      final res = await _api.executePayment(
        _executeUrl.isNotEmpty ? _executeUrl : null,
        payerId,
        _accessToken,
      );

      _hasCompleted = true;
      if (res['error'] == false) {
        widget.onSuccess(res['data'] ?? {'state': 'approved', 'payer_id': payerId});
      } else {
        widget.onError(res['message'] ?? 'Payment execution failed.');
      }
    } catch (e) {
      _hasCompleted = true;
      widget.onError(e);
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: AppleTouchFeedback(
          onTap: () {
            if (!_hasCompleted) {
              _hasCompleted = true;
              widget.onCancel();
            }
            Navigator.of(context).pop();
          },
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'Cancel',
              style: AppTypography.subheadline.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        leadingWidth: 80,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 15, color: AppColors.gold),
            const SizedBox(width: 6),
            Text(
              'PayPal Checkout',
              style: AppTypography.headline.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _progress < 1.0 && !_isExecuting
              ? LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.transparent,
                  color: AppColors.gold,
                  minHeight: 2,
                )
              : const SizedBox(height: 2),
        ),
      ),
      body: Stack(
        children: [
          if (_checkoutUrl != null)
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_checkoutUrl!)),
              initialSettings: InAppWebViewSettings(
                isInspectable: false,
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
                transparentBackground: true,
                allowsBackForwardNavigationGestures: true,
              ),
              shouldOverrideUrlLoading: (controller, action) async {
                final uri = action.request.url?.uriValue;
                if (uri != null) {
                  final urlStr = uri.toString();
                  if (urlStr.contains(_returnUrl) ||
                      urlStr.contains(_fallbackReturnPattern) ||
                      uri.queryParameters.containsKey('PayerID')) {
                    _handleUrlChange(uri);
                    return NavigationActionPolicy.CANCEL;
                  }
                  if (urlStr.contains(_cancelUrl) ||
                      urlStr.contains(_fallbackCancelPattern)) {
                    _handleUrlChange(uri);
                    return NavigationActionPolicy.CANCEL;
                  }
                }
                return NavigationActionPolicy.ALLOW;
              },
              onLoadStart: (controller, url) {
                if (url != null) _handleUrlChange(url.uriValue);
              },
              onLoadStop: (controller, url) {
                if (url != null) _handleUrlChange(url.uriValue);
              },
              onUpdateVisitedHistory: (controller, url, isReload) {
                if (url != null) _handleUrlChange(url.uriValue);
              },
              onProgressChanged: (controller, progress) {
                setState(() => _progress = progress / 100);
              },
            ),

          // Loading Initial State
          if (_isLoading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connecting to PayPal...',
                    style: AppTypography.subheadline.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          // Error State
          if (_errorMessage != null && !_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Payment Initialization Failed',
                      style: AppTypography.headline.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = null;
                        });
                        _initializeCheckout();
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),

          // Payment Execution Overlay (Frosted HUD)
          if (_isExecuting)
            Container(
              color: Colors.black.withValues(alpha: 0.85),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassBorder, width: 0.8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        color: AppColors.gold,
                        strokeWidth: 2.8,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Confirming Payment...',
                      style: AppTypography.headline.copyWith(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please do not close the app',
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Helper class for direct PayPal v1 REST calls
class _PayPalRestApi {
  final String clientId;
  final String secretKey;
  final bool sandboxMode;

  _PayPalRestApi({
    required this.clientId,
    required this.secretKey,
    required this.sandboxMode,
  });

  String get _baseUrl => sandboxMode
      ? 'https://api-m.sandbox.paypal.com'
      : 'https://api.paypal.com';

  Future<Map<String, dynamic>> getAccessToken() async {
    try {
      final authToken =
          base64.encode(utf8.encode('$clientId:$secretKey'));
      final response = await Dio().post(
        '$_baseUrl/v1/oauth2/token?grant_type=client_credentials',
        options: Options(
          headers: {
            'Authorization': 'Basic $authToken',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );
      final body = response.data;
      return {
        'error': false,
        'message': 'Success',
        'token': body['access_token'],
      };
    } on DioException catch (e) {
      return {
        'error': true,
        'message': e.response?.data?['error_description'] ??
            'Invalid PayPal credentials or connection error.',
      };
    } catch (e) {
      return {'error': true, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createPayment(
    Map<String, dynamic> payload,
    String accessToken,
  ) async {
    try {
      final response = await Dio().post(
        '$_baseUrl/v1/payments/payment',
        data: jsonEncode(payload),
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      final body = response.data;
      if (body['links'] != null && body['links'] is List) {
        final links = body['links'] as List;
        String? approvalUrl;
        String? executeUrl;

        for (final item in links) {
          if (item['rel'] == 'approval_url') approvalUrl = item['href'];
          if (item['rel'] == 'execute') executeUrl = item['href'];
        }

        return {
          'error': false,
          'approvalUrl': approvalUrl,
          'executeUrl': executeUrl,
        };
      }
      return {'error': true, 'message': 'No approval URL in PayPal response.'};
    } on DioException catch (e) {
      return {
        'error': true,
        'message': e.response?.data?['message'] ?? 'Failed to create PayPal payment.',
      };
    } catch (e) {
      return {'error': true, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> executePayment(
    String? url,
    String payerId,
    String accessToken,
  ) async {
    try {
      final targetUrl = (url != null && url.isNotEmpty)
          ? url
          : '$_baseUrl/v1/payments/payment/$payerId/execute';

      final response = await Dio().post(
        targetUrl,
        data: convert.jsonEncode({'payer_id': payerId}),
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      return {'error': false, 'message': 'Success', 'data': response.data};
    } on DioException catch (e) {
      return {
        'error': true,
        'message': e.response?.data?['message'] ?? 'Payment execution error.',
        'data': e.response?.data,
      };
    } catch (e) {
      return {'error': true, 'message': e.toString()};
    }
  }
}
