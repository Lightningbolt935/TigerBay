import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/constants/dmn_config.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/features/home/providers/home_provider.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  String? _lastLoadedVenueId;

  /// Builds (or rebuilds) the WebView controller for the given DMN [venueId].
  void _initWebView(String venueId) {
    if (_lastLoadedVenueId == venueId && _webViewController != null) return;
    _lastLoadedVenueId = venueId;

    final bookingUrl = DmnConfig.getBookingUrl(venueId);
    debugPrint('[Booking] Loading URL: $bookingUrl');

    late final WebViewController controller;
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) async {
            if (mounted) setState(() => _isLoading = false);
            // Inject responsive CSS to clean navigation headers and fix mobile popovers
            try {
              await controller.runJavaScript('''
                (function() {
                  var style = document.getElementById('tb-mobile-fix');
                  if (!style) {
                    style = document.createElement('style');
                    style.id = 'tb-mobile-fix';
                    style.innerHTML = `
                      header, .header-utilities, .header-row, .secondary-nav, .logo, .strapline, footer {
                        display: none !important;
                      }
                      body {
                        background: #ffffff !important;
                        padding: 6px 12px 30px !important;
                        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif !important;
                      }
                      .super-heading h1 {
                        font-size: 20px !important;
                        margin-top: 6px !important;
                        color: #1a1a1a !important;
                      }
                      .container.book {
                        padding: 0 !important;
                        width: 100% !important;
                      }
                      /* Center mobile popover dropdown dialogs */
                      .popover {
                        position: fixed !important;
                        top: 50% !important;
                        left: 50% !important;
                        transform: translate(-50%, -50%) !important;
                        width: 88% !important;
                        max-width: 360px !important;
                        max-height: 75vh !important;
                        overflow-y: auto !important;
                        z-index: 999999 !important;
                        background: #ffffff !important;
                        border-radius: 16px !important;
                        border: 1px solid rgba(0,0,0,0.15) !important;
                        box-shadow: 0 16px 48px rgba(0,0,0,0.3) !important;
                        padding: 16px !important;
                      }
                      .popover .arrow {
                        display: none !important;
                      }
                      .popover .radio, .popover label {
                        font-size: 15px !important;
                        color: #222222 !important;
                        padding: 10px 8px !important;
                        display: block !important;
                        cursor: pointer !important;
                        line-height: 1.4 !important;
                      }
                      .popover .radio input[type="radio"] {
                        margin-right: 10px !important;
                        transform: scale(1.2) !important;
                      }
                      /* Fix datepicker calendar */
                      .ui-datepicker {
                        width: 90% !important;
                        max-width: 320px !important;
                        margin: 0 auto !important;
                        font-size: 14px !important;
                        border-radius: 12px !important;
                        box-shadow: 0 10px 30px rgba(0,0,0,0.15) !important;
                      }
                      /* Inputs & Primary Buttons */
                      .form-control, input, select {
                        border-radius: 10px !important;
                        height: 48px !important;
                        font-size: 15px !important;
                      }
                      .btn-primary, button[type="submit"] {
                        background: #C4A35A !important;
                        border-color: #C4A35A !important;
                        color: #ffffff !important;
                        font-weight: 700 !important;
                        border-radius: 25px !important;
                        height: 50px !important;
                        font-size: 16px !important;
                      }
                    `;
                    document.head.appendChild(style);
                  }
                })();
              ''');
            } catch (e) {
              debugPrint('[Booking] Style injection note: \$e');
            }
          },
          onHttpError: (error) {
            debugPrint('WebView HTTP \${error.response?.statusCode}: \${error.request?.uri}');
          },
          onWebResourceError: (error) {
            debugPrint('WebView error [\${error.errorCode}]: \${error.description}');
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );

    controller.loadRequest(Uri.parse(bookingUrl));

    setState(() {
      _webViewController = controller;
      _isLoading = true;
    });
  }

  void _onBranchChanged(Branch branch, List<Branch> list) {
    ref.read(selectedBranchProvider.notifier).changeBranch(branch);
    final newVenueId = DmnConfig.getDmnVenueId(branch.title);
    debugPrint('[Booking] Branch: "\${branch.title}" → venueId: \$newVenueId');
    if (newVenueId != null) {
      _initWebView(newVenueId);
    } else {
      setState(() {
        _webViewController = null;
        _lastLoadedVenueId = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _openInBrowser(String branchTitle, String venueId) async {
    final directUrl = DmnConfig.getDirectBookingUrl(branchTitle, venueId);
    final uri = Uri.parse(directUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[Booking] Could not launch URL: \$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final branches = ref.watch(branchesProvider);
    final selectedBranch = ref.watch(selectedBranchProvider);

    // Resolve the DMN venue ID from the selected branch title.
    final venueId = selectedBranch != null
        ? DmnConfig.getDmnVenueId(selectedBranch.title)
        : null;

    // Auto-init WebView when branch becomes available and we haven't loaded yet.
    if (venueId != null && _webViewController == null) {
      Future.microtask(() {
        if (mounted) _initWebView(venueId);
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Branch Selector ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.store_outlined,
                          color: AppColors.gold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: branches.when(
                      data: (list) => DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedBranch?.id ??
                              (list.isNotEmpty ? list.first.id : null),
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down,
                              color: Colors.grey.shade600),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          onChanged: (id) {
                            if (id == null) return;
                            final b = list.firstWhere((b) => b.id == id);
                            _onBranchChanged(b, list);
                          },
                          items: list
                              .map((b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text(b.title),
                                  ))
                              .toList(),
                        ),
                      ),
                      loading: () => const Text('Loading branches…',
                          style: TextStyle(fontSize: 14)),
                      error: (_, __) => const Text('Select a venue',
                          style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Section Title + Actions (Refresh & Open in Browser) ─────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Book a Table',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (venueId != null) ...[
                    GestureDetector(
                      onTap: () => _openInBrowser(
                        selectedBranch?.title ?? 'Kingsbury',
                        venueId,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.open_in_browser,
                            size: 20, color: Colors.grey.shade700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _lastLoadedVenueId = null; // Force reload
                        _initWebView(venueId);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.refresh,
                            size: 20, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── WebView / Loading / Fallback ──────────────────────────────
            Expanded(
              child: _buildBody(venueId, selectedBranch),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String? venueId, dynamic selectedBranch) {
    // No branch matched a DMN venue
    if (venueId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_busy_outlined,
                  size: 36,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Online Booking Not Available',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                selectedBranch != null
                    ? 'Online booking is not yet available for \${selectedBranch.title}. Please call the restaurant to make a reservation.'
                    : 'Please select a venue to book a table.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // WebView controller not yet created — show spinner while microtask fires
    if (_webViewController == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 2.5,
            ),
            SizedBox(height: 14),
            Text(
              'Loading booking form…',
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      );
    }

    // WebView ready — show it with an overlay spinner while page loads
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController!),
        if (_isLoading)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 2.5,
                ),
                SizedBox(height: 14),
                Text(
                  'Loading booking form…',
                  style: TextStyle(fontSize: 13, color: Colors.black45),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
