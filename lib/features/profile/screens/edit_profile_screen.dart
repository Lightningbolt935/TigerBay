import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/branch_model.dart';
import '../../../services/twilio_notification_service.dart';
import '../../../shared/widgets/apple_touch_feedback.dart';
import '../../../shared/widgets/safe_network_image.dart';
import '../../../core/utils/phone_number_helper.dart';
import '../../../shared/widgets/phone_input_field.dart';
import '../../home/providers/home_provider.dart';
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
  int? _selectedHomeSiteId;
  final Set<String> _selectedDiningPrefs = {};
  bool _initialized = false;

  static const List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  static const List<String> _diningOptions = [
    'Halal Only',
    'Vegetarian',
    'Vegan',
    'Gluten-Free',
    'Nut Allergy',
    'Non-Alcoholic',
    'Outdoor Terrace',
    'Booth Seating',
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
      _phoneController.text = PhoneNumberHelper.formatDisplay(profile?.phone);
      _selectedGender = profile?.gender;
      _selectedHomeSiteId = profile?.homeSiteId;
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

  // ── iOS Cupertino Preferred Branch ActionSheet Modal ─────────────────────
  void _pickBranchCupertino(List<Branch> branches) {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext bContext) => CupertinoActionSheet(
        title: Text(
          'Select Preferred Lounge',
          style: AppTypography.subheadline.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        message: Text(
          'Your primary TigerBay venue for reservations and VIP perks.',
          style: AppTypography.caption1.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: branches.map((branch) {
          final isSelected = _selectedHomeSiteId == branch.id;
          return CupertinoActionSheetAction(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedHomeSiteId = branch.id);
              Navigator.pop(bContext);
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
                  branch.title,
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
          onPressed: () => Navigator.pop(bContext),
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

  // ── Verified Mobile Number Change Flow (Twilio SMS Verify) ───────────────
  void _showChangePhoneSheet() {
    HapticFeedback.selectionClick();
    final (initialCountry, initialDigits) =
        PhoneNumberHelper.parseE164(_phoneController.text);
    CountryCode selectedCountry = initialCountry;
    final nationalPhoneController = TextEditingController(text: initialDigits);
    final otpController = TextEditingController();
    int step = 0;
    bool isLoading = false;
    String? errorMessage;
    int cooldownSeconds = 60;
    Timer? resendTimer;
    String cleanPhone = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          void startCooldown() {
            cooldownSeconds = 60;
            resendTimer?.cancel();
            resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
              if (cooldownSeconds > 0) {
                setModalState(() => cooldownSeconds--);
              } else {
                t.cancel();
              }
            });
          }

          Future<void> sendOtp() async {
            final validationError = PhoneNumberHelper.validate(
              country: selectedCountry,
              nationalInput: nationalPhoneController.text,
            );
            if (validationError != null) {
              setModalState(() => errorMessage = validationError);
              return;
            }
            cleanPhone = PhoneNumberHelper.formatToE164(
              dialCode: selectedCountry.dialCode,
              nationalInput: nationalPhoneController.text,
            );
            setModalState(() {
              isLoading = true;
              errorMessage = null;
            });
            try {
              final twilio = TwilioNotificationService();
              final res = await twilio.sendVerificationCode(to: cleanPhone, channel: 'sms');
              if (res['success'] == true) {
                setModalState(() {
                  step = 1;
                  isLoading = false;
                });
                startCooldown();
              } else {
                setModalState(() {
                  isLoading = false;
                  errorMessage = res['error']?.toString() ?? 'Failed to send SMS code';
                });
              }
            } catch (e) {
              setModalState(() {
                isLoading = false;
                errorMessage = 'Error sending code: $e';
              });
            }
          }

          Future<void> verifyOtp() async {
            final otp = otpController.text.trim();
            if (otp.length != 6) {
              setModalState(() => errorMessage = 'Enter the complete 6-digit code');
              return;
            }
            cleanPhone = PhoneNumberHelper.formatToE164(
              dialCode: selectedCountry.dialCode,
              nationalInput: nationalPhoneController.text,
            );
            setModalState(() {
              isLoading = true;
              errorMessage = null;
            });
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(sheetContext);
            try {
              final twilio = TwilioNotificationService();
              final approved = await twilio.verifyCode(to: cleanPhone, code: otp);
              if (approved) {
                resendTimer?.cancel();
                await ref.read(profileProvider.notifier).updateProfile(
                      fullName: _nameController.text.trim(),
                      email: _emailController.text.trim(),
                      phone: cleanPhone,
                      gender: _selectedGender,
                      dob: _selectedDob,
                      homeSiteId: _selectedHomeSiteId,
                    );
                if (!mounted) return;
                setState(() => _phoneController.text = PhoneNumberHelper.formatDisplay(cleanPhone));
                HapticFeedback.heavyImpact();
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.champagneGold, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Mobile number verified and updated!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
              } else {
                setModalState(() {
                  isLoading = false;
                  errorMessage = 'Incorrect 6-digit verification code';
                });
              }
            } catch (e) {
              setModalState(() {
                isLoading = false;
                errorMessage = 'Verification error: $e';
              });
            }
          }

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        step == 0 ? 'Update Mobile Number' : 'Verify Mobile Number',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          resendTimer?.cancel();
                          Navigator.pop(sheetContext);
                        },
                        child: const Icon(CupertinoIcons.xmark_circle_fill,
                            color: AppColors.textHint, size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step == 0
                        ? 'We will send a 6-digit SMS verification code to verify your new mobile number.'
                        : 'Enter the 6-digit SMS code dispatched to ${PhoneNumberHelper.formatDisplay(cleanPhone)}.',
                    style: AppTypography.footnote.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: AppTypography.caption1.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (step == 0) ...[
                    PhoneInputField(
                      controller: nationalPhoneController,
                      selectedCountry: selectedCountry,
                      onCountryChanged: (c) {
                        setModalState(() => selectedCountry = c);
                      },
                    ),
                    const SizedBox(height: 20),
                    AppleTouchFeedback(
                      onTap: isLoading ? null : sendOtp,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                              )
                            : Text(
                                'Send Verification Code',
                                style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.brandBlack,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.champagneGold, width: 1.2),
                      ),
                      child: TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: AppColors.gold,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 10,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '••••••',
                          hintStyle: GoogleFonts.poppins(
                            color: AppColors.textHint,
                            fontSize: 22,
                            letterSpacing: 10,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => setModalState(() => step = 0),
                          child: Text(
                            'Edit number',
                            style: AppTypography.footnote.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                        Text(
                          cooldownSeconds > 0 ? 'Resend in ${cooldownSeconds}s' : 'Code expired',
                          style: AppTypography.footnote.copyWith(
                            color: cooldownSeconds > 0 ? AppColors.gold : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    AppleTouchFeedback(
                      onTap: isLoading ? null : verifyOtp,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                              )
                            : Text(
                                'Verify & Update',
                                style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Verified Email Change Flow (Supabase Auth Link) ──────────────────────
  void _showChangeEmailSheet() {
    HapticFeedback.selectionClick();
    final newEmailController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          Future<void> submitEmailChange() async {
            final newEmail = newEmailController.text.trim();
            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            if (!emailRegex.hasMatch(newEmail)) {
              setModalState(() => errorMessage = 'Please enter a valid email address');
              return;
            }
            setModalState(() {
              isLoading = true;
              errorMessage = null;
            });
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(sheetContext);
            try {
              await Supabase.instance.client.auth.updateUser(
                UserAttributes(email: newEmail),
              );
              if (!mounted) return;
              HapticFeedback.mediumImpact();
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(CupertinoIcons.mail_solid, color: AppColors.champagneGold, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Confirmation link sent to $newEmail. Click link in email to finalize.',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
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
            } catch (e) {
              setModalState(() {
                isLoading = false;
                errorMessage = 'Failed to update email: $e';
              });
            }
          }

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Change Email Address',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Icon(CupertinoIcons.xmark_circle_fill,
                            color: AppColors.textHint, size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter your new email address. A secure verification link will be dispatched to confirm ownership.',
                    style: AppTypography.footnote.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: AppTypography.caption1.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.brandBlack,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.glassBorder, width: 0.8),
                    ),
                    child: TextField(
                      controller: newEmailController,
                      keyboardType: TextInputType.emailAddress,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'newemail@example.com',
                        hintStyle: AppTypography.body.copyWith(color: AppColors.textHint),
                        prefixIcon: const Icon(CupertinoIcons.mail,
                            color: AppColors.gold, size: 18),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppleTouchFeedback(
                    onTap: isLoading ? null : submitEmailChange,
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : Text(
                              'Send Confirmation Link',
                              style: GoogleFonts.poppins(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
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
          homeSiteId: _selectedHomeSiteId,
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

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                color: AppColors.error, size: 22),
            const SizedBox(width: 10),
            Text(
              'Delete Account?',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Text(
          'This action is permanent and cannot be undone. All your membership privileges, VIP tier, active bookings, and loyalty strips will be permanently erased.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx, rootNavigator: true).pop();
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Deleting your account...'),
                  backgroundColor: Color(0xFF1E1E22),
                  behavior: SnackBarBehavior.floating,
                ),
              );

              final navigator = Navigator.of(context);
              final success =
                  await ref.read(profileProvider.notifier).deleteAccount();

              if (!mounted) return;
              if (success) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Your account and data have been permanently deleted.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                navigator.pop();
              } else {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Failed to delete account. Please contact TigerBay concierge.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(
              'Delete Permanently',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
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
    final branches = ref.watch(branchesProvider);
    _initFields(profileState);
    final bottomSafePadding = MediaQuery.paddingOf(context).bottom;

    final branchList = branches.asData?.value ?? [];
    final resolvedBranch = branchList.where(
      (b) => b.id == _selectedHomeSiteId,
    ).firstOrNull;
    final String homeBranchName = resolvedBranch != null
        ? resolvedBranch.title
        : 'Select Venue';

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
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
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
                      actionLabel: 'Change',
                      onActionTap: _showChangeEmailSheet,
                    ),
                    const Divider(
                        height: 1, indent: 16, color: AppColors.glassBorder),
                    _AppleInputField(
                      label: 'Mobile Number',
                      controller: _phoneController,
                      hint: '+44 7700 900000',
                      inputType: TextInputType.phone,
                      readOnly: true,
                      actionLabel: 'Change',
                      onActionTap: _showChangePhoneSheet,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 6),
                child: Text(
                  'Tap Change to securely update your verified credentials via OTP.',
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
                    const Divider(
                        height: 1, indent: 16, color: AppColors.glassBorder),

                    // Preferred Home Lounge Row
                    AppleTouchFeedback(
                      onTap: () {
                        if (branchList.isNotEmpty) {
                          _pickBranchCupertino(branchList);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 15),
                        child: Row(
                          children: [
                            Text(
                              'Preferred Lounge',
                              style: AppTypography.body.copyWith(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              homeBranchName,
                              style: AppTypography.body.copyWith(
                                fontSize: 15,
                                color: _selectedHomeSiteId == null
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

              const SizedBox(height: 24),

              // ── Section 3: DINING & LOUNGE PREFERENCES ──────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'DINING & LOUNGE PREFERENCES',
                  style: AppTypography.sectionHeader,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.glassBorder, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inform lounge hosts of dietary restrictions and preferred seating.',
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: _diningOptions.map((option) {
                        final isSelected = _selectedDiningPrefs.contains(option);
                        return AppleTouchFeedback(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (isSelected) {
                                _selectedDiningPrefs.remove(option);
                              } else {
                                _selectedDiningPrefs.add(option);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.gold.withValues(alpha: 0.16)
                                  : AppColors.brandBlack,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.champagneGold
                                    : AppColors.glassBorder,
                                width: isSelected ? 1.4 : 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  const Icon(
                                    CupertinoIcons.checkmark_alt,
                                    size: 14,
                                    color: AppColors.champagneGold,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  option,
                                  style: AppTypography.caption1.copyWith(
                                    color: isSelected
                                        ? AppColors.champagneGold
                                        : AppColors.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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

            const SizedBox(height: 24),

            // ── Apple Guideline 5.1.1(v) Compliant Delete Account Action ────
            Center(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                onPressed: profileState.isSaving
                    ? null
                    : () => _confirmDeleteAccount(context),
                child: Text(
                  'Delete Account',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.error.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
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
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const _AppleInputField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.inputType,
    this.readOnly = false,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
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
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 10),
            AppleTouchFeedback(
              onTap: onActionTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.champagneGold.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: AppTypography.caption1.copyWith(
                    color: AppColors.champagneGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
