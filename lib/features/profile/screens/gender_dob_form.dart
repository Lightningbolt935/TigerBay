// TigerBay International — Gender & Date of Birth Form
// Self-contained stateful widget for selecting and persisting gender and DOB.
// Integrates directly with Riverpod [profileProvider] so saving flows through
// the same state management layer as the rest of the profile section.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/profile_provider.dart';

class GenderDobForm extends ConsumerStatefulWidget {
  final String? initialGender;
  final DateTime? initialDob;
  /// Called after a successful save so the parent can react (e.g. pop).
  final VoidCallback? onSaved;

  const GenderDobForm({
    super.key,
    this.initialGender,
    this.initialDob,
    this.onSaved,
  });

  @override
  ConsumerState<GenderDobForm> createState() => _GenderDobFormState();
}

class _GenderDobFormState extends ConsumerState<GenderDobForm> {
  String? _selectedGender;
  DateTime? _selectedDob;

  static const List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    _selectedGender = widget.initialGender;
    _selectedDob = widget.initialDob;
  }

  // ── Date Picker ─────────────────────────────────────────────────────────

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

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final success = await ref.read(profileProvider.notifier).updateGenderDob(
          gender: _selectedGender,
          dob: _selectedDob,
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile details updated successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      if (widget.onSaved != null) widget.onSaved!();
    } else {
      final error = ref.read(profileProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Update failed. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(profileProvider).isSaving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Date of Birth ───────────────────────────────────────────────
        const _FieldLabel('DATE OF BIRTH'),
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

        // ── Gender ──────────────────────────────────────────────────────
        const _FieldLabel('GENDER'),
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
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.gold),
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

        // ── Save Button ─────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: isSaving ? null : _save,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.gold, width: 1.2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: isSaving
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
      ],
    );
  }
}

/// Small label above each field — mirrors the style used elsewhere in profile screens.
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

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
