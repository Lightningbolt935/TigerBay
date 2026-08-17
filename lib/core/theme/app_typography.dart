import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Apple SF Pro Typography System
/// ═══════════════════════════════════════════════════════════════════════════
/// Implements Apple Human Interface Guidelines (HIG) Dynamic Type hierarchy.
/// Uses SF Pro Display / SF Pro Text with system fallbacks and Inter for
/// cross-platform visual parity on iOS, Android, and Web.
class AppTypography {
  AppTypography._();

  static const String sfProDisplay = 'SF Pro Display';
  static const String sfProText = 'SF Pro Text';

  static const List<String> fontFallbacks = [
    'SF Pro Display',
    'SF Pro Text',
    '.SF UI Display',
    '.SF UI Text',
    '-apple-system',
    'BlinkMacSystemFont',
    'Inter',
    'Roboto',
    'sans-serif',
  ];

  /// Generic SF Pro / Apple-styled TextStyle builder
  static TextStyle sfPro({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    // Attempt Inter via GoogleFonts with SF Pro fallbacks for consistent rendering
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing ?? _defaultTracking(fontSize),
      height: height,
      decoration: decoration,
    ).copyWith(
      fontFamilyFallback: fontFallbacks,
    );
  }

  /// Apple Dynamic Type letter spacing (tracking) calculation
  static double _defaultTracking(double fontSize) {
    if (fontSize >= 28) return 0.36;
    if (fontSize >= 22) return 0.35;
    if (fontSize >= 20) return 0.38;
    if (fontSize >= 17) return -0.41;
    if (fontSize >= 16) return -0.32;
    if (fontSize >= 15) return -0.24;
    if (fontSize >= 13) return -0.08;
    if (fontSize >= 12) return 0.0;
    return 0.07;
  }

  // ── Apple Dynamic Type Presets ──────────────────────────────────────────

  /// Large Title (34pt / Bold) — Large hero headers
  static TextStyle get largeTitle => sfPro(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.37,
      );

  /// Title 1 (28pt / Bold) — Primary page headers
  static TextStyle get title1 => sfPro(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.36,
      );

  /// Title 2 (22pt / Bold) — Section headers
  static TextStyle get title2 => sfPro(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.35,
      );

  /// Title 3 (20pt / SemiBold) — Card headers & group titles
  static TextStyle get title3 => sfPro(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.38,
      );

  /// Headline (17pt / SemiBold) — Prominent list items & top bars
  static TextStyle get headline => sfPro(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
      );

  /// Body (17pt / Regular) — Primary reading text
  static TextStyle get body => sfPro(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.41,
      );

  /// Callout (16pt / Regular) — Highlighted content & buttons
  static TextStyle get callout => sfPro(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.32,
      );

  /// Subheadline (15pt / Regular) — Secondary subtitles
  static TextStyle get subheadline => sfPro(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.24,
      );

  /// Footnote (13pt / Regular) — Group headers & metadata
  static TextStyle get footnote => sfPro(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.08,
      );

  /// Caption 1 (12pt / Regular) — Badges & helper text
  static TextStyle get caption1 => sfPro(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.0,
      );

  /// Caption 2 (11pt / Regular) — Micro labels & timestamps
  static TextStyle get caption2 => sfPro(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.07,
      );

  /// Section Header (13pt / SemiBold / Uppercase tracking)
  static TextStyle get sectionHeader => sfPro(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: AppColors.textSecondary,
      );

  /// Number Display (Monospaced / Tabular figures for Member IDs & balances)
  static TextStyle memberIdStyle({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.champagneGold,
  }) {
    return sfPro(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: 1.8,
    );
  }

  /// Builds a complete TextTheme matching Apple HIG specifications
  static TextTheme createTextTheme(Color defaultColor) {
    return TextTheme(
      displayLarge: largeTitle.copyWith(color: defaultColor),
      displayMedium: title1.copyWith(color: defaultColor),
      displaySmall: title2.copyWith(color: defaultColor),
      headlineMedium: title3.copyWith(color: defaultColor),
      headlineSmall: headline.copyWith(color: defaultColor),
      titleLarge: headline.copyWith(color: defaultColor),
      titleMedium: callout.copyWith(color: defaultColor),
      titleSmall: subheadline.copyWith(color: defaultColor),
      bodyLarge: body.copyWith(color: defaultColor),
      bodyMedium: subheadline.copyWith(color: defaultColor),
      bodySmall: footnote.copyWith(color: defaultColor),
      labelLarge: callout.copyWith(
        color: defaultColor,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: caption1.copyWith(color: defaultColor),
      labelSmall: caption2.copyWith(color: defaultColor),
    );
  }
}
