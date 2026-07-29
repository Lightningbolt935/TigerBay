import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Brand Color System (Dark Luxury)
/// ═══════════════════════════════════════════════════════════════════════════
/// Every color token used in the application is defined here. No ad-hoc hex
/// values are permitted outside this class. All values match the brand spec.
class AppColors {
  AppColors._();

  // ── Primary Brand Highlights ──────────────────────────────────────────────
  /// Used on TigerBay logo text, active icon states, error borders, urgency
  /// badges.
  static const Color brandRed = Color(0xFFE2231A);

  /// Primary action color — all ElevatedButtons, active tab indicators,
  /// focused input borders (width 1.5), Strips balance displays, discounted
  /// prices, reward cost badges, tier card header text.
  static const Color gold = Color(0xFFC9A84C);

  /// Disabled gold state for buttons.
  static Color goldDisabled = gold.withValues(alpha: 0.4);

  // ── Backgrounds ───────────────────────────────────────────────────────────
  /// Logo container background, scaffold backgrounds, list view backgrounds.
  static const Color brandBlack = Color(0xFF0A0A0A);

  /// Card surfaces, modal sheets, list tile backgrounds, information
  /// containers.
  static const Color surface = Color(0xFF1C1C1E);

  /// Secondary containers, inner card sections, divider-adjacent areas.
  static const Color surfaceLight = Color(0xFF2C2C2E);

  // ── Text ──────────────────────────────────────────────────────────────────
  /// All primary body text, card titles, menu item names on dark backgrounds.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Subtitles, descriptions, timestamps, helper text, muted labels.
  static const Color textSecondary = Color(0xFFAEAEB2);

  /// Placeholder text inside input fields.
  static const Color textHint = Color(0xFF6C6C70);

  // ── Borders ───────────────────────────────────────────────────────────────
  /// Default unfocused input borders, card outlines, dividers.
  static const Color border = Color(0xFF3A3A3C);

  // ── Status ────────────────────────────────────────────────────────────────
  /// Earned Strips ledger entries (+X Strips), successful redemption dialogs,
  /// active status chips.
  static const Color success = Color(0xFF34C759);

  /// Failed state messages, insufficient balance warnings, error SnackBars.
  static const Color error = Color(0xFFFF3B30);

  /// Warning badges, pending states.
  static const Color warning = Color(0xFFFF9500);

  // ── Social Button Colors ──────────────────────────────────────────────────
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color appleBlack = Color(0xFF000000);
  static const Color facebookBlue = Color(0xFF1877F2);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD4B96A), gold, Color(0xFFB8942F)],
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surface, brandBlack],
  );

  static const LinearGradient brandRedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandRed, Color(0xFFB01710)],
  );
}
