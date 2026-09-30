import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/constants/app_routes.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/features/auth/providers/auth_provider.dart';
import 'package:tigerbay_app/features/auth/providers/profile_state_provider.dart';
import 'package:tigerbay_app/features/auth/providers/register_provider.dart';
import 'package:tigerbay_app/services/twilio_notification_service.dart';
import 'package:tigerbay_app/core/utils/phone_number_helper.dart';
import 'package:tigerbay_app/core/utils/error_sanitizer.dart';
import 'package:tigerbay_app/core/config/demo_mode.dart';

enum _RegStage {
  verifyPhone,
  verifyEmail,
  completed,
}

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Registration Verification Pipeline
/// Enforces dual-factor verification (SMS Phone OTP + Email OTP) during signup.
/// ═══════════════════════════════════════════════════════════════════════════
class RegistrationVerificationScreen extends ConsumerStatefulWidget {
  final String fullName;
  final String email;
  final String phone;
  final String password;
  final Branch? homeSite;

  const RegistrationVerificationScreen({
    super.key,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    this.homeSite,
  });

  @override
  ConsumerState<RegistrationVerificationScreen> createState() =>
      _RegistrationVerificationScreenState();
}

class _RegistrationVerificationScreenState
    extends ConsumerState<RegistrationVerificationScreen> {
  _RegStage _stage = _RegStage.verifyPhone;

  final List<TextEditingController> _phoneOtpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _phoneFocusNodes = List.generate(6, (_) => FocusNode());

  final List<TextEditingController> _emailOtpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _emailFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _errorMessage;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  // ── Robust Draft Fallbacks (Guaranteed never empty across router rebuilds) ───
  String get effectiveEmail {
    if (widget.email.trim().isNotEmpty) return widget.email.trim();
    return ref.read(registrationDraftProvider).email.trim();
  }

  String get effectivePhone {
    if (widget.phone.trim().isNotEmpty) return widget.phone.trim();
    return ref.read(registrationDraftProvider).phone.trim();
  }

  String get effectiveFullName {
    if (widget.fullName.trim().isNotEmpty) return widget.fullName.trim();
    return ref.read(registrationDraftProvider).fullName.trim();
  }

  String get effectivePassword {
    if (widget.password.isNotEmpty) return widget.password;
    return ref.read(registrationDraftProvider).password;
  }

  Branch get effectiveHomeSite {
    return widget.homeSite ??
        ref.read(registrationDraftProvider).homeSite ??
        Branch.defaultBranches.first;
  }

  @override
  void initState() {
    super.initState();

    final draft = ref.read(registrationDraftProvider);
    if (draft.stage == 1) {
      _stage = _RegStage.verifyEmail;
    } else if (draft.stage == 2) {
      _stage = _RegStage.completed;
    }

    for (int i = 0; i < 6; i++) {
      _phoneFocusNodes[i].onKeyEvent = (node, event) =>
          _handleOtpKeyEvent(event, i, _phoneOtpControllers, _phoneFocusNodes);
      _phoneFocusNodes[i].addListener(() {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
      });

      _emailFocusNodes[i].onKeyEvent = (node, event) =>
          _handleOtpKeyEvent(event, i, _emailOtpControllers, _emailFocusNodes);
      _emailFocusNodes[i].addListener(() {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
      });
    }

    // Dispatch initial Phone SMS OTP on entry only if in phone verification stage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_stage == _RegStage.verifyPhone) {
        _sendPhoneOtp();
      }
    });
  }

  KeyEventResult _handleOtpKeyEvent(
    KeyEvent event,
    int index,
    List<TextEditingController> controllers,
    List<FocusNode> focusNodes,
  ) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (controllers[index].text.isEmpty && index > 0) {
        controllers[index - 1].clear();
        focusNodes[index - 1].requestFocus();
        HapticFeedback.selectionClick();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    for (final c in _phoneOtpControllers) {
      c.dispose();
    }
    for (final f in _phoneFocusNodes) {
      f.dispose();
    }
    for (final c in _emailOtpControllers) {
      c.dispose();
    }
    for (final f in _emailFocusNodes) {
      f.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCooldown > 1) {
          _resendCooldown--;
        } else {
          _resendCooldown = 0;
          timer.cancel();
        }
      });
    });
  }

  // ── Phase 1: Send & Verify Phone SMS OTP ────────────────────────────────────
  Future<void> _sendPhoneOtp() async {
    final phone = effectivePhone;
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'No mobile phone number provided for verification.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final twilio = TwilioNotificationService();
      final res = await twilio.sendVerificationCode(to: phone, channel: 'sms');
      if (res['status'] == 'error') {
        final err = res['error']?.toString() ?? 'Could not send SMS verification code.';
        final isTrial = res['isTrialRestriction'] == true ||
            err.toLowerCase().contains('unverified') ||
            err.toLowerCase().contains('compliance') ||
            err.toLowerCase().contains('trusthub');
        if (isTrial) {
          setState(() {
            _isLoading = false;
            _errorMessage = DemoMode.hint ??
                'SMS service is in test mode. Please request a new code and try again.';
          });
          _startCooldown();
          return;
        }
        throw Exception(err);
      }

      setState(() => _isLoading = false);
      _startCooldown();
      if (_phoneFocusNodes.isNotEmpty) {
        _phoneFocusNodes[0].requestFocus();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorSanitizer.format(e);
      });
    }
  }

  Future<void> _handleVerifyPhone() async {
    final code = _phoneOtpControllers.map((c) => c.text.trim()).join();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit SMS code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (DemoMode.isMasterOtp(code)) {
        debugPrint('[Registration] Demo master OTP accepted for phone SMS stage.');
        await _initiateEmailPhase();
        return;
      }

      final phone = effectivePhone;
      final twilio = TwilioNotificationService();
      final approved = await twilio.verifyCode(to: phone, code: code);
      if (!approved) {
        throw const AuthException(
            'The SMS verification code entered is incorrect. Please try again.');
      }

      // Phone is verified! Now initiate Email registration in Supabase
      await _initiateEmailPhase();
    } on AuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorSanitizer.format(e);
      });
    }
  }

  // ── Phase 2: Create Account in Supabase & Dispatch Email OTP ────────────────
  Future<void> _initiateEmailPhase() async {
    try {
      // Persist stage 1 into registration draft
      ref.read(registrationDraftProvider.notifier).setStage(1);

      final success = await ref.read(authProvider.notifier).signUpWithEmail(
            email: effectiveEmail,
            password: effectivePassword,
            fullName: effectiveFullName,
            homeSite: effectiveHomeSite,
            phone: effectivePhone,
          );

      // Save user ID if available
      final user = ref.read(authProvider).user ?? Supabase.instance.client.auth.currentUser;
      if (user != null) {
        ref.read(registrationDraftProvider.notifier).setUserId(user.id);
        // Guarantee profile row is written/updated immediately
        try {
          await Supabase.instance.client.from('profiles').upsert({
            'id': user.id,
            'email': effectiveEmail.trim().toLowerCase(),
            'phone': effectivePhone.trim(),
            'full_name': effectiveFullName.trim(),
            'home_site_id': effectiveHomeSite.id,
            'membership_status': 'inactive',
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('[Registration] Pre-emptive profile upsert notice: $e');
        }
      }

      if (!success) {
        final error = ref.read(authProvider).error ?? '';
        final isAlreadyRegistered = error.toLowerCase().contains('already exists') ||
            error.toLowerCase().contains('already registered') ||
            error.toLowerCase().contains('user already registered');

        if (isAlreadyRegistered) {
          // Account already created in Supabase (e.g. earlier retry) — lookup user ID & trigger OTP resend
          debugPrint('[Registration] Account already created; requesting fresh email OTP code.');
          try {
            final match = await Supabase.instance.client
                .from('profiles')
                .select('id')
                .or('phone.eq.${effectivePhone.trim()},email.ilike.${effectiveEmail.trim().toLowerCase()}')
                .limit(1)
                .maybeSingle();
            if (match != null && match['id'] != null) {
              final uid = match['id'] as String;
              ref.read(registrationDraftProvider.notifier).setUserId(uid);
              await Supabase.instance.client.from('profiles').upsert({
                'id': uid,
                'email': effectiveEmail.trim().toLowerCase(),
                'phone': effectivePhone.trim(),
                'full_name': effectiveFullName.trim(),
                'home_site_id': effectiveHomeSite.id,
                'membership_status': 'inactive',
                'updated_at': DateTime.now().toIso8601String(),
              });
            }
          } catch (_) {}

          try {
            await Supabase.instance.client.auth.resend(
              type: OtpType.signup,
              email: effectiveEmail,
            );
          } catch (_) {}
        } else {
          throw Exception(error.isNotEmpty ? error : 'Registration failed. Please try again.');
        }
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _stage = _RegStage.verifyEmail;
      });
      _startCooldown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _emailFocusNodes.isNotEmpty) {
          _emailFocusNodes[0].requestFocus();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorSanitizer.format(e);
      });
    }
  }

  Future<void> _resendEmailOtp() async {
    if (_resendCooldown > 0) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: effectiveEmail,
      );
      setState(() => _isLoading = false);
      _startCooldown();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification code resent to $effectiveEmail'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorSanitizer.format(e);
      });
    }
  }

  Future<void> _handleVerifyEmail() async {
    final code = _emailOtpControllers.map((c) => c.text.trim()).join();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit email code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = effectiveEmail.trim().toLowerCase();
      final phone = effectivePhone.trim();
      final name = effectiveFullName.trim();
      final homeSiteId = effectiveHomeSite.id;

      // 1. Identify target user ID
      String? targetUserId = ref.read(registrationDraftProvider).userId ??
          Supabase.instance.client.auth.currentUser?.id;

      if (targetUserId == null) {
        try {
          final match = await Supabase.instance.client
              .from('profiles')
              .select('id')
              .or('phone.eq.$phone,email.ilike.$email')
              .limit(1)
              .maybeSingle();
          if (match != null && match['id'] != null) {
            targetUserId = match['id'] as String;
            ref.read(registrationDraftProvider.notifier).setUserId(targetUserId);
          }
        } catch (_) {}
      }

      if (DemoMode.isMasterOtp(code)) {
        debugPrint('[Registration] Demo master OTP accepted for email stage of $email');

        // If password is available in draft, sign in to establish active Supabase session
        if (effectivePassword.isNotEmpty) {
          try {
            final loginRes = await ref.read(authRepositoryProvider).signInWithEmail(
              email: email,
              password: effectivePassword,
            );
            if (loginRes.user != null) {
              targetUserId = loginRes.user!.id;
            }
          } catch (e) {
            debugPrint('[Registration] Master OTP auto-signin notice: $e');
          }
        }

        // Guarantee profile is saved in public.profiles
        if (targetUserId != null) {
          try {
            await Supabase.instance.client.from('profiles').upsert({
              'id': targetUserId,
              'email': email,
              'phone': phone,
              'full_name': name,
              'home_site_id': homeSiteId,
              'membership_status': 'inactive',
              'updated_at': DateTime.now().toIso8601String(),
            });
            ref.read(registrationDraftProvider.notifier).setUserId(targetUserId);
          } catch (e) {
            debugPrint('[Registration] Profile upsert notice: $e');
          }
        }

        ref.read(registrationDraftProvider.notifier).setStage(2);
        ref.read(authProvider.notifier).markRegistrationVerified(
          email: email,
          userId: targetUserId,
        );
        ref.invalidate(profileStateProvider);

        setState(() {
          _isLoading = false;
          _stage = _RegStage.completed;
        });
        return;
      }

      final authRes = await ref.read(authRepositoryProvider).verifyEmailOtp(
            email: email,
            token: code,
          );

      final verifiedUid = authRes.user?.id ?? targetUserId;
      if (verifiedUid != null) {
        // Sync email, phone & name into public.profiles
        try {
          await Supabase.instance.client.from('profiles').upsert({
            'id': verifiedUid,
            'email': email,
            'phone': phone,
            'full_name': name,
            'home_site_id': homeSiteId,
            'membership_status': 'inactive',
            'updated_at': DateTime.now().toIso8601String(),
          });
          ref.read(registrationDraftProvider.notifier).setUserId(verifiedUid);
        } catch (e) {
          debugPrint('[Registration] Profile upsert notice: $e');
        }
      }

      ref.read(registrationDraftProvider.notifier).setStage(2);
      ref.read(authProvider.notifier).markRegistrationVerified(
        email: email,
        userId: verifiedUid,
      );
      ref.invalidate(profileStateProvider);

      setState(() {
        _isLoading = false;
        _stage = _RegStage.completed;
      });
    } on AuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorSanitizer.format(e.message);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorSanitizer.format(e);
      });
    }
  }

  void _onDigitChanged(int index, String val, bool isPhone) {
    final controllers = isPhone ? _phoneOtpControllers : _emailOtpControllers;
    final nodes = isPhone ? _phoneFocusNodes : _emailFocusNodes;

    // ── Handle full 6-digit paste or SMS Autofill (e.g. "123456") ──────────
    if (val.length > 1) {
      final digits = val.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < digits.length && i < 6; i++) {
        controllers[i].text = digits[i];
      }
      if (digits.length >= 6) {
        nodes[5].unfocus();
        HapticFeedback.mediumImpact();
        if (isPhone) {
          _handleVerifyPhone();
        } else {
          _handleVerifyEmail();
        }
      } else if (digits.isNotEmpty) {
        nodes[digits.length.clamp(0, 5)].requestFocus();
      }
      return;
    }

    if (val.isNotEmpty) {
      HapticFeedback.lightImpact();
      if (index < 5) {
        nodes[index + 1].requestFocus();
      } else {
        nodes[index].unfocus();
        HapticFeedback.mediumImpact();
        if (isPhone) {
          _handleVerifyPhone();
        } else {
          _handleVerifyEmail();
        }
      }
    }
  }

  Future<void> _handleBackNavigation() async {
    HapticFeedback.lightImpact();
    if (_stage == _RegStage.verifyEmail) {
      // Step back from email OTP to phone OTP stage
      setState(() => _stage = _RegStage.verifyPhone);
    } else {
      // Aborting verification or leaving "Account Verified!" to sign in later.
      // Must sign out cleanly so GoRouter redirect does not bounce an un-activated session to the membership paywall.
      await ref.read(authProvider.notifier).signOut();
      ref.read(registrationDraftProvider.notifier).clear();
      if (mounted) {
        context.go(AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF08080A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.chevron_back,
                color: Colors.white, size: 22),
            onPressed: _handleBackNavigation,
          ),
          title: Text(
            'Account Verification',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Step Progress Indicator
                _buildProgressHeader(),
                const SizedBox(height: 32),

                // Animated Dynamic Stage View
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.08, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_stage),
                    child: switch (_stage) {
                      _RegStage.verifyPhone => _buildPhoneStage(),
                      _RegStage.verifyEmail => _buildEmailStage(),
                      _RegStage.completed => _buildCompletedStage(),
                    },
                  ),
                ),

                // Error Banner
                if (_errorMessage != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    final isPhoneDone = _stage != _RegStage.verifyPhone;
    final isEmailDone = _stage == _RegStage.completed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2C2C35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Step 1: Phone
          Row(
            children: [
              Icon(
                isPhoneDone
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.phone_fill,
                color: isPhoneDone ? AppColors.success : AppColors.gold,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '1. Phone SMS',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isPhoneDone ? Colors.white70 : AppColors.gold,
                ),
              ),
            ],
          ),
          const Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.white30),
          // Step 2: Email
          Row(
            children: [
              Icon(
                isEmailDone
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.mail_solid,
                color: isEmailDone
                    ? AppColors.success
                    : (_stage == _RegStage.verifyEmail ? AppColors.gold : Colors.white30),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '2. Email Code',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isEmailDone
                      ? Colors.white70
                      : (_stage == _RegStage.verifyEmail ? AppColors.gold : Colors.white30),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 1: Phone Verification ──────────────────────────────────────────────
  Widget _buildPhoneStage() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.gold.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.5),
          ),
          child: const Icon(CupertinoIcons.phone_fill, color: AppColors.gold, size: 30),
        ),
        const SizedBox(height: 20),
        Text(
          'Verify Mobile Phone',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit SMS verification code to\n${PhoneNumberHelper.formatDisplay(effectivePhone)}',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Incorrect mobile number? ',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.pop();
              },
              child: Text(
                'Change',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.gold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // 6-digit OTP fields
        _buildOtpFields(controllers: _phoneOtpControllers, focusNodes: _phoneFocusNodes, isPhone: true),
        const SizedBox(height: 24),

        // Resend
        if (_resendCooldown > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141418),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF282830)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.timer, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Resend code in ${_resendCooldown}s',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          TextButton.icon(
            onPressed: _isLoading ? null : _sendPhoneOtp,
            icon: const Icon(CupertinoIcons.arrow_clockwise, size: 15, color: AppColors.gold),
            label: Text(
              'Resend SMS Code',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
              ),
            ),
          ),

        const SizedBox(height: 24),
        _buildActionButton(
          label: 'VERIFY PHONE NUMBER',
          isLoading: _isLoading,
          onTap: _handleVerifyPhone,
        ),
      ],
    );
  }

  // ── Step 2: Email Verification ──────────────────────────────────────────────
  Widget _buildEmailStage() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.gold.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.5),
          ),
          child: const Icon(CupertinoIcons.mail_solid, color: AppColors.gold, size: 30),
        ),
        const SizedBox(height: 20),
        Text(
          'Verify Email Address',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Phone verified ✓\nNow enter the 6-digit code sent to\n$effectiveEmail',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Incorrect email address? ',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
            GestureDetector(
              onTap: () async {
                HapticFeedback.lightImpact();
                await ref.read(authProvider.notifier).signOut();
                ref.read(registrationDraftProvider.notifier).clear();
                if (mounted) {
                  context.go(AppRoutes.login);
                }
              },
              child: Text(
                'Change',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.gold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // 6-digit OTP fields
        _buildOtpFields(controllers: _emailOtpControllers, focusNodes: _emailFocusNodes, isPhone: false),
        const SizedBox(height: 24),

        // Resend
        if (_resendCooldown > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141418),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF282830)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.timer, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Resend code in ${_resendCooldown}s',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          TextButton.icon(
            onPressed: _isLoading ? null : _resendEmailOtp,
            icon: const Icon(CupertinoIcons.arrow_clockwise, size: 15, color: AppColors.gold),
            label: Text(
              'Resend Email Code',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
              ),
            ),
          ),

        const SizedBox(height: 24),
        _buildActionButton(
          label: 'COMPLETE REGISTRATION',
          isLoading: _isLoading,
          onTap: _handleVerifyEmail,
        ),
      ],
    );
  }

  // ── Step 3: Completed Stage ─────────────────────────────────────────────────
  Widget _buildCompletedStage() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(CupertinoIcons.checkmark_alt, color: AppColors.success, size: 46),
        ),
        const SizedBox(height: 22),
        Text(
          'Account Verified!',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Both your mobile phone and email address are authenticated. Welcome to TigerBay International.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        // Verification Summary Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF141418),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF282830)),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                icon: CupertinoIcons.person_fill,
                label: 'Member Name',
                value: effectiveFullName,
              ),
              const Divider(color: Color(0xFF24242C), height: 20),
              _buildSummaryRow(
                icon: CupertinoIcons.phone_fill,
                label: 'Mobile Phone',
                value: PhoneNumberHelper.formatDisplay(effectivePhone),
                isVerified: true,
              ),
              const Divider(color: Color(0xFF24242C), height: 20),
              _buildSummaryRow(
                icon: CupertinoIcons.mail_solid,
                label: 'Email Address',
                value: effectiveEmail,
                isVerified: true,
              ),
              const Divider(color: Color(0xFF24242C), height: 20),
              _buildSummaryRow(
                icon: CupertinoIcons.location_solid,
                label: 'Home Venue',
                value: effectiveHomeSite.title,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        _buildActionButton(
          label: 'SELECT YOUR MEMBERSHIP',
          isLoading: false,
          onTap: () async {
            HapticFeedback.mediumImpact();
            final uid = ref.read(registrationDraftProvider).userId ??
                Supabase.instance.client.auth.currentUser?.id;
            ref.read(authProvider.notifier).markRegistrationVerified(
                  email: effectiveEmail,
                  userId: uid,
                );
            ref.read(profileStateProvider.notifier).loadProfile();
            context.go(AppRoutes.membershipPaywall);
          },
        ),
        const SizedBox(height: 16),
        Text(
          'An active VIP membership is required to unlock your dashboard and access all club benefits.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    bool isVerified = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.gold),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        if (isVerified) ...[
          const SizedBox(width: 6),
          const Icon(CupertinoIcons.checkmark_circle_fill,
              size: 14, color: AppColors.success),
        ],
      ],
    );
  }

  Widget _buildOtpFields({
    required List<TextEditingController> controllers,
    required List<FocusNode> focusNodes,
    required bool isPhone,
  }) {
    final hasError = _errorMessage != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // 6 boxes with 5 gaps of 8px = 40px total gap
        final boxWidth = ((totalWidth - 40) / 6).clamp(36.0, 50.0);
        final boxHeight = (boxWidth * 1.18).clamp(46.0, 60.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            final isFocused = focusNodes[i].hasFocus;
            final isFilled = controllers[i].text.isNotEmpty;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: boxWidth,
              height: boxHeight,
              decoration: BoxDecoration(
                color: isFocused ? const Color(0xFF191920) : const Color(0xFF141418),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isFocused
                      ? AppColors.gold
                      : hasError
                          ? AppColors.error.withValues(alpha: 0.6)
                          : isFilled
                              ? AppColors.gold.withValues(alpha: 0.45)
                              : const Color(0xFF282830),
                  width: isFocused ? 1.8 : 1.2,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.22),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: TextField(
                controller: controllers[i],
                focusNode: focusNodes[i],
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                textAlign: TextAlign.center,
                maxLength: i == 0 ? 6 : 1,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (val) => _onDigitChanged(i, val, isPhone),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildActionButton({
    required String label,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Color(0xFF16161A),
                  strokeWidth: 2.2,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF16161A),
                  letterSpacing: 1.0,
                ),
              ),
      ),
    );
  }
}
