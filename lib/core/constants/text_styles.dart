import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Typography System (Poppins Only)
/// ═══════════════════════════════════════════════════════════════════════════
/// Every TextStyle in the application must reference this class. The font
/// family is always 'Poppins' — no system fonts, no fallbacks.
///
/// Tiers:
///   Hero       → Bold (w700), 24–28px, uppercase, letterSpacing 2.0–4.0
///   Section    → SemiBold (w600), 16–18px, letterSpacing 1.2
///   Body       → Regular (w400), 13–15px
///   Micro      → SemiBold (w600), 10–12px, uppercase, letterSpacing 0.8–1.2
class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'Poppins';

  // ── Hero Tier ─────────────────────────────────────────────────────────────

  /// Screen titles, hero labels. 28px, Bold, uppercase, letterSpacing 4.
  static const TextStyle heroTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 4.0,
  );

  /// Slightly smaller hero. 24px, Bold, uppercase, letterSpacing 2.
  static const TextStyle heroTitleSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 2.0,
  );

  /// Brand name "TigerBay" on app bars — 20px Bold, brandRed, letterSpacing 2.
  static const TextStyle brandTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.brandRed,
    letterSpacing: 2.0,
  );

  /// Brand subtitle "INTERNATIONAL" — 12px SemiBold, gold, letterSpacing 4.
  static const TextStyle brandSubtitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.gold,
    letterSpacing: 4.0,
  );

  // ── Section Tier ──────────────────────────────────────────────────────────

  /// Section headers. 18px SemiBold, letterSpacing 1.2.
  static const TextStyle sectionHeader = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 1.2,
  );

  /// Smaller section header. 16px SemiBold, letterSpacing 1.2.
  static const TextStyle sectionHeaderSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 1.2,
  );

  // ── Body Tier ─────────────────────────────────────────────────────────────

  /// Primary body text. 15px Regular, white.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Standard body. 14px Regular, white.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Compact body. 13px Regular, white.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Body secondary text. 14px Regular, textSecondary.
  static const TextStyle bodySecondary = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Body hint. 13px Regular, textHint.
  static const TextStyle bodyHint = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );

  // ── Micro Tier ────────────────────────────────────────────────────────────

  /// Micro labels, badges, chips. 12px SemiBold, uppercase, letterSpacing 1.2.
  static const TextStyle micro = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 1.2,
  );

  /// Tiny micro. 11px SemiBold, uppercase, letterSpacing 0.8.
  static const TextStyle microSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.8,
  );

  /// Smallest micro for badge text. 10px SemiBold, uppercase, letterSpacing 0.8.
  static const TextStyle microTiny = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.8,
  );

  // ── Special Purpose ───────────────────────────────────────────────────────

  /// Primary ElevatedButton text. 15px SemiBold, white.
  static const TextStyle buttonPrimary = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Secondary / outlined button text. 14px Medium, gold.
  static const TextStyle buttonSecondary = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.gold,
  );

  /// Input field text. 15px Regular, white.
  static const TextStyle inputText = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// Input hint. 15px Regular, textHint.
  static const TextStyle inputHint = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );

  /// Input label. 14px SemiBold, textSecondary.
  static const TextStyle inputLabel = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  /// Tier name inside membership card. 22px Bold, gold.
  static const TextStyle tierName = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.gold,
  );

  /// Price figure. 28px Bold, white.
  static const TextStyle priceLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Strips balance number. 22px Bold, gold.
  static const TextStyle stripsBalance = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.gold,
  );

  /// Strips label below balance. 12px Regular, textSecondary.
  static const TextStyle stripsLabel = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Earned strips. 14px Bold, success green.
  static const TextStyle stripsEarned = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.success,
  );

  /// Redeemed strips. 14px Regular, textSecondary.
  static const TextStyle stripsRedeemed = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Discounted price. 16px Bold, gold.
  static const TextStyle priceDiscounted = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.gold,
  );

  /// Original price struck through. 13px Regular, textHint.
  static const TextStyle priceOriginal = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
    decoration: TextDecoration.lineThrough,
  );

  /// Discount ribbon text. 11px Bold, white.
  static const TextStyle discountRibbon = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Tab bar label. 13px SemiBold.
  static const TextStyle tabLabel = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Timestamp text. 11px Regular, textHint.
  static const TextStyle timestamp = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );

  /// Category pill text. 13px SemiBold.
  static const TextStyle categoryPill = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Social login button text. 15px Medium, white.
  static const TextStyle buttonSocial = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Link text. 12px Medium, gold, underlined.
  static const TextStyle link = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.gold,
    decoration: TextDecoration.underline,
  );

  /// Caption / fine print. 11px Regular, textHint.
  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );
}
