import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/constants/app_routes.dart';
import 'package:tigerbay_app/core/constants/dmn_config.dart';
import 'package:tigerbay_app/core/theme/app_typography.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/features/home/providers/home_provider.dart';
import 'package:tigerbay_app/shared/widgets/apple_touch_feedback.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Reserve a Table / Spot Screen (Apple HIG Edition)
/// ═══════════════════════════════════════════════════════════════════════════
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  String? _lastLoadedVenueId;

  void _handleBack(BuildContext context) {
    HapticFeedback.lightImpact();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

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
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onHttpError: (error) {
            debugPrint(
                'WebView HTTP ${error.response?.statusCode}: ${error.request?.uri}');
          },
          onWebResourceError: (error) {
            debugPrint(
                'WebView error [${error.errorCode}]: ${error.description}');
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.brandBlack,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: AppleTouchFeedback(
            onTap: () => _handleBack(context),
            child: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Icon(
                CupertinoIcons.chevron_back,
                size: 22,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          title: Text(
            'Reserve a Table',
            style: AppTypography.headline.copyWith(
              color: AppColors.textPrimary,
              fontSize: 17,
            ),
          ),
          centerTitle: true,
          actions: [
            if (venueId != null) ...[
              // Open in Safari / External Browser
              AppleTouchFeedback(
                onTap: () => _openInBrowser(
                  selectedBranch?.title ?? 'Kingsbury',
                  venueId,
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    CupertinoIcons.compass,
                    size: 20,
                    color: AppColors.champagneGold,
                  ),
                ),
              ),
              // Refresh WebView
              AppleTouchFeedback(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _lastLoadedVenueId = null;
                  _initWebView(venueId);
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 4, right: 14),
                  child: Icon(
                    CupertinoIcons.arrow_clockwise,
                    size: 19,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Apple Inset Branch Selector ───────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.glassBorder,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        CupertinoIcons.building_2_fill,
                        size: 18,
                        color: AppColors.champagneGold,
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
                            dropdownColor: const Color(0xFF1E1E22),
                            borderRadius: BorderRadius.circular(14),
                            icon: const Icon(
                              CupertinoIcons.chevron_down,
                              size: 14,
                              color: AppColors.textHint,
                            ),
                            style: AppTypography.subheadline.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
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
                                        style: AppTypography.subheadline.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                        loading: () => Text(
                          'Loading branches…',
                          style: AppTypography.subheadline.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                        error: (_, __) => Text(
                          'Select a venue',
                          style: AppTypography.subheadline.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── WebView / Loading / Fallback Body ────────────────────────────
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: _buildBody(venueId, selectedBranch),
                ),
              ),
            ],
          ),
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
                  CupertinoIcons.calendar_badge_minus,
                  size: 34,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Online Booking Not Available',
                textAlign: TextAlign.center,
                style: AppTypography.headline.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                selectedBranch != null
                    ? 'Online booking is not currently available for ${selectedBranch.title}. Please call the restaurant directly to make a reservation.'
                    : 'Please select a venue to book a table.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // WebView controller not yet created — show spinner while microtask fires
    if (_webViewController == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 14),
            Text(
              'Connecting to reservation system…',
              style: AppTypography.footnote.copyWith(color: Colors.black54),
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
          Container(
            color: Colors.white,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 2.5,
                ),
                const SizedBox(height: 14),
                Text(
                  'Loading booking form…',
                  style: AppTypography.footnote.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
