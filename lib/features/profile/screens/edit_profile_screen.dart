import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/safe_network_image.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDob;
  bool _initialized = false;

  static const List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initFields(ProfileState state) {
    if (_initialized) return;

    final profile = state.profile;
    final authUser = Supabase.instance.client.auth.currentUser;
    final fallbackEmail =
        authUser?.email ?? authUser?.userMetadata?['email'] as String? ?? '';
    final fallbackName = authUser?.userMetadata?['full_name'] as String? ??
        authUser?.userMetadata?['name'] as String? ??
        authUser?.userMetadata?['user_name'] as String? ??
        '';

    final resolvedName =
        (profile?.fullName != null && profile!.fullName!.trim().isNotEmpty)
            ? profile.fullName!
            : fallbackName;
    final resolvedEmail =
        (profile?.email != null && profile!.email!.trim().isNotEmpty)
            ? profile.email!
            : fallbackEmail;

    if (profile != null || authUser != null) {
      _initialized = true;
      _nameController.text = resolvedName;
      _emailController.text = resolvedEmail;
      _phoneController.text = profile?.phone ?? '';
      _selectedGender = profile?.gender;
      _selectedDob =
          profile?.dob != null ? DateTime.tryParse(profile!.dob!) : null;
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.gold,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDob && mounted) {
      setState(() => _selectedDob = picked);
    }
  }

  Future<void> _save() async {
    final success = await ref.read(profileProvider.notifier).updateProfile(
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          gender: _selectedGender,
          dob: _selectedDob,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      final error = ref.read(profileProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to update profile'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Avatar fallback — initials inside a filled circle ─────────────────────
  Widget _initialsWidget(String initials) {
    return Container(
      width: 90,
      height: 90,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    _initFields(profileState);

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      appBar: AppBar(
        backgroundColor: AppColors.brandBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontFamily: 'Poppins',
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // ── Avatar ─────────────────────────────────────────────────
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.gold, width: 2),
                    ),
                    child: ClipOval(
                      child: profileState.profile?.avatarUrl != null
                          ? SafeNetworkImage(
                              imageUrl: profileState.profile!.avatarUrl,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              fallback: _initialsWidget(
                                  profileState.profile?.initials ?? '?'),
                            )
                          : _initialsWidget(
                              profileState.profile?.initials ?? '?'),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.brandBlack, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            const Center(
              child: Text(
                'JPG or PNG. Max 5MB',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Poppins',
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Fields ─────────────────────────────────────────────────
            const _EditFieldLabel('FULL NAME'),
            const SizedBox(height: 8),
            _EditField(
              controller: _nameController,
              hint: 'Your full name',
              inputType: TextInputType.name,
            ),

            const SizedBox(height: 18),

            const _EditFieldLabel('EMAIL ADDRESS'),
            const SizedBox(height: 8),
            _EditField(
              controller: _emailController,
              hint: 'your@email.com',
              inputType: TextInputType.emailAddress,
              readOnly: true,
              suffixIcon: const Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: AppColors.textHint,
              ),
              helperText: 'Account email cannot be modified',
            ),

            const SizedBox(height: 18),

            const _EditFieldLabel('MOBILE NUMBER'),
            const SizedBox(height: 8),
            _EditField(
              controller: _phoneController,
              hint: '+44 7700 900000',
              inputType: TextInputType.phone,
            ),

            const SizedBox(height: 28),

            // ── Gender & Date of Birth ──────────────────────────────────
            const _EditFieldLabel('PERSONAL DETAILS'),
            const SizedBox(height: 16),

            const _EditFieldLabel('DATE OF BIRTH'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDob == null
                          ? 'Select Date of Birth'
                          : DateFormat('dd MMM yyyy').format(_selectedDob!),
                      style: TextStyle(
                        color: _selectedDob == null
                            ? AppColors.textHint
                            : AppColors.textPrimary,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const Icon(Icons.calendar_today_rounded,
                        color: AppColors.gold, size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            const _EditFieldLabel('GENDER'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedGender,
                  hint: const Text(
                    'Select Gender',
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  dropdownColor: AppColors.surface,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down,
                      color: AppColors.gold),
                  items: _genderOptions.map((String option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(
                        option,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedGender = val),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Single Save Changes Button ──────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: profileState.isSaving ? null : _save,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: AppColors.gold, width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: profileState.isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: AppColors.gold, strokeWidth: 2),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                          fontFamily: 'Poppins',
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _EditFieldLabel extends StatelessWidget {
  final String text;
  const _EditFieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
        fontFamily: 'Poppins',
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType inputType;
  final bool readOnly;
  final Widget? suffixIcon;
  final String? helperText;

  const _EditField({
    required this.controller,
    required this.hint,
    required this.inputType,
    this.readOnly = false,
    this.suffixIcon,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: inputType,
      style: TextStyle(
        fontSize: 14,
        color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
        fontFamily: 'Poppins',
      ),
      decoration: InputDecoration(
        hintText: hint,
        helperText: helperText,
        helperStyle: const TextStyle(
          fontSize: 11,
          color: AppColors.textHint,
          fontFamily: 'Poppins',
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: readOnly ? const Color(0xFF141414) : AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: readOnly
                ? AppColors.border.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: readOnly ? AppColors.border : AppColors.gold,
            width: readOnly ? 1.0 : 1.5,
          ),
        ),
      ),
    );
  }
}
