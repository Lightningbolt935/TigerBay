import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Import your auth/profile provider here as per your project layout:
// import 'package:tigerbay_loyalty/features/auth/presentation/providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dobController = TextEditingController();

  String? _selectedGender;
  String? _selectedHomeBranch;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
  ];

  final List<String> _venueOptions = [
    'TigerBay London',
    'TigerBay Dubai',
    'TigerBay Cardiff',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final now = DateTime.now();
    final hundredYearsAgo = DateTime(now.year - 100);
    final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: eighteenYearsAgo,
      firstDate: hundredYearsAgo,
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Pass metadata along during signup
      // await ref.read(authNotifierProvider.notifier).signUp(
      //   email: _emailController.text.trim(),
      //   password: _passwordController.text,
      //   fullName: _fullNameController.text.trim(),
      //   dob: _dobController.text.trim(),
      //   gender: _selectedGender,
      //   homeBranch: _selectedHomeBranch,
      // );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // ── Sign In / Register Tab Toggle ──────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Sign In',
                              style: TextStyle(color: Colors.white54)),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const TextButton(
                            onPressed: null,
                            child: Text('Register',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── 1. Full Name ───────────────────────────────────────
                _label('Full Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fullNameController,
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Poppins'),
                  decoration: _inputDecoration(
                      hint: 'Enter your full name', icon: Icons.person_outline),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),

                // ── 2. Email ───────────────────────────────────────────
                _label('Email'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Poppins'),
                  decoration: _inputDecoration(
                      hint: 'Enter your email address',
                      icon: Icons.email_outlined),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 16),

                // ── 3. Password ────────────────────────────────────────
                _label('Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Poppins'),
                  decoration: _inputDecoration(
                    hint: 'Create a password',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white54),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 16),

                // ── 4. Confirm Password ────────────────────────────────
                _label('Confirm Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Poppins'),
                  decoration: _inputDecoration(
                    hint: 'Re-enter your password',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white54),
                      onPressed: () => setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (v) {
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── 5. Date of Birth (FIXED) ───────────────────────────
                _label('Date of Birth'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _selectDateOfBirth(context),
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _dobController,
                      style: const TextStyle(
                          color: Colors.white, fontFamily: 'Poppins'),
                      decoration: _inputDecoration(
                        hint: 'YYYY-MM-DD',
                        icon: Icons.calendar_today_outlined,
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Please select your date of birth'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── 6. Gender Selection (FIXED) ────────────────────────
                _label('Gender'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Poppins'),
                  decoration: _inputDecoration(
                      hint: 'Select Gender', icon: Icons.wc_outlined),
                  hint: const Text('Select Gender',
                      style: TextStyle(
                          color: Colors.white38, fontFamily: 'Poppins')),
                  items: _genderOptions
                      .map((gender) => DropdownMenuItem(
                            value: gender,
                            child: Text(gender,
                                style: const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedGender = val),
                  validator: (val) =>
                      val == null ? 'Please select your gender' : null,
                ),
                const SizedBox(height: 16),

                // ── 7. Home Location ───────────────────────────────────
                _label('Home Location'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedHomeBranch,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Poppins'),
                  decoration: _inputDecoration(
                      hint: 'Select your nearest TigerBay venue',
                      icon: Icons.location_on_outlined),
                  hint: const Text('Select your nearest TigerBay venue',
                      style: TextStyle(
                          color: Colors.white38, fontFamily: 'Poppins')),
                  items: _venueOptions
                      .map((venue) => DropdownMenuItem(
                            value: venue,
                            child: Text(venue,
                                style: const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedHomeBranch = val),
                  validator: (val) =>
                      val == null ? 'Please select a location' : null,
                ),
                const SizedBox(height: 28),

                // ── 8. Submit Button ───────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins'),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String hint, required IconData icon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontFamily: 'Poppins'),
      prefixIcon: Icon(icon, color: const Color(0xFFD4AF37)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
