import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_state_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TigerBay International — Email Verification Pending Screen
// ═══════════════════════════════════════════════════════════════════════════
// Shown when:
//   AuthStatus == pendingEmailVerification
//   (i.e. email_confirmed_at IS NULL on the current user)
//
// Automatically refreshes when the user switches back from their email app,
// polls every 3 seconds, and provides a manual "I'VE CONFIRMED MY EMAIL" button.
// ═══════════════════════════════════════════════════════════════════════════

class EmailVerificationPendingScreen extends ConsumerStatefulWidget {
  const EmailVerificationPendingScreen({super.key});

  @override
  ConsumerState<EmailVerificationPendingScreen> createState() =>
      _EmailVerificationPendingScreenState();
}

class _EmailVerificationPendingScreenState
    extends ConsumerState<EmailVerificationPendingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ── Animation ──────────────────────────────────────────────────────────────
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _fadeAnimation;

  // ── Resend throttle ────────────────────────────────────────────────────────
  bool _isSendingResend = false;
  bool _resentSuccessfully = false;
  int _resendCooldownSeconds = 0;

  // ── Auto-polling & Lifecycle Verification ──────────────────────────────────
  Timer? _pollingTimer;
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[TigerBay EmailPending] App resumed from background. Checking email confirmation status...');
      _checkVerificationStatus(silent: true);
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _checkVerificationStatus(silent: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkVerificationStatus({bool silent = false}) async {
    if (_isCheckingStatus) return;
    if (!silent) setState(() => _isCheckingStatus = true);

    try {
      final confirmed = await ref.read(authProvider.notifier).checkEmailConfirmed();
      if (confirmed && mounted) {
        _pollingTimer?.cancel();
        _showSnack('Email confirmed! Welcome to TigerBay ✓', isError: false);
        ref.invalidate(profileStateProvider);
      } else if (!silent && mounted) {
        _showSnack(
          'Email not yet confirmed. Please tap the verification link in your inbox.',
          isError: true,
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        _showSnack('Could not check confirmation status. Please try again.', isError: true);
      }
    } finally {
      if (mounted && !silent) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  // ── Resend email ───────────────────────────────────────────────────────────

  Future<void> _resendVerificationEmail() async {
    if (_isSendingResend || _resendCooldownSeconds > 0) return;

    setState(() => _isSendingResend = true);

    try {
      final email = ref.read(pendingEmailProvider);
      if (email.isEmpty) {
        _showSnack('No email address found. Please sign up again.', isError: true);
        return;
      }

      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: 'io.tigerbay.app://login-callback',
      );

      setState(() {
        _resentSuccessfully = true;
        _resendCooldownSeconds = 60;
      });

      _showSnack('Verification email resent to $email ✓', isError: false);
      _startCooldownTimer();
    } on AuthException catch (e) {
      _showSnack('Resend failed: ${e.message}', isError: true);
    } catch (e) {
      _showSnack('Could not resend. Please try again.', isError: true);
    } finally {
      setState(() => _isSendingResend = false);
    }
  }

  void _startCooldownTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_resendCooldownSeconds > 0) _resendCooldownSeconds--;
      });
      return _resendCooldownSeconds > 0;
    });
  }

  // ── Sign out and go back ───────────────────────────────────────────────────

  Future<void> _goBackToLogin() async {
    _pollingTimer?.cancel();
    await ref.read(authProvider.notifier).signOut();
    if (mounted) context.go(AppRoutes.login);
  }

  // ── SnackBar helper ────────────────────────────────────────────────────────

  void _showSnack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(pendingEmailProvider);

    // If the user confirmed their email while on this screen, GoRouter's
    // redirect will handle navigation. This listener triggers a rebuild
    // so the router re-evaluates immediately.
    ref.listen<AuthStatus>(authStatusProvider, (previous, next) {
      if (next == AuthStatus.authenticated && mounted) {
        // Router redirect picks this up automatically — no manual navigation.
        debugPrint(
          '[TigerBay VerificationScreen] Email confirmed! '
          'Router redirect will gate user to home.',
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // ── Animated envelope icon ─────────────────────────────────
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.25),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_rounded,
                      size: 56,
                      color: AppColors.gold,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // ── Heading ────────────────────────────────────────────────
                const Text(
                  'Check Your Inbox',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 12),

                // ── Sub-heading ────────────────────────────────────────────
                const Text(
                  'We sent a verification link to',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 4),

                // ── Email pill ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    email.isEmpty ? 'your email address' : email,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Instructions card ─────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _instructionRow(
                        icon: Icons.email_rounded,
                        text: 'Open the email from TigerBay',
                      ),
                      const SizedBox(height: 14),
                      _instructionRow(
                        icon: Icons.touch_app_rounded,
                        text: 'Tap the "Confirm Email" button',
                      ),
                      const SizedBox(height: 14),
                      _instructionRow(
                        icon: Icons.lock_open_rounded,
                        text: 'You\'ll be returned here automatically',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Spam note ─────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Check your spam or junk folder if not visible.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Primary: Check Confirmation Status Button ─────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    key: const ValueKey('confirm_email_status_button'),
                    onPressed: _isCheckingStatus
                        ? null
                        : () => _checkVerificationStatus(silent: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.brandBlack,
                      elevation: 6,
                      shadowColor: AppColors.gold.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: _isCheckingStatus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: AppColors.brandBlack,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 20),
                    label: Text(
                      _isCheckingStatus
                          ? 'CHECKING VERIFICATION...'
                          : 'I\'VE CONFIRMED MY EMAIL',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Resend button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    key: const ValueKey('resend_verification_button'),
                    onPressed: (_isSendingResend || _resendCooldownSeconds > 0)
                        ? null
                        : _resendVerificationEmail,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.45),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isSendingResend
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.gold,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _resendCooldownSeconds > 0
                                ? 'Resend in ${_resendCooldownSeconds}s'
                                : _resentSuccessfully
                                    ? 'Resend Email Again'
                                    : 'Resend Verification Email',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.gold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Back to login ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    key: const ValueKey('back_to_login_button'),
                    onPressed: _goBackToLogin,
                    child: const Text(
                      'Use a different account',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _instructionRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
