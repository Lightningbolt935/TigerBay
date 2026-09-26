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
import 'package:tigerbay_app/features/auth/providers/register_provider.dart';

// ── 3. Navigation Shell ──────────────────────────────────────────────────────
import 'package:tigerbay_app/shared/widgets/main_shell.dart';

// ── 4. Auth & Onboarding Screens ─────────────────────────────────────────────
import 'package:tigerbay_app/features/auth/screens/splash_screen.dart';
import 'package:tigerbay_app/features/auth/screens/login_screen.dart';
import 'package:tigerbay_app/features/auth/screens/otp_screen.dart';
import 'package:tigerbay_app/features/auth/screens/email_verification_pending_screen.dart';
import 'package:tigerbay_app/features/auth/screens/forgot_password_screen.dart';
import 'package:tigerbay_app/features/auth/screens/registration_verification_screen.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
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
import 'package:tigerbay_app/data/models/booking_model.dart';

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

  // ── Auth Status Listener ───────────────────────────────────────────────
  ref.listen<AuthStatus>(authStatusProvider, (previous, next) {
    if (previous != next) {
      debugPrint(
        '[TigerBay Router] Auth status changed: $previous → $next',
      );

      // CRITICAL: When the user enters their phone OTP and Supabase registers the
      // account, authStatus transitions to pendingEmailVerification.
      // If the user is currently on registrationVerification, DO NOT trigger a
      // GoRouter refresh! That would tear down or rebuild the active widget tree
      // right when the screen is switching internally to Email OTP.
      final currentCtx = rootNavigatorKey.currentContext;
      if (currentCtx != null) {
        try {
          final loc = GoRouter.of(currentCtx).routeInformationProvider.value.uri.path;
          if (loc == AppRoutes.registrationVerification &&
              next == AuthStatus.pendingEmailVerification) {
            debugPrint(
              '[TigerBay Router] RegistrationVerificationScreen active; skipping router refresh.',
            );
            return;
          }
        } catch (_) {}
      }

      refreshNotifier.refresh();
    }
  });

  // ── Profile State Listener ─────────────────────────────────────────────
  ref.listen<ProfileState>(profileStateProvider, (previous, next) {
    final prevReady = previous?.isReady ?? false;
    final nextReady = next.isReady;
    final prevStatus = previous?.profile?.membershipStatus;
    final nextStatus = next.profile?.membershipStatus;
    final prevTierId = previous?.profile?.membershipTierId;
    final nextTierId = next.profile?.membershipTierId;

    if (prevReady != nextReady ||
        prevStatus != nextStatus ||
        prevTierId != nextTierId ||
        previous?.loadStatus != next.loadStatus) {
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
      final profile = profileState.profile;
      final isMembershipActive = profile?.isMembershipActive ?? false;
      final isMembershipExpired = profile?.isMembershipExpired ?? false;

      debugPrint(
        '[TigerBay Router] Redirect check — '
        'loc=$loc, auth=$authStatus, '
        'active=$isMembershipActive, expired=$isMembershipExpired, '
        'profileReady=${profileState.isReady}',
      );

      // ── Gate 0: Unknown Auth State (Cold Start) ───────────────────────
      if (authStatus == AuthStatus.unknown) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // ── Sanctuary Route: In-flight Verification Flows ─────────────────
      // If the user is on the forgot-password or registration-verification screen,
      // NEVER redirect them away or reload it while in-flight.
      if (loc == AppRoutes.forgotPassword ||
          loc == AppRoutes.registrationVerification) {
        return null;
      }

      final isAuthenticated = authStatus == AuthStatus.authenticated;
      final isPendingEmail = authStatus == AuthStatus.pendingEmailVerification;

      // ── Gate 1: Email Verification Pending ─────────────────────────────
      // TigerBay uses 2-step OTP verification on RegistrationVerificationScreen.
      // NEVER redirect to the old link-based pendingVerification screen!
      if (isPendingEmail) {
        if (loc == AppRoutes.registrationVerification ||
            loc == AppRoutes.forgotPassword ||
            loc == AppRoutes.membershipPaywall) {
          return null;
        }
        return AppRoutes.registrationVerification;
      }

      // ── Gate 1.5: Password Recovery Event ─────────────────────────────
      if (authStatus == AuthStatus.passwordRecovery) {
        return loc == AppRoutes.forgotPassword ? null : AppRoutes.forgotPassword;
      }

      // ── Gate 2: Unauthenticated User ──────────────────────────────────
      if (!isAuthenticated) {
        final isOnAuthRoute = loc == AppRoutes.login ||
            loc == AppRoutes.otp ||
            loc == AppRoutes.register ||
            loc == AppRoutes.splash ||
            loc == AppRoutes.pendingVerification ||
            loc == AppRoutes.forgotPassword ||
            loc == AppRoutes.registrationVerification ||
            loc == AppRoutes.membershipPaywall;

        return isOnAuthRoute ? null : AppRoutes.login;
      }

      // ── Gate 3: Authenticated — Profile Loading Guard ─────────────────
      // If cold-starting on splash, wait on splash until ready.
      if (!profileState.isReady) {
        if (loc == AppRoutes.splash) return null;
        if (loc == AppRoutes.membershipPaywall) return null;
        if (loc == AppRoutes.login || loc == AppRoutes.register) {
          // Authenticated user on login/register screen — immediately send to home or paywall
          return (!isMembershipActive || isMembershipExpired)
              ? AppRoutes.membershipPaywall
              : AppRoutes.home;
        }
        if (profileState.loadStatus == ProfileLoadStatus.error) {
          debugPrint(
              '[TigerBay Router] Profile error — allowing home with fallback.');
          return loc == AppRoutes.home ? null : AppRoutes.home;
        }
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // ── Gate 4: Membership Wall Guard ─────────────────────────────────
      // TigerBay requires an active membership to access club features (/home, /booking, etc.).
      // If the user's membership is inactive or expired:
      // They MUST ONLY be able to view the membership wall (/membership-paywall).
      // They can NEVER access their dashboard or club tabs until membership is active.
      if (!isMembershipActive || isMembershipExpired) {
        if (loc == AppRoutes.membershipPaywall ||
            loc == AppRoutes.forgotPassword ||
            loc == AppRoutes.registrationVerification) {
          return null; // Stay on paywall, forgot password, or registration verification
        }
        debugPrint(
          '[TigerBay Router] Inactive/expired member (active=$isMembershipActive, expired=$isMembershipExpired) '
          'attempted to visit $loc → routing to membership paywall.',
        );
        return AppRoutes.membershipPaywall;
      }

      // ── Gate 5: Active Member Route Cleanup ────────────────────────────
      // If user is currently resetting password on forgotPassword, NEVER kick them out!
      if (loc == AppRoutes.forgotPassword) {
        return null;
      }

      // If authenticated member with active plan is on auth/onboarding screens, send them Home.
      final isOnOnboardingOrAuthRoute = loc == AppRoutes.login ||
          loc == AppRoutes.register ||
          loc == AppRoutes.splash ||
          loc == AppRoutes.otp ||
          loc == AppRoutes.registrationVerification;

      if (isOnOnboardingOrAuthRoute) {
        debugPrint(
            '[TigerBay Router] Active authenticated member on onboarding route → Redirecting to /home');
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
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) {
          final email = state.extra as String?;
          return ForgotPasswordScreen(initialEmail: email);
        },
      ),
      GoRoute(
        path: AppRoutes.registrationVerification,
        builder: (context, state) {
          final extraMap = state.extra is Map ? (state.extra as Map) : null;
          final draft = ref.read(registrationDraftProvider);

          final rawFullName = extraMap?['fullName']?.toString();
          final fullName = (rawFullName != null && rawFullName.trim().isNotEmpty)
              ? rawFullName.trim()
              : draft.fullName;

          final rawEmail = extraMap?['email']?.toString();
          final email = (rawEmail != null && rawEmail.trim().isNotEmpty)
              ? rawEmail.trim()
              : draft.email;

          final rawPhone = extraMap?['phone']?.toString();
          final phone = (rawPhone != null && rawPhone.trim().isNotEmpty)
              ? rawPhone.trim()
              : draft.phone;

          final rawPassword = extraMap?['password']?.toString();
          final password = (rawPassword != null && rawPassword.isNotEmpty)
              ? rawPassword
              : draft.password;

          Branch parseBranch(dynamic val) {
            if (val is Branch) return val;
            if (val is Map) {
              try {
                return Branch.fromJson(Map<String, dynamic>.from(val));
              } catch (e) {
                debugPrint('[TigerBay Router] Branch parse error: $e');
              }
            }
            return draft.homeSite ?? Branch.defaultBranches.first;
          }

          final homeSite = parseBranch(extraMap?['homeSite']);

          return RegistrationVerificationScreen(
            key: const ValueKey('registration_verification_screen_key'),
            fullName: fullName,
            email: email,
            phone: phone,
            password: password,
            homeSite: homeSite,
          );
        },
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
      GoRoute(
        path: '${AppRoutes.bookingDetail}/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          BookingModel? booking;
          if (state.extra is BookingModel) {
            booking = state.extra as BookingModel;
          } else if (state.extra is Map) {
            try {
              booking = BookingModel.fromJson(Map<String, dynamic>.from(state.extra as Map));
            } catch (_) {}
          }
          return BookingDetailScreen(bookingId: id, initialBooking: booking);
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
