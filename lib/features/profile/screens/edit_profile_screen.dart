import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/apple_touch_feedback.dart';
import '../../../shared/widgets/safe_network_image.dart';
import '../providers/profile_provider.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Edit Profile Screen (Apple HIG Luxury Edition)
/// ═══════════════════════════════════════════════════════════════════════════
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

  // ── iOS Cupertino Date Picker Modal ───────────────────────────────────────
  void _pickDateCupertino() {
    HapticFeedback.selectionClick();
    DateTime tempPickedDate = _selectedDob ?? DateTime(2000, 1, 1);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext bContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Apple Modal Header with Cancel & Done actions
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: AppColors.glassBorder, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Text(
                        'Cancel',
                        style: AppTypography.subheadline.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onPressed: () => Navigator.pop(bContext),
                    ),
                    Text(
                      'Date of Birth',
                      style: AppTypography.headline.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Text(
                        'Done',
                        style: AppTypography.headline.copyWith(
                          color: AppColors.champagneGold,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: () {
                        setState(() => _selectedDob = tempPickedDate);
                        Navigator.pop(bContext);
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 216,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: Brightness.dark,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: AppTypography.title3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: _selectedDob ?? DateTime(2000, 1, 1),
                    minimumDate: DateTime(1920),
                    maximumDate: DateTime.now(),
                    onDateTimeChanged: (DateTime newDate) {
                      tempPickedDate = newDate;
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── iOS Cupertino Gender ActionSheet Modal ────────────────────────────────
  void _pickGenderCupertino() {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext aContext) => CupertinoActionSheet(
        title: Text(
          'Select Gender',
          style: AppTypography.subheadline.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: _genderOptions.map((option) {
          final isSelected = _selectedGender == option;
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _selectedGender = option);
              Navigator.pop(aContext);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected) ...[
                  const Icon(Icons.check_rounded,
                      size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                ],
                Text(
                  option,
                  style: AppTypography.callout.copyWith(
                    color: isSelected ? AppColors.gold : Colors.white,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(aContext),
          child: Text(
            'Cancel',
            style: AppTypography.callout.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ── iOS Cupertino Image Picker ActionSheet ───────────────────────────────
  void _showImageSourceSheet() {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext aContext) => CupertinoActionSheet(
        title: Text(
          'Change Profile Photo',
          style: AppTypography.subheadline.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(aContext);
              _pickImage(ImageSource.camera);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.camera,
                    size: 20, color: AppColors.gold),
                const SizedBox(width: 10),
                Text(
                  'Take Photo',
                  style: AppTypography.callout.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(aContext);
              _pickImage(ImageSource.gallery);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.photo_on_rectangle,
                    size: 20, color: AppColors.gold),
                const SizedBox(width: 10),
                Text(
                  'Choose from Library',
                  style: AppTypography.callout.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(aContext),
          child: Text(
            'Cancel',
            style: AppTypography.callout.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;

      final success = await ref
          .read(profileProvider.notifier)
          .uploadAvatar(pickedFile.name, bytes);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(CupertinoIcons.checkmark_seal_fill,
                      color: AppColors.champagneGold, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Profile photo updated',
                    style: AppTypography.subheadline
                        .copyWith(color: Colors.white),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E1E22),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side:
                    const BorderSide(color: AppColors.glassBorder, width: 0.8),
              ),
            ),
          );
        } else {
          final error = ref.read(profileProvider).error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(error ?? 'Failed to upload photo. Please try again.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting photo: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
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
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.champagneGold, size: 18),
              const SizedBox(width: 10),
              Text(
                'Profile updated successfully',
                style: AppTypography.subheadline.copyWith(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E1E22),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.glassBorder, width: 0.8),
          ),
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      final error = ref.read(profileProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error ?? 'Failed to update profile',
                  style:
                      AppTypography.subheadline.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2C1414),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.error, width: 0.8),
          ),
        ),
      );
    }
  }

  Widget _initialsWidget(String initials) {
    return Container(
      width: 92,
      height: 92,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTypography.sfPro(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.champagneGold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    _initFields(profileState);
    final bottomSafePadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AppleTouchFeedback(
          onTap: () => Navigator.pop(context),
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
          'Edit Profile',
          style: AppTypography.headline.copyWith(
            color: AppColors.textPrimary,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          // ── Apple Top-Right "Save" Action Button ─────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AppleTouchFeedback(
              onTap: profileState.isSaving ? null : _save,
              child: Container(
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: profileState.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: AppColors.champagneGold,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Save',
                        style: AppTypography.headline.copyWith(
                          color: AppColors.champagneGold,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(18, 16, 18, bottomSafePadding + 64),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Apple Avatar Inset ──────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  AppleTouchFeedback(
                    onTap: _showImageSourceSheet,
                    child: Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.champagneGold,
                              width: 2.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.2),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                profileState.profile?.avatarUrl != null
                                    ? SafeNetworkImage(
                                        imageUrl:
                                            profileState.profile!.avatarUrl,
                                        width: 96,
                                        height: 96,
                                        fit: BoxFit.cover,
                                        fallback: _initialsWidget(
                                            profileState.profile?.initials ??
                                                '?'),
                                      )
                                    : _initialsWidget(
                                        profileState.profile?.initials ?? '?'),
                                if (profileState.isSaving)
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    alignment: Alignment.center,
                                    child: const CupertinoActivityIndicator(
                                      color: AppColors.champagneGold,
                                      radius: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.brandBlack,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.camera_fill,
                              size: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap avatar to change photo',
                    style: AppTypography.caption1.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Section 1: ACCOUNT DETAILS (Apple Inset Group) ──────────────
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'ACCOUNT DETAILS',
                style: AppTypography.sectionHeader,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.glassBorder, width: 0.8),
              ),
              child: Column(
                children: [
                  _AppleInputField(
                    label: 'Full Name',
                    controller: _nameController,
                    hint: 'Your full name',
                    inputType: TextInputType.name,
                  ),
                  const Divider(
                      height: 1, indent: 16, color: AppColors.glassBorder),
                  _AppleInputField(
                    label: 'Email',
                    controller: _emailController,
                    hint: 'your@email.com',
                    inputType: TextInputType.emailAddress,
                    readOnly: true,
                    suffixIcon: const Icon(
                      CupertinoIcons.lock_fill,
                      size: 15,
                      color: AppColors.textHint,
                    ),
                  ),
                  const Divider(
                      height: 1, indent: 16, color: AppColors.glassBorder),
                  _AppleInputField(
                    label: 'Mobile Number',
                    controller: _phoneController,
                    hint: '+44 7700 900000',
                    inputType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 6),
              child: Text(
                'Account email cannot be modified directly.',
                style: AppTypography.caption2.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Section 2: PERSONAL DETAILS (Apple Inset Group) ─────────────
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'PERSONAL DETAILS',
                style: AppTypography.sectionHeader,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.glassBorder, width: 0.8),
              ),
              child: Column(
                children: [
                  // Date of Birth Row
                  AppleTouchFeedback(
                    onTap: _pickDateCupertino,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                      child: Row(
                        children: [
                          Text(
                            'Date of Birth',
                            style: AppTypography.body.copyWith(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _selectedDob == null
                                ? 'Select Date'
                                : DateFormat('dd MMM yyyy')
                                    .format(_selectedDob!),
                            style: AppTypography.body.copyWith(
                              fontSize: 15,
                              color: _selectedDob == null
                                  ? AppColors.textHint
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: AppColors.textHint,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(
                      height: 1, indent: 16, color: AppColors.glassBorder),

                  // Gender Row
                  AppleTouchFeedback(
                    onTap: _pickGenderCupertino,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                      child: Row(
                        children: [
                          Text(
                            'Gender',
                            style: AppTypography.body.copyWith(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _selectedGender ?? 'Select Gender',
                            style: AppTypography.body.copyWith(
                              fontSize: 15,
                              color: _selectedGender == null
                                  ? AppColors.textHint
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: AppColors.textHint,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // ── Primary Save Changes Pill Button ────────────────────────────
            AppleTouchFeedback(
              onTap: profileState.isSaving ? null : _save,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.gold,
                      AppColors.champagneGold,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: profileState.isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2.2,
                        ),
                      )
                    : Text(
                        'Save Changes',
                        style: AppTypography.callout.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Inset Apple-style row text field
class _AppleInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType inputType;
  final bool readOnly;
  final Widget? suffixIcon;

  const _AppleInputField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.inputType,
    this.readOnly = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              keyboardType: inputType,
              textAlign: TextAlign.end,
              style: AppTypography.body.copyWith(
                fontSize: 15,
                color:
                    readOnly ? AppColors.textSecondary : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.body.copyWith(
                  fontSize: 15,
                  color: AppColors.textHint,
                ),
                suffixIcon: suffixIcon,
                suffixIconConstraints: const BoxConstraints(
                  maxWidth: 24,
                  maxHeight: 24,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
