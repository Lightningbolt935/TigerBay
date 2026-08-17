import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── 1. App Routes & Constants ────────────────────────────────────────────────
import 'package:tigerbay_app/core/constants/app_routes.dart';

// ── 2. Providers & State Classes ─────────────────────────────────────────────
import 'package:tigerbay_app/features/auth/providers/auth_provider.dart';
import 'package:tigerbay_app/features/auth/providers/profile_state_provider.dart';

// ── 3. Navigation Shell ──────────────────────────────────────────────────────
import 'package:tigerbay_app/shared/widgets/main_shell.dart';

// ── 4. Auth & Onboarding Screens ─────────────────────────────────────────────
import 'package:tigerbay_app/features/auth/screens/splash_screen.dart';
import 'package:tigerbay_app/features/auth/screens/login_screen.dart';
import 'package:tigerbay_app/features/auth/screens/otp_screen.dart';
import 'package:tigerbay_app/features/auth/screens/email_verification_pending_screen.dart';
import 'package:tigerbay_app/features/membership/screens/membership_paywall_screen.dart';

// ── 5. Core Application Screens ──────────────────────────────────────────────
import 'package:tigerbay_app/features/home/screens/home_screen.dart';
import 'package:tigerbay_app/features/home/screens/dashboard_screen.dart';
import 'package:tigerbay_app/features/menu/screens/menu_screen.dart';
import 'package:tigerbay_app/features/notifications/screens/notifications_screen.dart';

// ── 6. Loyalty & Rewards Screens ─────────────────────────────────────────────
import 'package:tigerbay_app/features/loyalty/screens/loyalty_screen.dart';
import 'package:tigerbay_app/features/loyalty/screens/qr_display_screen.dart';
import 'package:tigerbay_app/features/loyalty/screens/transaction_history_screen.dart';
import 'package:tigerbay_app/features/loyalty/screens/link_physical_card_screen.dart';
import 'package:tigerbay_app/features/loyalty/screens/redeem_screen.dart';
import 'package:tigerbay_app/features/loyalty/screens/reward_store_screen.dart';

// ── 7. Booking & Reservation Screens ─────────────────────────────────────────
import 'package:tigerbay_app/features/bookings/screens/my_bookings_screen.dart';
import 'package:tigerbay_app/features/bookings/screens/booking_screen.dart';
import 'package:tigerbay_app/features/bookings/screens/booking_confirm_screen.dart';

// ── 8. Profile & Settings Screens ────────────────────────────────────────────
import 'package:tigerbay_app/features/profile/screens/profile_screen.dart';
import 'package:tigerbay_app/features/profile/screens/edit_profile_screen.dart';
import 'package:tigerbay_app/features/profile/screens/notification_prefs_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// GoRouter Refresh Stream Notifier
/// ═══════════════════════════════════════════════════════════════════════════
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) {
      notifyListeners();
    });
  }

  /// Public API for external callers (e.g. profile state listener) to
  /// trigger a GoRouter redirect re-evaluation without violating the
  /// protected `notifyListeners()` contract.
  void refresh() => notifyListeners();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — GoRouter with Hard Paywall Onboarding Guard
/// ═══════════════════════════════════════════════════════════════════════════
final routerProvider = Provider<GoRouter>((ref) {
  // ── Refresh Notifier ───────────────────────────────────────────────────
  final refreshNotifier = GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  );

  // ── Profile State Listener ─────────────────────────────────────────────
  ref.listen<ProfileState>(profileStateProvider, (previous, next) {
    final prevStatus = previous?.profile?.membershipStatus;
    final nextStatus = next.profile?.membershipStatus;
    final prevTierId = previous?.profile?.membershipTierId;
    final nextTierId = next.profile?.membershipTierId;
    final prevReady = previous?.isReady ?? false;
    final nextReady = next.isReady;

    if (prevStatus != nextStatus ||
        prevTierId != nextTierId ||
        prevReady != nextReady) {
      debugPrint(
        '[TigerBay Router] Profile state changed — '
        'ready: $prevReady → $nextReady, '
        'status: $prevStatus → $nextStatus, '
        'tierId: $prevTierId → $nextTierId — triggering router refresh.',
      );
      refreshNotifier.refresh();
    }
  });

  ref.onDispose(() => refreshNotifier.dispose());

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final authStatus = ref.read(authStatusProvider);
      final loc = state.matchedLocation;

      final profileState = ref.read(profileStateProvider);
      final membershipStatus =
          profileState.profile?.membershipStatus ?? 'inactive';
      final membershipTierId = profileState.profile?.membershipTierId;

      // Active only if status is NOT 'inactive' AND a valid tier ID exists
      final isMembershipActive =
          membershipStatus != 'inactive' && membershipTierId != null;

      debugPrint(
        '[TigerBay Router] Redirect check — '
        'loc=$loc, auth=$authStatus, '
        'membership=$membershipStatus, tierId=$membershipTierId, '
        'profileReady=${profileState.isReady}',
      );

      // ── Gate 0: Unknown Auth State (Cold Start) ───────────────────────
      if (authStatus == AuthStatus.unknown) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final isAuthenticated = authStatus == AuthStatus.authenticated;
      final isPendingEmail = authStatus == AuthStatus.pendingEmailVerification;

      // ── Gate 1: Email Verification Pending ─────────────────────────────
      if (isPendingEmail) {
        return loc == AppRoutes.pendingVerification
            ? null
            : AppRoutes.pendingVerification;
      }

      // ── Gate 2: Unauthenticated User ──────────────────────────────────
      if (!isAuthenticated) {
        final isOnAuthRoute = loc == AppRoutes.login ||
            loc == AppRoutes.otp ||
            loc == AppRoutes.register ||
            loc == AppRoutes.splash ||
            loc == AppRoutes.pendingVerification;

        return isOnAuthRoute ? null : AppRoutes.login;
      }

      // ── Gate 3: Authenticated — Profile Loading Guard ─────────────────
      if (!profileState.isReady) {
        debugPrint(
            '[TigerBay Router] Profile not ready yet — holding route until profile loads.');
        return null;
      }

      // ── Gate 4: Hard Membership Gate (Paywall Enforcement) ─────────────
      // If user is authenticated but membership is NOT active/selected,
      // force them to the paywall regardless of where they were trying to go.
      if (!isMembershipActive) {
        debugPrint(
            '[TigerBay Router] User inactive/no tier selected → Enforcing /membership-paywall');
        return loc == AppRoutes.membershipPaywall
            ? null
            : AppRoutes.membershipPaywall;
      }

      // ── Gate 5: Active Member Route Cleanup ────────────────────────────
      // If active member is sitting on auth or onboarding screens, send them Home.
      // NOTE: /membership-paywall is intentionally NOT in this list — active
      // members can open it from the Profile page to view / renew / switch
      // their membership. Gate 4 still forces INACTIVE users onto the paywall.
      final isOnOnboardingOrAuthRoute = loc == AppRoutes.login ||
          loc == AppRoutes.register ||
          loc == AppRoutes.splash ||
          loc == AppRoutes.pendingVerification ||
          loc == AppRoutes.otp;

      if (isOnOnboardingOrAuthRoute) {
        debugPrint(
            '[TigerBay Router] Active member on onboarding route → Redirecting to /home');
        return AppRoutes.home;
      }

      // Allow navigation to main application screens (/home, /dashboard, etc.)
      return null;
    },
    routes: [
      // ── Auth routes ─────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const LoginScreen(initialTabIndex: 1),
      ),
      GoRoute(
        path: AppRoutes.pendingVerification,
        builder: (_, __) => const EmailVerificationPendingScreen(),
      ),

      // ── Membership Paywall (onboarding gate) ────────────────────────
      GoRoute(
        path: AppRoutes.membershipPaywall,
        builder: (_, __) => const MembershipPaywallScreen(),
      ),

      // ── Notifications Inbox (full-screen, outside shell) ──────────
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const NotificationsScreen(),
      ),

      // ── Full-screen Modal / Sub-routes (Completely OUTSIDE ShellRoute) ──
      GoRoute(
        path: AppRoutes.editProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.notificationPrefs,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const NotificationPrefsScreen(),
      ),
      GoRoute(
        path: AppRoutes.qrDisplay,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const QrDisplayScreen(),
      ),
      GoRoute(
        path: AppRoutes.transactionHistory,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const TransactionHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.linkPhysicalCard,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const LinkPhysicalCardScreen(),
      ),
      GoRoute(
        path: AppRoutes.redeem,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const RedeemScreen(),
      ),
      GoRoute(
        path: AppRoutes.booking,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const BookingScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookingConfirm,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>? ?? {};
          return BookingConfirmScreen(bookingData: data);
        },
      ),

      // ── Main Shell with Bottom Nav Dock ─────────────────────────────
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // Home / Feed
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const HomeScreen(),
          ),

          // Dashboard (Strips Wallet)
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (_, __) => const DashboardScreen(),
          ),

          // Menu
          GoRoute(
            path: AppRoutes.menu,
            builder: (_, __) => const MenuScreen(),
          ),

          // Wallet / Loyalty
          GoRoute(
            path: AppRoutes.loyalty,
            builder: (_, __) => const LoyaltyScreen(),
          ),

          // Reward Store
          GoRoute(
            path: AppRoutes.rewardStore,
            builder: (_, __) => const RewardStoreScreen(),
          ),

          // Bookings / Reservations
          GoRoute(
            path: AppRoutes.myBookings,
            builder: (_, __) => const MyBookingsScreen(),
          ),

          // Profile / Settings
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Root Application Widget (Light Theme)
/// ═══════════════════════════════════════════════════════════════════════════

/// Smooth cross-page transition: gentle fade combined with a subtle upward
/// slide. Replaces the default platform slide-from-right / zoom so navigation
/// feels calm and premium across the whole app.
class _SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class TigerBayApp extends ConsumerWidget {
  const TigerBayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'TigerBay International',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _SmoothPageTransitionsBuilder(),
            TargetPlatform.iOS: _SmoothPageTransitionsBuilder(),
            TargetPlatform.windows: _SmoothPageTransitionsBuilder(),
            TargetPlatform.macOS: _SmoothPageTransitionsBuilder(),
            TargetPlatform.linux: _SmoothPageTransitionsBuilder(),
          },
        ),
      ),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
