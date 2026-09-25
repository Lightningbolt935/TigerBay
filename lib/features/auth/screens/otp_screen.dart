import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_state_provider.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Standalone Phone OTP Verification Screen
/// ═══════════════════════════════════════════════════════════════════════════
class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _resendCountdown = 60;
  Timer? _timer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 6; i++) {
      _focusNodes[i].onKeyEvent = (node, event) =>
          _handleOtpKeyEvent(event, i, _controllers, _focusNodes);
      _focusNodes[i].addListener(() {
        if (mounted) setState(() {});
      });
    }
    _startCountdown();
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
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendCountdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendCountdown <= 1) {
        setState(() => _resendCountdown = 0);
        t.cancel();
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  String get _otp => _controllers.map((c) => c.text.trim()).join();

  void _onDigitEntered(int index, String value) {
    setState(() => _errorMessage = null);

    // ── Handle full 6-digit paste or SMS Autofill (e.g. "123456") ──────────
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < digits.length && i < 6; i++) {
        _controllers[i].text = digits[i];
      }
      if (digits.length >= 6) {
        _focusNodes[5].unfocus();
        HapticFeedback.mediumImpact();
        _verify();
      } else if (digits.isNotEmpty) {
        _focusNodes[digits.length.clamp(0, 5)].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty) {
      HapticFeedback.lightImpact();
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        HapticFeedback.mediumImpact();
        _verify();
      }
    }
  }

  Future<void> _verify() async {
    if (_otp.length != 6) {
      HapticFeedback.heavyImpact();
      setState(() => _errorMessage = 'Please enter the 6-digit code.');
      return;
    }

    setState(() => _errorMessage = null);
    final success = await ref.read(authProvider.notifier).verifyOtp(
          phone: widget.phoneNumber,
          token: _otp,
        );

    if (success && mounted) {
      HapticFeedback.mediumImpact();
      final profile = ref.read(profileStateProvider).profile;
      if (profile?.isMembershipActive == true) {
        context.go(AppRoutes.home);
      } else {
        context.go(AppRoutes.membershipPaywall);
      }
    } else if (mounted) {
      HapticFeedback.heavyImpact();
      final error = ref.read(authProvider).error;
      setState(() => _errorMessage = error ?? 'Invalid code. Please try again.');
      ref.read(authProvider.notifier).clearError();
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resend() async {
    if (_resendCountdown > 0) return;
    setState(() => _errorMessage = null);

    try {
      await ref.read(authProvider.notifier).sendOtp(widget.phoneNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'A new verification code has been sent to ${widget.phoneNumber}',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
      _startCountdown();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not resend code: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final hasError = _errorMessage != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF08080A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.chevron_back, size: 22, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.pop();
            },
          ),
          title: Text(
            'Security',
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
                const SizedBox(height: 12),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.phone_fill,
                    color: AppColors.gold,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Verify Your Phone',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit verification code to\n${widget.phoneNumber}',
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
                      'Incorrect phone number? ',
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

                // ── 6-digit Animated Input Boxes ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    final isFocused = _focusNodes[i].hasFocus;
                    final isFilled = _controllers[i].text.isNotEmpty;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: 48,
                      height: 56,
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
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        textAlign: TextAlign.center,
                        maxLength: i == 0 ? 6 : 1,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
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
                        onChanged: (v) => _onDigitEntered(i, v),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 24),

                // ── Resend Timer / Button ────────────────────────────────────
                if (_resendCountdown > 0)
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
                          'Resend code in ${_resendCountdown}s',
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
                    onPressed: auth.isLoading ? null : _resend,
                    icon: const Icon(CupertinoIcons.arrow_clockwise, size: 15, color: AppColors.gold),
                    label: Text(
                      'Resend Code',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // ── Verify Button ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (auth.isLoading || _otp.length != 6) ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.35),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Color(0xFF16161A),
                              strokeWidth: 2.2,
                            ),
                          )
                        : Text(
                            'VERIFY CODE',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF16161A),
                              letterSpacing: 1.0,
                            ),
                          ),
                  ),
                ),

                // ── Error Banner ──────────────────────────────────────────────
                if (_errorMessage != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
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
}
