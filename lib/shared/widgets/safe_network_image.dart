// TigerBay International — SafeNetworkImage
// Drop-in replacement for Image.network that guards against:
//   • null / empty imageUrl → shows fallback immediately
//   • Malformed URIs (no scheme, no host) → shows fallback (no crash)
//   • Network / decode errors at runtime → errorBuilder fallback
//   • Slow loading → gold spinner placeholder
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  /// Optional custom fallback widget. If null, the default icon fallback
  /// is used.
  final Widget? fallback;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallback,
  });

  /// Returns true only when [imageUrl] is a syntactically valid http/https URL.
  bool get _isValid {
    if (imageUrl == null || imageUrl!.trim().isEmpty) return false;
    final uri = Uri.tryParse(imageUrl!.trim());
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (!_isValid) {
      content = fallback ?? _buildDefaultFallback();
    } else {
      content = Image.network(
        imageUrl!.trim(),
        width: width,
        height: height,
        fit: fit,
        // Network / decode failure → show fallback gracefully
        errorBuilder: (context, error, stackTrace) =>
            fallback ?? _buildDefaultFallback(),
        // Loading in-progress → gold spinner
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: width,
            height: height,
            child: Container(
              color: AppColors.surface,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.gold,
                ),
              ),
            ),
          );
        },
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: content);
    }
    return content;
  }

  Widget _buildDefaultFallback() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.gold,
        size: 28,
      ),
    );
  }
}
