import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/theme/app_typography.dart';
import 'package:tigerbay_app/features/auth/providers/auth_provider.dart';
import 'package:tigerbay_app/features/auth/widgets/branch_selector_widget.dart';
import 'package:tigerbay_app/shared/widgets/apple_touch_feedback.dart';

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
    with SingleTickerProviderStateMixin {
  // ── Tab animation ────────────────────────────────────────────────────────────
  late final TabController _tabController;

  // ── Login form ────────────────────────────────────────────────────────────────
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginPasswordObscured = true;

  // ── Register form ─────────────────────────────────────────────────────────────
  final _registerFormKey = GlobalKey<FormState>();
  final _registerFullNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  bool _registerPasswordObscured = true;
  bool _registerConfirmObscured = true;

  // ── Branch selection tracking pointer (as specified in the brief) ─────────────
  Branch? chosenHomeSite;

  // ── Form submit flags ─────────────────────────────────────────────────────────
  bool _loginSubmitted = false;
  bool _registerSubmitted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerFullNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _submitLogin() async {
    setState(() => _loginSubmitted = true);
    if (!_loginFormKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).signInWithEmail(
          email: _loginEmailController.text.trim(),
          password: _loginPasswordController.text,
        );

    if (!mounted) return;

    if (!success) {
      final error = ref.read(authProvider).error;
      _showErrorSnack(error ?? 'Sign-in failed. Please try again.');
      return;
    }

    // Navigation is handled automatically by GoRouter's redirect in app.dart,
    // which watches authStatusProvider and routes to /home (or /membership-paywall)
    // once AuthStatus changes to authenticated.
  }

  Future<void> _submitRegister() async {
    setState(() => _registerSubmitted = true);
    final formValid = _registerFormKey.currentState!.validate();
    final branchValid = chosenHomeSite != null;

    if (!formValid || !branchValid) return;

    final success = await ref.read(authProvider.notifier).signUpWithEmail(
          email: _registerEmailController.text.trim(),
          password: _registerPasswordController.text,
          fullName: _registerFullNameController.text.trim(),
          homeSite: chosenHomeSite!,
        );

    if (!mounted) return;

    if (!success) {
      final error = ref.read(authProvider).error;
      _showErrorSnack(error ?? 'Registration failed. Please try again.');
      return;
    }

    // Navigation is handled automatically by GoRouter's redirect in app.dart.
    // After successful sign-up, AuthStatus is set to pendingEmailVerification,
    // which routes the user to the /pending-verification screen.
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
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────────
            const SizedBox(height: 32),
            _buildLogoHeader(),
            const SizedBox(height: 28),

            // ── Tab bar ─────────────────────────────────────────────────────────
            _buildTabBar(),
            const SizedBox(height: 4),

            // ── Forms ───────────────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginForm(authState),
                  _buildRegisterForm(authState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logo header ──────────────────────────────────────────────────────────────

  Widget _buildLogoHeader() {
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: AppColors.brandBlack,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandRed.withValues(alpha: 0.25),
                blurRadius: 28,
                offset: const Offset(0, 8),
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
                size: 44,
                color: AppColors.brandRed,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'TigerBay',
          style: AppTypography.title1.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: AppColors.brandRed,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'INTERNATIONAL',
          style: AppTypography.caption2.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 3.5,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Member Access',
          style: AppTypography.subheadline.copyWith(
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
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF28282B),
            width: 0.8,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: const Color(0xFF242428),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: AppColors.champagneGold,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTypography.subheadline.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: AppTypography.subheadline.copyWith(
            fontWeight: FontWeight.w400,
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
                onPressed: () => _sendPasswordReset(),
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

            // ── Sign In button ──────────────────────────────────────────────────
            _buildPrimaryButton(
              label: 'Sign In',
              isLoading: authState.isLoading,
              onTap: _submitLogin,
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
    );
  }

  Future<void> _sendPasswordReset() async {
    final email = _loginEmailController.text.trim();
    if (email.isEmpty) {
      _showErrorSnack('Enter your email address first to reset password.');
      return;
    }
    try {
      await ref
          .read(supabaseClientProvider)
          .auth
          .resetPasswordForEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Password reset email sent.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    } catch (e) {
      _showErrorSnack(e.toString());
    }
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
              controller: _registerPasswordController,
              hint: 'Create a password',
              obscure: _registerPasswordObscured,
              prefixIcon: CupertinoIcons.lock,
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

            const SizedBox(height: 18),

            // ── Confirm Password ────────────────────────────────────────────────
            _buildFieldLabel('CONFIRM PASSWORD'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _registerConfirmPasswordController,
              hint: 'Re-enter your password',
              obscure: _registerConfirmObscured,
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      obscureText: obscure,
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

  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return AppleTouchFeedback(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(27),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label,
                  style: AppTypography.headline.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
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
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: AppTypography.caption1.copyWith(
          color: AppColors.textHint,
        ),
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: AppTypography.caption1.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.champagneGold,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()..onTap = () {},
          ),
          const TextSpan(text: ' & '),
          TextSpan(
            text: 'Privacy Policy',
            style: AppTypography.caption1.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.champagneGold,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()..onTap = () {},
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
