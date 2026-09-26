import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tigerbay_app/core/constants/app_routes.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/theme/app_typography.dart';
import 'package:tigerbay_app/features/auth/providers/auth_provider.dart';
import 'package:tigerbay_app/features/auth/providers/profile_state_provider.dart';
import 'package:tigerbay_app/features/auth/providers/register_provider.dart';
import 'package:tigerbay_app/features/auth/widgets/branch_selector_widget.dart';
import 'package:tigerbay_app/shared/widgets/apple_touch_feedback.dart';
import 'package:url_launcher/url_launcher.dart';

/// Combined Login + Registration screen for TigerBay International.
///
/// Modes:
///   - Login  : email + password sign-in OR social sign-in
///   - Register: email + password + full name + branch (home_site_id) sign-up
///
/// The [Branch] chosen during registration is written directly to
/// `profiles.home_site_id` (INT) upon successful auth creation.
class LoginScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const LoginScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  // ── Tab & Animation controllers ──────────────────────────────────────────────
  late final TabController _tabController;
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final AnimationController _sheenController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _tabsFade;
  late final Animation<Offset> _tabsSlide;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;

  // ── Login form ────────────────────────────────────────────────────────────────
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginPasswordObscured = true;

  // ── Register form ─────────────────────────────────────────────────────────────
  final _registerFormKey = GlobalKey<FormState>();
  final _registerFullNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  String _registerCountryCode = '+44';
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  bool _registerPasswordObscured = true;
  bool _registerConfirmObscured = true;

  // ── Branch selection tracking pointer (as specified in the brief) ─────────────
  Branch? chosenHomeSite;

  // ── Form submit flags ─────────────────────────────────────────────────────────
  bool _loginSubmitted = false;
  bool _registerSubmitted = false;

  // ── Brute-force protection & cooldown ─────────────────────────────────────────
  int _failedLoginAttempts = 0;
  int _lockoutSecondsRemaining = 0;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _tabController.addListener(() => setState(() {}));

    // ── Entrance Animation Timeline (1000ms) ─────────────────────────────────
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // ── Ambient Breathing Pulse (3200ms) ─────────────────────────────────────
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    // ── Continuous Sheen Reflection (3000ms) ─────────────────────────────────
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.05, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _tabsFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
    );

    _tabsSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _formFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.4, 0.85, curve: Curves.easeOut),
    );

    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _entranceController.dispose();
    _pulseController.dispose();
    _sheenController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerFullNameController.dispose();
    _registerEmailController.dispose();
    _registerPhoneController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _startLockoutTimer() {
    setState(() => _lockoutSecondsRemaining = 60);
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_lockoutSecondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _lockoutSecondsRemaining = 0;
          _failedLoginAttempts = 0;
        });
      } else {
        setState(() => _lockoutSecondsRemaining--);
      }
    });
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _submitLogin() async {
    if (_lockoutSecondsRemaining > 0) {
      _showErrorSnack('Security lockout: Please wait $_lockoutSecondsRemaining seconds before trying again.');
      return;
    }

    setState(() => _loginSubmitted = true);
    if (!_loginFormKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).signInWithEmail(
          email: _loginEmailController.text.trim(),
          password: _loginPasswordController.text,
        );

    if (!mounted) return;

    if (!success) {
      _failedLoginAttempts++;
      final error = ref.read(authProvider).error ?? '';
      final isUnconfirmed = error.toLowerCase().contains('confirm your email') ||
          error.toLowerCase().contains('email not confirmed');

      if (isUnconfirmed) {
        _showEmailUnconfirmedDialog(
          email: _loginEmailController.text.trim(),
          password: _loginPasswordController.text,
        );
        return;
      }

      if (_failedLoginAttempts >= 5) {
        _startLockoutTimer();
        _showErrorSnack('Too many failed attempts. Sign-in locked for 60 seconds.');
      } else {
        final remaining = 5 - _failedLoginAttempts;
        _showErrorSnack(
          remaining <= 2
              ? '${error.isNotEmpty ? error : 'Invalid email or password.'} ($remaining attempts remaining before security lock)'
              : (error.isNotEmpty ? error : 'Sign-in failed. Please try again.'),
        );
      }
      return;
    }

    // ── Credential Save (Apple Keychain & Google Password Manager) ─────────
    TextInput.finishAutofillContext();
    _failedLoginAttempts = 0;

    // Explicitly load profile to ensure membership status is known
    await ref.read(profileStateProvider.notifier).loadProfile();
    if (!mounted) return;

    final profile = ref.read(profileStateProvider).profile;
    if (profile?.isMembershipActive == true) {
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.membershipPaywall);
    }
  }

  Future<void> _submitRegister() async {
    setState(() => _registerSubmitted = true);
    final formValid = _registerFormKey.currentState!.validate();
    final branchValid = chosenHomeSite != null;

    if (!formValid || !branchValid) {
      if (!branchValid) {
        _showErrorSnack('Please select your home TigerBay venue.');
      }
      return;
    }

    final rawPhone = _registerPhoneController.text.trim();
    final cleanDigits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length < 7) {
      _showErrorSnack('Please enter a valid mobile phone number.');
      return;
    }
    final formattedPhone = '$_registerCountryCode$cleanDigits';
    final email = _registerEmailController.text.trim().toLowerCase();
    final fullName = _registerFullNameController.text.trim();
    final password = _registerPasswordController.text;

    // ── Pre-registration Duplicate Account Check ────────────────────────────
    try {
      final existing = await ref.read(authRepositoryProvider).checkUserExists(
            email: email,
            phone: formattedPhone,
          );

      if (existing != null) {
        final existingEmail = (existing['email'] as String? ?? '').toLowerCase();
        _showAccountAlreadyExistsDialog(
          email: email,
          phone: formattedPhone,
          isEmailMatch: existingEmail == email,
        );
        return;
      }
    } catch (e) {
      debugPrint('[TigerBay Auth] Duplicate check notice: $e');
    }

    // ── Proceed to Dual-Factor Verification (SMS OTP + Email OTP) ───────────
    if (!mounted) return;
    ref.read(registrationDraftProvider.notifier).setDraft(
          fullName: fullName,
          email: email,
          phone: formattedPhone,
          password: password,
          homeSite: chosenHomeSite!,
          stage: 0,
        );
    context.go(
      AppRoutes.registrationVerification,
      extra: {
        'fullName': fullName,
        'email': email,
        'phone': formattedPhone,
        'password': password,
        'homeSite': chosenHomeSite!,
      },
    );
  }

  void _showAccountAlreadyExistsDialog({
    required String email,
    required String phone,
    required bool isEmailMatch,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF16161A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF33333D), width: 1.2),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A42),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                ),
                child: const Icon(
                  CupertinoIcons.person_badge_minus_fill,
                  color: AppColors.gold,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Account Already Exists',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isEmailMatch
                    ? 'An account is already registered with $email. Please sign in to access your profile.'
                    : 'An account is already registered with $phone. Please sign in to access your profile.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(modalContext).pop();
                    _tabController.animateTo(0);
                    _loginEmailController.text = email;
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'SIGN IN TO YOUR ACCOUNT',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF16161A),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(modalContext).pop();
                    context.go(AppRoutes.forgotPassword, extra: email);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF33333D)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'FORGOT PASSWORD?',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.champagneGold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEmailUnconfirmedDialog({
    required String email,
    required String password,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF16161A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF33333D), width: 1.2),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A42),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                ),
                child: const Icon(
                  CupertinoIcons.mail_solid,
                  color: AppColors.gold,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Email Verification Required',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your account for $email was registered, but your email address has not been confirmed yet. Enter your verification code to complete sign in.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(modalContext).pop();
                    try {
                      await Supabase.instance.client.auth.resend(
                        type: OtpType.signup,
                        email: email,
                      );
                    } catch (_) {}

                    ref.read(registrationDraftProvider.notifier).setDraft(
                          fullName: '',
                          email: email,
                          phone: '',
                          password: password,
                          homeSite: chosenHomeSite ??
                              const Branch(
                                id: 1,
                                title: 'TigerBay Kingsbury',
                                imageUrl: '',
                                address: 'Kingsbury, London',
                                isActive: true,
                              ),
                          stage: 1,
                        );

                    if (!mounted) return;
                    context.go(
                      AppRoutes.registrationVerification,
                      extra: {
                        'email': email,
                        'password': password,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'ENTER VERIFICATION CODE',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF16161A),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(modalContext).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF33333D)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _socialSignIn(SocialProvider provider) async {
    final notifier = ref.read(authProvider.notifier);
    switch (provider) {
      case SocialProvider.google:
        await notifier.signInWithGoogle();
      case SocialProvider.apple:
        await notifier.signInWithApple();
      case SocialProvider.facebook:
        await notifier.signInWithFacebook();
    }
    if (!mounted) return;
    final error = ref.read(authProvider).error;
    if (error != null) _showErrorSnack(error);
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
    ref.read(authProvider.notifier).clearError();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.error != null && mounted) {
        final err = next.error!.toLowerCase();
        final isUnconfirmed = err.contains('confirm your email') ||
            err.contains('email not confirmed') ||
            err.contains('email_not_confirmed');
        if (!isUnconfirmed) {
          _showErrorSnack(next.error!);
        }
      }
      if (next.status == AuthStatus.authenticated && mounted) {
        context.go(AppRoutes.home);
      }
    });

    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF08080A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Ambient Luxury Glow Layer ──────────────────────────────────────
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final pulse = 0.85 + (_pulseController.value * 0.15);
              return Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.65),
                      radius: 0.95,
                      colors: [
                        AppColors.brandRed.withValues(alpha: 0.20 * pulse),
                        AppColors.gold.withValues(alpha: 0.08 * pulse),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),

                // ── Animated Logo & Brand Header ─────────────────────────────
                SlideTransition(
                  position: _headerSlide,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: _buildLogoHeader(),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // ── Animated Segmented Tab Bar ───────────────────────────────
                SlideTransition(
                  position: _tabsSlide,
                  child: FadeTransition(
                    opacity: _tabsFade,
                    child: _buildTabBar(),
                  ),
                ),
                const SizedBox(height: 6),

                // ── Animated Forms ───────────────────────────────────────────
                Expanded(
                  child: SlideTransition(
                    position: _formSlide,
                    child: FadeTransition(
                      opacity: _formFade,
                      child: Stack(
                        children: [
                          TabBarView(
                            controller: _tabController,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              _buildLoginForm(authState),
                              _buildRegisterForm(authState),
                            ],
                          ),
                          if (authState.isLoading)
                            const Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: LinearProgressIndicator(
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                                minHeight: 2,
                              ),
                            ),
                        ],
                      ),
                    ),
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

  // ── Logo header ──────────────────────────────────────────────────────────────

  Widget _buildLogoHeader() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final glowPulse = _pulseController.value;
            return Container(
              width: 98,
              height: 98,
              decoration: BoxDecoration(
                color: AppColors.brandBlack,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.35 + (glowPulse * 0.25)),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandRed.withValues(alpha: 0.24 + (glowPulse * 0.16)),
                    blurRadius: 26 + (glowPulse * 10),
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.14 + (glowPulse * 0.08)),
                    blurRadius: 18 + (glowPulse * 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/tigerbay_logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    CupertinoIcons.paw,
                    size: 42,
                    color: AppColors.brandRed,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          'TigerBay',
          style: GoogleFonts.cinzel(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.5,
            color: Colors.white,
            shadows: [
              Shadow(
                color: AppColors.brandRed.withValues(alpha: 0.5),
                blurRadius: 18,
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'INTERNATIONAL',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 4.5,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Member Access',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Tab bar (Apple Segmented Capsule) ────────────────────────────────────────

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF131316),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: const Color(0xFF28282E),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2B2B33), Color(0xFF1E1E24)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.4),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.12),
                blurRadius: 8,
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppColors.champagneGold,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Sign In'),
            Tab(text: 'Register'),
          ],
        ),
      ),
    );
  }

  // ── Login form ───────────────────────────────────────────────────────────────

  Widget _buildLoginForm(AuthState authState) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Form(
        key: _loginFormKey,
        autovalidateMode: _loginSubmitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Email ───────────────────────────────────────────────────────────
              _buildFieldLabel('EMAIL ADDRESS'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _loginEmailController,
                hint: 'your@email.com',
                inputType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email, AutofillHints.username],
                prefixIcon: CupertinoIcons.mail,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email address';
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // ── Password ────────────────────────────────────────────────────────
              _buildFieldLabel('PASSWORD'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _loginPasswordController,
                hint: 'Enter your password',
                obscure: _loginPasswordObscured,
                autofillHints: const [AutofillHints.password],
                prefixIcon: CupertinoIcons.lock,
                suffixIcon: IconButton(
                  icon: Icon(
                    _loginPasswordObscured
                        ? CupertinoIcons.eye
                        : CupertinoIcons.eye_slash,
                    size: 20,
                    color: AppColors.textHint,
                  ),
                  onPressed: () => setState(
                      () => _loginPasswordObscured = !_loginPasswordObscured),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  return null;
                },
              ),

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _openForgotPassword,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: AppTypography.caption1.copyWith(
                      color: AppColors.champagneGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Security Lockout Banner (Brute-Force Protection) ─────────────
              if (_lockoutSecondsRemaining > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.lock_shield_fill, color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Security lockout active. Try again in ${_lockoutSecondsRemaining}s',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Sign In button ──────────────────────────────────────────────────
              _buildPrimaryButton(
                label: _lockoutSecondsRemaining > 0
                    ? 'LOCKED (${_lockoutSecondsRemaining}s)'
                    : 'Sign In',
                isLoading: authState.isLoading,
                onTap: _lockoutSecondsRemaining > 0 ? () {} : _submitLogin,
              ),

              const SizedBox(height: 24),
              _buildSocialDivider(),
              const SizedBox(height: 16),
              _buildSocialButtons(authState),

              const SizedBox(height: 24),
              _buildTermsFooter(),
            ],
          ),
        ),
      ),
    );
  }

  void _openForgotPassword() {
    final email = _loginEmailController.text.trim();
    context.go(AppRoutes.forgotPassword, extra: email.isNotEmpty ? email : null);
  }

  // ── Register form ─────────────────────────────────────────────────────────────

  Widget _buildRegisterForm(AuthState authState) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Form(
        key: _registerFormKey,
        autovalidateMode: _registerSubmitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Full Name ───────────────────────────────────────────────────────
              _buildFieldLabel('FULL NAME'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _registerFullNameController,
                hint: 'Your full name',
                inputType: TextInputType.name,
                autofillHints: const [AutofillHints.name],
                prefixIcon: CupertinoIcons.person,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Full name is required';
                  if (v.trim().length < 2) return 'Enter at least 2 characters';
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // ── Email ───────────────────────────────────────────────────────────
              _buildFieldLabel('EMAIL ADDRESS'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _registerEmailController,
                hint: 'your@email.com',
                inputType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email, AutofillHints.username],
                prefixIcon: CupertinoIcons.mail,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email address';
                  return null;
                },
              ),

            const SizedBox(height: 18),

            // ── Phone Number ────────────────────────────────────────────────────
            _buildFieldLabel('MOBILE PHONE NUMBER'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16161A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _registerSubmitted &&
                          _registerPhoneController.text.trim().length < 7
                      ? AppColors.error
                      : const Color(0xFF2C2C35),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _registerCountryCode,
                      dropdownColor: const Color(0xFF222228),
                      icon: const Icon(CupertinoIcons.chevron_down,
                          size: 14, color: AppColors.champagneGold),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      items: const [
                        DropdownMenuItem(value: '+44', child: Text('🇬🇧 +44')),
                        DropdownMenuItem(value: '+971', child: Text('🇦🇪 +971')),
                        DropdownMenuItem(value: '+1', child: Text('🇺🇸 +1')),
                        DropdownMenuItem(value: '+91', child: Text('🇮🇳 +91')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _registerCountryCode = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 24, color: const Color(0xFF33333D)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _registerPhoneController,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: '7123 456789',
                        hintStyle: TextStyle(color: Color(0xFF6E6E78)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        final digits = v.replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 7) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Password ────────────────────────────────────────────────────────
            _buildFieldLabel('PASSWORD'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _registerPasswordController,
              hint: 'Create a password',
              obscure: _registerPasswordObscured,
              autofillHints: const [AutofillHints.newPassword],
              prefixIcon: CupertinoIcons.lock,
              onChanged: (_) => setState(() {}),
              suffixIcon: IconButton(
                icon: Icon(
                  _registerPasswordObscured
                      ? CupertinoIcons.eye
                      : CupertinoIcons.eye_slash,
                  size: 20,
                  color: AppColors.textHint,
                ),
                onPressed: () => setState(() =>
                    _registerPasswordObscured = !_registerPasswordObscured),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 8) return 'Password must be at least 8 characters';
                return null;
              },
            ),
            _buildPasswordStrengthMeter(_registerPasswordController.text),

            const SizedBox(height: 18),

            // ── Confirm Password ────────────────────────────────────────────────
            _buildFieldLabel('CONFIRM PASSWORD'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _registerConfirmPasswordController,
              hint: 'Re-enter your password',
              obscure: _registerConfirmObscured,
              autofillHints: const [AutofillHints.newPassword],
              prefixIcon: CupertinoIcons.lock,
              suffixIcon: IconButton(
                icon: Icon(
                  _registerConfirmObscured
                      ? CupertinoIcons.eye
                      : CupertinoIcons.eye_slash,
                  size: 20,
                  color: AppColors.textHint,
                ),
                onPressed: () => setState(
                    () => _registerConfirmObscured = !_registerConfirmObscured),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm your password';
                if (v != _registerPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),

            const SizedBox(height: 18),

            // ── Home Location Selector (Branch → home_site_id: INT) ─────────────
            _buildFieldLabel('HOME LOCATION'),
            const SizedBox(height: 8),
            BranchSelectorWidget(
              selectedBranch: chosenHomeSite,
              onChanged: (branch) => setState(() => chosenHomeSite = branch),
              showError: _registerSubmitted && chosenHomeSite == null,
              label: '',
              hint: 'Select your nearest TigerBay venue',
            ),

            const SizedBox(height: 28),

            // ── Create Account button ───────────────────────────────────────────
            _buildPrimaryButton(
              label: 'Create Account',
              isLoading: authState.isLoading,
              onTap: _submitRegister,
            ),

            const SizedBox(height: 24),
            _buildTermsFooter(),
          ],
        ),
      ),
    ),
    );
  }

  // ── Shared UI helpers ─────────────────────────────────────────────────────────

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: AppTypography.caption1.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType inputType = TextInputType.text,
    bool obscure = false,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    Iterable<String>? autofillHints,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      obscureText: obscure,
      onChanged: onChanged,
      autofillHints: autofillHints,
      style: AppTypography.body.copyWith(
        color: AppColors.textPrimary,
      ),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.body.copyWith(
          color: AppColors.textHint,
        ),
        filled: true,
        fillColor: const Color(0xFF141416),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: AppColors.textHint)
            : null,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF28282B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF28282B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppColors.champagneGold, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        errorStyle: AppTypography.caption1.copyWith(
          color: AppColors.error,
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthMeter(String password) {
    if (password.isEmpty) return const SizedBox.shrink();

    final bool hasMinLength = password.length >= 8;
    final bool hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final bool hasLower = RegExp(r'[a-z]').hasMatch(password);
    final bool hasNumberOrSpecial =
        RegExp(r'[0-9!@#\$&*~%^()_+=<>?]').hasMatch(password);

    final int score = (hasMinLength ? 1 : 0) +
        (hasUpper ? 1 : 0) +
        (hasLower ? 1 : 0) +
        (hasNumberOrSpecial ? 1 : 0);

    Color strengthColor;
    String strengthLabel;
    switch (score) {
      case 1:
        strengthColor = const Color(0xFFE53935);
        strengthLabel = 'Weak';
        break;
      case 2:
        strengthColor = const Color(0xFFFB8C00);
        strengthLabel = 'Fair';
        break;
      case 3:
        strengthColor = AppColors.gold;
        strengthLabel = 'Good';
        break;
      case 4:
        strengthColor = const Color(0xFF43A047);
        strengthLabel = 'Strong';
        break;
      default:
        strengthColor = Colors.white24;
        strengthLabel = '';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: List.generate(4, (index) {
                    final isFilled = index < score;
                    return Expanded(
                      child: Container(
                        height: 3.5,
                        margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                        decoration: BoxDecoration(
                          color: isFilled ? strengthColor : const Color(0xFF28282E),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                strengthLabel,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: strengthColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildRuleChip('8+ chars', hasMinLength),
              _buildRuleChip('Uppercase', hasUpper),
              _buildRuleChip('Lowercase', hasLower),
              _buildRuleChip('Number/Symbol', hasNumberOrSpecial),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRuleChip(String text, bool isMet) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isMet
              ? CupertinoIcons.checkmark_circle_fill
              : CupertinoIcons.circle,
          size: 12,
          color: isMet ? const Color(0xFF43A047) : Colors.white30,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            color: isMet ? Colors.white70 : Colors.white38,
            fontWeight: isMet ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return AppleTouchFeedback(
      onTap: isLoading ? null : onTap,
      child: AnimatedBuilder(
        animation: _sheenController,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE5C068), Color(0xFFD4AF37), Color(0xFFB38927)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(27),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: Stack(
                children: [
                  // Continuous subtle diagonal sheen reflection
                  Positioned.fill(
                    child: FractionalTranslation(
                      translation: Offset((_sheenController.value * 3.0) - 1.0, 0),
                      child: Transform.rotate(
                        angle: 0.3,
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.28),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      label,
                      key: ValueKey(label),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        fontSize: 16,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSocialDivider() {
    return Row(
      children: [
        const Expanded(
            child: Divider(color: Color(0xFF28282B), height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR CONTINUE WITH',
            style: AppTypography.caption2.copyWith(
              letterSpacing: 1.2,
              color: AppColors.textHint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(
            child: Divider(color: Color(0xFF28282B), height: 1)),
      ],
    );
  }

  Widget _buildSocialButtons(AuthState authState) {
    return Column(
      children: [
        _SocialButton(
          label: 'Continue with Google',
          iconWidget: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: const Center(
              child: Text(
                'G',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.googleBlue,
                ),
              ),
            ),
          ),
          onTap: authState.isLoading
              ? null
              : () => _socialSignIn(SocialProvider.google),
        ),
        const SizedBox(height: 12),
        _SocialButton(
          label: 'Continue with Apple',
          iconWidget: const Icon(
            Icons.apple,
            size: 24,
            color: Colors.white,
          ),
          onTap: authState.isLoading
              ? null
              : () => _socialSignIn(SocialProvider.apple),
        ),
        const SizedBox(height: 12),
        _SocialButton(
          label: 'Continue with Facebook',
          iconWidget: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.facebookBlue,
            ),
            child: const Center(
              child: Text(
                'f',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          onTap: authState.isLoading
              ? null
              : () => _socialSignIn(SocialProvider.facebook),
        ),
      ],
    );
  }

  Widget _buildTermsFooter() {
    Future<void> launchLegalUrl(String url) async {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }

    Widget buildLegalLink(String title, String url) {
      return AppleTouchFeedback(
        onTap: () => launchLegalUrl(url),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.champagneGold,
              letterSpacing: 0.1,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131316),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.champagneGold.withValues(alpha: 0.18),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.lock_shield_fill,
                size: 13,
                color: AppColors.champagneGold.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Text(
                'TIGERBAY MEMBERSHIP & COMPLIANCE',
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.champagneGold.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'By continuing, you agree to our club policies & terms:',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            runSpacing: 2,
            children: [
              buildLegalLink(
                'Terms & Conditions',
                'https://www.tigerbayshisha.co.uk/terms-conditions.html',
              ),
              Text(
                '•',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint.withValues(alpha: 0.6),
                ),
              ),
              buildLegalLink(
                'Privacy Policy',
                'https://www.tigerbayshisha.co.uk/privacy-policy.html',
              ),
              Text(
                '•',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint.withValues(alpha: 0.6),
                ),
              ),
              buildLegalLink(
                'House Rules',
                'https://www.tigerbayshisha.co.uk/house-rules.html',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Social login button ───────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget iconWidget;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.label,
    required this.iconWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppleTouchFeedback(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF28282B), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            SizedBox(width: 28, child: iconWidget),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTypography.subheadline.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 16, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

// ── Enum ──────────────────────────────────────────────────────────────────────

enum SocialProvider { google, apple, facebook }
