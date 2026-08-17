import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import 'app_typography.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Application Theme (Apple Dark Luxury Edition)
/// ═══════════════════════════════════════════════════════════════════════════
/// Single dark theme with Cupertino physics, Apple SF Pro typography, and
/// glassmorphic styling matching the Apple Human Interface Guidelines.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTypography.sfProText,
      fontFamilyFallback: AppTypography.fontFallbacks,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.brandRed,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.brandBlack,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );

    return base.copyWith(
      textTheme: AppTypography.createTextTheme(AppColors.textPrimary),

      // ── App Bar (Apple Translucent Header) ───────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 20),
        titleTextStyle: AppTypography.headline.copyWith(
          color: AppColors.textPrimary,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),

      // ── Elevated Button (Apple Pill Button) ──────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.black.withValues(alpha: 0.5),
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppTypography.callout.copyWith(
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),

      // ── Outlined Button (Apple Outlined Inset) ───────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gold,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: AppColors.gold, width: 1.2),
          textStyle: AppTypography.subheadline.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input Decoration (Apple Inset Rounded Fields) ────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: AppTypography.subheadline.copyWith(
          color: AppColors.textHint,
        ),
        labelStyle: AppTypography.footnote.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Card (Apple Inset Grouped Surface) ───────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.glassBorder, width: 0.8),
        ),
      ),

      // ── Divider ─────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.glassBorder,
        thickness: 0.5,
      ),

      // ── Bottom Navigation Bar ───────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppTypography.caption2.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTypography.caption2.copyWith(
          fontWeight: FontWeight.w400,
        ),
      ),

      // ── Bottom Sheet (Apple Inset Modal) ─────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        dragHandleColor: AppColors.border,
        showDragHandle: true,
      ),

      // ── Dialog (Apple Alert Dialog) ──────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.glassBorder, width: 0.8),
        ),
        titleTextStyle: AppTypography.headline.copyWith(
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
      ),

      // ── Snack Bar (Apple Dynamic Toast) ──────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E1E22),
        contentTextStyle: AppTypography.subheadline.copyWith(
          color: AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder, width: 0.8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Chip (Apple Capsule Chip) ────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        side: const BorderSide(color: AppColors.gold, width: 1.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        labelStyle: AppTypography.caption2.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.gold,
          letterSpacing: 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Tab Bar ─────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.gold,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTypography.subheadline.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTypography.subheadline.copyWith(
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
