import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'apple_touch_feedback.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — FrostedGlassCard Widget
/// ═══════════════════════════════════════════════════════════════════════════
/// Apple-grade frosted glass container with real-time BackdropFilter blur,
/// subtle hairline light reflection border, and ambient luxury shadows.
class FrostedGlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;

  const FrostedGlassCard({
    super.key,
    required this.child,
    this.blur = 18.0,
    this.borderRadius = 22.0,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.gradient,
    this.borderColor,
    this.borderWidth = 0.8,
    this.shadows,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: gradient == null
                  ? (backgroundColor ?? AppColors.glassBackground)
                  : null,
              gradient: gradient,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? AppColors.glassBorder,
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return AppleTouchFeedback(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}
