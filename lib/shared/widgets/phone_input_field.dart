import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/phone_number_helper.dart';
import 'country_code_picker_sheet.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PhoneInputField — Luxury Apple-Themed Phone Input with Country Code Modal
/// ═══════════════════════════════════════════════════════════════════════════
class PhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final CountryCode selectedCountry;
  final ValueChanged<CountryCode> onCountryChanged;
  final String? Function(String?)? validator;
  final bool hasError;
  final String? hintText;
  final VoidCallback? onEditingComplete;

  const PhoneInputField({
    super.key,
    required this.controller,
    required this.selectedCountry,
    required this.onCountryChanged,
    this.validator,
    this.hasError = false,
    this.hintText,
    this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError ? AppColors.error : const Color(0xFF2C2C35),
          width: hasError ? 1.4 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // ── Country Selector Pill ─────────────────────────────────────────
          InkWell(
            onTap: () async {
              final chosen = await CountryCodePickerSheet.show(
                context: context,
                selectedCountry: selectedCountry,
              );
              if (chosen != null) {
                onCountryChanged(chosen);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedCountry.flagEmoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectedCountry.dialCode,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    CupertinoIcons.chevron_down,
                    size: 13,
                    color: AppColors.champagneGold,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Divider ───────────────────────────────────────────────────────
          Container(
            width: 1,
            height: 24,
            color: const Color(0xFF33333D),
          ),
          const SizedBox(width: 12),

          // ── National Number Text Field ────────────────────────────────────
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              onEditingComplete: onEditingComplete,
              decoration: InputDecoration(
                hintText: hintText ?? selectedCountry.example,
                hintStyle: GoogleFonts.poppins(
                  color: const Color(0xFF6E6E78),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              validator: validator ??
                  (v) => PhoneNumberHelper.validate(
                        country: selectedCountry,
                        nationalInput: v ?? '',
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
