/// Maps to public.app_configs (Realtime enabled).
/// Row 1 is always the active layout config.
class AppConfigModel {
  final int id;
  final String? bannerTitle;    // column: banner_title
  final String? bannerSubtitle; // column: banner_subtitle
  final bool isPromoActive;     // column: is_promo_active

  const AppConfigModel({
    required this.id,
    this.bannerTitle,
    this.bannerSubtitle,
    this.isPromoActive = false,
  });

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    return AppConfigModel(
      id: json['id'] as int,
      bannerTitle: json['banner_title'] as String?,
      bannerSubtitle: json['banner_subtitle'] as String?,
      isPromoActive: json['is_promo_active'] as bool? ?? false,
    );
  }
}
