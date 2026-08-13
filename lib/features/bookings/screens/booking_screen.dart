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

    final widgetHtml = DmnConfig.getWidgetHtml(venueId);
    debugPrint('[Booking] Loading responsive partner widget HTML for venue: $venueId');

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D0804))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onHttpError: (error) {
            debugPrint('WebView HTTP ${error.response?.statusCode}: ${error.request?.uri}');
          },
          onWebResourceError: (error) {
            debugPrint('WebView error [${error.errorCode}]: ${error.description}');
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );

    controller.loadHtmlString(
      widgetHtml,
      baseUrl: 'https://www.tigerbayshisha.co.uk',
    );

    setState(() {
      _webViewController = controller;
      _isLoading = true;
    });
  }

  void _onBranchChanged(Branch branch, List<Branch> list) {
    ref.read(selectedBranchProvider.notifier).changeBranch(branch);
    final newVenueId = DmnConfig.getDmnVenueId(branch.title);
    debugPrint('[Booking] Branch: "${branch.title}" → venueId: $newVenueId');
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
      debugPrint('[Booking] Could not launch URL: $e');
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
      backgroundColor: const Color(0xFF0D0804),
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
                      color: const Color(0xFF1E140C),
                      child: const Icon(Icons.store_outlined,
                          color: AppColors.gold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: branches.when(
                      data: (list) => DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          dropdownColor: const Color(0xFF1E140C),
                          value: selectedBranch?.id ??
                              (list.isNotEmpty ? list.first.id : null),
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: AppColors.gold),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          onChanged: (id) {
                            if (id == null) return;
                            final b = list.firstWhere((b) => b.id == id);
                            _onBranchChanged(b, list);
                          },
                          items: list
                              .map((b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text(
                                      b.title,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      loading: () => const Text('Loading branches…',
                          style: TextStyle(fontSize: 14, color: Colors.white70)),
                      error: (_, __) => const Text('Select a venue',
                          style: TextStyle(fontSize: 15, color: Colors.white70)),
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
                        color: Colors.white,
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
                          color: const Color(0xFF1E140C),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.open_in_browser,
                            size: 20, color: AppColors.gold),
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
                          color: const Color(0xFF1E140C),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.refresh,
                            size: 20, color: AppColors.gold),
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                selectedBranch != null
                    ? 'Online booking is not yet available for ${selectedBranch.title}. Please call the restaurant to make a reservation.'
                    : 'Please select a venue to book a table.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
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
              style: TextStyle(fontSize: 13, color: Colors.white70),
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
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
