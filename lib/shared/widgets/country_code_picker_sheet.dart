import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/phone_number_helper.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// CountryCodePickerSheet — Luxury Dark Glass Searchable Country Modal
/// ═══════════════════════════════════════════════════════════════════════════
class CountryCodePickerSheet extends StatefulWidget {
  final CountryCode selectedCountry;

  const CountryCodePickerSheet({
    super.key,
    required this.selectedCountry,
  });

  /// Displays the interactive country code picker modal bottom sheet
  static Future<CountryCode?> show({
    required BuildContext context,
    CountryCode selectedCountry = PhoneNumberHelper.defaultCountry,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<CountryCode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CountryCodePickerSheet(selectedCountry: selectedCountry),
    );
  }

  @override
  State<CountryCodePickerSheet> createState() => _CountryCodePickerSheetState();
}

class _CountryCodePickerSheetState extends State<CountryCodePickerSheet> {
  final _searchController = TextEditingController();
  List<CountryCode> _filtered = PhoneNumberHelper.supportedCountries;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = PhoneNumberHelper.supportedCountries;
      } else {
        _filtered = PhoneNumberHelper.supportedCountries.where((c) {
          final nameMatch = c.name.toLowerCase().contains(query);
          final codeMatch = c.dialCode.contains(query) ||
              c.dialCode.replaceAll('+', '').contains(query);
          final isoMatch = c.isoCode.toLowerCase().contains(query);
          return nameMatch || codeMatch || isoMatch;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.82;

    return Container(
      height: maxHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF131317),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF2C2C35), width: 1.2),
        ),
      ),
      child: Column(
        children: [
          // ── Grab Handle ───────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF383842),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header Title ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Country / Region',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF222228),
                    ),
                    child: const Icon(CupertinoIcons.xmark,
                        size: 16, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Search Input ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2E2E38)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.search,
                      size: 18, color: AppColors.champagneGold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search by country or code (e.g. +44)',
                        hintStyle: GoogleFonts.poppins(
                            color: const Color(0xFF6E6E78), fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => _searchController.clear(),
                      child: const Icon(CupertinoIcons.clear_circled_solid,
                          size: 16, color: Color(0xFF888890)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFF22222A)),

          // ── Country List ──────────────────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.globe,
                            size: 40, color: Color(0xFF4A4A55)),
                        const SizedBox(height: 12),
                        Text(
                          'No country found',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final country = _filtered[index];
                      final isSelected =
                          country.dialCode == widget.selectedCountry.dialCode &&
                              country.isoCode == widget.selectedCountry.isoCode;

                      return InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop(country);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 13),
                          color: isSelected
                              ? AppColors.gold.withValues(alpha: 0.08)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              Text(
                                country.flagEmoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  country.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? AppColors.champagneGold
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                country.dialCode,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.gold
                                      : const Color(0xFF9E9EAA),
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 10),
                                const Icon(CupertinoIcons.checkmark_alt_circle_fill,
                                    size: 18, color: AppColors.gold),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
