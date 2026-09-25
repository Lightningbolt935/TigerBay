import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/branch_model.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/widgets/apple_touch_feedback.dart';
import '../../../shared/widgets/safe_network_image.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/home_provider.dart';
import '../../../services/biometric_service.dart';
import '../../bookings/providers/booking_provider.dart';
import '../../../data/models/booking_model.dart';
import '../providers/profile_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TigerBay International — Redesigned Profile Screen
// ═══════════════════════════════════════════════════════════════════════════
// Full dark-luxury profile page with:
//  • Hero avatar + name + membership badge
//  • Strips balance card with gold shimmer
//  • Settings tiles for account, legal, sign-out
// NOT an edit form — editing happens via the separate EditProfileScreen.

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final branches = ref.watch(branchesProvider);
    final selectedBranch = ref.watch(selectedBranchProvider);
    final bookingsAsync = ref.watch(userBookingsStreamProvider);
    final upcomingCount = bookingsAsync.valueOrNull
            ?.where((b) => b.status == BookingStatus.upcoming)
            .length ??
        0;

    if (profileState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.brandBlack,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
        ),
      );
    }

    final profile = profileState.profile;

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Collapsible Header ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _ProfileHero(
              profile: profile,
              branches: branches,
              selectedBranch: selectedBranch,
              onBranchTap: () => _showBranchPicker(context, ref,
                  branches.asData?.value ?? []),
              onEditTap: () => context.push(AppRoutes.editProfile),
            ),
          ),

          // ── Strips Balance Card ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: _StripsCard(stripsBalance: profile?.stripsBalance ?? 0),
            ),
          ),

          // ── ACCOUNT section ────────────────────────────────────────────
          const SliverToBoxAdapter(
            child: _SectionLabel('ACCOUNT'),
          ),
          SliverToBoxAdapter(
            child: _SettingsCard(
              tiles: [
                _SettingsTile(
                  icon: CupertinoIcons.person_crop_circle,
                  label: 'Edit Profile',
                  subtitle: profile?.fullName ?? 'Update your details',
                  onTap: () => context.push(AppRoutes.editProfile),
                ),
                _SettingsTile(
                  icon: CupertinoIcons.calendar_badge_plus,
                  label: 'My Reservations',
                  subtitle: upcomingCount > 0
                      ? '$upcomingCount Upcoming ${upcomingCount == 1 ? 'Booking' : 'Bookings'}'
                      : 'View past & upcoming tables',
                  trailing: upcomingCount > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$upcomingCount Active',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 14,
                                color: AppColors.success,
                              ),
                            ],
                          ),
                        )
                      : null,
                  onTap: () => context.push(AppRoutes.myBookings),
                ),
                _SettingsTile(
                  icon: CupertinoIcons.bell_fill,
                  label: 'Notifications',
                  subtitle: 'Manage alerts & preferences',
                  onTap: () => context.push(AppRoutes.notificationPrefs),
                ),
                const _SettingsTile(
                  icon: CupertinoIcons.viewfinder,
                  label: 'Face ID & Biometrics',
                  subtitle: 'Quick unlock & VIP security',
                  trailing: _BiometricSwitch(),
                ),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── MEMBERSHIP section ─────────────────────────────────────────
          const SliverToBoxAdapter(
            child: _SectionLabel('MEMBERSHIP'),
          ),
          SliverToBoxAdapter(
            child: _SettingsCard(
              tiles: [
                _SettingsTile(
                  icon: CupertinoIcons.sparkles,
                  label: 'Membership',
                  subtitle: _membershipLabel(profile),
                  subtitleColor: _membershipColor(profile),
                  onTap: () => context.push(AppRoutes.membershipPaywall),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MembershipBadge(profile: profile),
                      const SizedBox(width: 4),
                      const Icon(
                        CupertinoIcons.chevron_right,
                        color: AppColors.textHint,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── INFORMATION & LEGAL section ────────────────────────────────
          const SliverToBoxAdapter(
            child: _SectionLabel('INFORMATION & LEGAL'),
          ),
          SliverToBoxAdapter(
            child: _SettingsCard(
              tiles: [
                _SettingsTile(
                  icon: CupertinoIcons.shield_lefthalf_fill,
                  label: 'Privacy Policy',
                  labelColor: AppColors.gold,
                  onTap: () => _launch('https://tigerbayinternational.com/privacy'),
                ),
                _SettingsTile(
                  icon: CupertinoIcons.doc_text_fill,
                  label: 'Terms of Service',
                  labelColor: AppColors.gold,
                  onTap: () => _launch('https://tigerbayinternational.com/terms'),
                ),
                _SettingsTile(
                  icon: CupertinoIcons.checkmark_shield_fill,
                  label: 'GDPR Compliance',
                  labelColor: AppColors.gold,
                  onTap: () => _launch('https://tigerbayinternational.com/gdpr'),
                ),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Sign Out
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SignOutButton(onTap: () => _confirmSignOut(context, ref)),
            ),
          ),

          // Delete Account (Apple Guideline 5.1.1(v) Compliant)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton(
                  onPressed: () => _confirmDeleteAccount(context, ref),
                  child: Text(
                    'Delete Account',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.error.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // App version
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 96),
              child: Center(
                child: Text(
                  'TigerBay International v1.0',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _membershipLabel(profile) {
    if (profile == null) return 'No membership';
    final status = profile.membershipStatus;
    if (status == 'active') return 'Active member';
    if (status == 'expired') return 'Membership expired';
    return 'No active membership';
  }

  Color _membershipColor(profile) {
    if (profile?.membershipStatus == 'active') return AppColors.success;
    if (profile?.membershipStatus == 'expired') return AppColors.warning;
    return AppColors.textSecondary;
  }

  void _showBranchPicker(BuildContext context, WidgetRef ref, List branches) {
    final selectedBranch = ref.read(selectedBranchProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.location_solid,
                    color: AppColors.gold, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Select Branch',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: branches.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, index) {
                  final b = branches[index];
                  final bool isSelected = selectedBranch?.id == b.id;
                  return _BranchTile(
                    name: b.title as String,
                    city: (b.city ?? '') as String,
                    isSelected: isSelected,
                    onTap: () {
                      ref.read(selectedBranchProvider.notifier).changeBranch(b);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Text(
          'You will be returned to the login screen.',
          style: GoogleFonts.poppins(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(authProvider.notifier).signOut();
              });
            },
            child: Text('Sign Out',
                style: GoogleFonts.poppins(
                    color: AppColors.brandRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                color: AppColors.error, size: 22),
            const SizedBox(width: 10),
            Text(
              'Delete Account?',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Text(
          'This action is permanent and cannot be undone. All your membership privileges, VIP tier, active bookings, and loyalty strips will be permanently erased.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx, rootNavigator: true).pop();
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Deleting your account...'),
                  backgroundColor: Color(0xFF1E1E22),
                  behavior: SnackBarBehavior.floating,
                ),
              );

              final success =
                  await ref.read(profileProvider.notifier).deleteAccount();

              if (success) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Your account and data have been permanently deleted.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Failed to delete account. Please contact TigerBay concierge.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(
              'Delete Permanently',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Hero Section
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileHero extends StatelessWidget {
  final UserProfile? profile;
  final AsyncValue<List<Branch>> branches;
  final Branch? selectedBranch;
  final VoidCallback onBranchTap;
  final VoidCallback onEditTap;

  const _ProfileHero({
    required this.profile,
    required this.branches,
    required this.selectedBranch,
    required this.onBranchTap,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final authUser = Supabase.instance.client.auth.currentUser;
    final displayName =
        (profile?.fullName != null && profile!.fullName!.trim().isNotEmpty)
            ? profile!.fullName!
            : (authUser?.userMetadata?['full_name'] as String? ??
                authUser?.userMetadata?['name'] as String? ??
                authUser?.userMetadata?['user_name'] as String? ??
                'TigerBay Member');
    final displayEmail =
        (profile?.email != null && profile!.email!.trim().isNotEmpty)
            ? profile!.email!
            : (authUser?.email ?? authUser?.userMetadata?['email'] as String?);
    final displayAvatar = profile?.avatarUrl ??
        authUser?.userMetadata?['avatar_url'] as String? ??
        authUser?.userMetadata?['picture'] as String?;
    final initials = profile?.initials ??
        (displayName != 'TigerBay Member' && displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : '?');

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A1A), AppColors.brandBlack],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top bar: title + branch pill
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Profile',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  branches.when(
                    data: (list) => _BranchPill(
                      label: selectedBranch?.title ?? 'Select Branch',
                      onTap: onBranchTap,
                    ),
                    loading: () =>
                        const _BranchPill(label: 'Loading...'),
                    error: (_, __) =>
                        const _BranchPill(label: 'Select Branch'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Avatar
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: SafeNetworkImage(
                      imageUrl: displayAvatar,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      fallback: Container(
                        color: AppColors.surface,
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Edit avatar button
                GestureDetector(
                  onTap: onEditTap,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.brandBlack, width: 2),
                    ),
                    child: const Icon(CupertinoIcons.camera_fill,
                        size: 14, color: Colors.black),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Name
            Text(
              displayName,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 4),

            // Email
            if (displayEmail != null && displayEmail.isNotEmpty)
              Text(
                displayEmail,
                style: AppTypography.subheadline.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),

            const SizedBox(height: 8),

            // 6-Digit Member ID
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder, width: 0.8),
              ),
              child: Text(
                'MEMBER ID: ${profile?.formattedMemberCode ?? 'TB-100000'}',
                style: AppTypography.memberIdStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.champagneGold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Membership tier chip
            _TierChip(profile: profile),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tier chip under the name
// ═══════════════════════════════════════════════════════════════════════════

class _TierChip extends StatelessWidget {
  final dynamic profile;
  const _TierChip({required this.profile});

  @override
  Widget build(BuildContext context) {
    final isActive = profile?.membershipStatus == 'active';
    final tierLabel = isActive
        ? 'Tier ${profile?.membershipTierId ?? ''} Member'
        : 'No Active Membership';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: isActive ? AppColors.goldGradient : null,
        color: isActive ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: isActive ? null : Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.workspace_premium : Icons.lock_outline_rounded,
            size: 14,
            color: isActive ? Colors.black : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            tierLabel,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.black : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Strips Balance Card
// ═══════════════════════════════════════════════════════════════════════════

class _StripsCard extends StatelessWidget {
  final int stripsBalance;
  const _StripsCard({required this.stripsBalance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F1B0E), Color(0xFF1C1C1E)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.toll_rounded,
                  color: Colors.black,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              // Balance info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STRIPS BALANCE',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$stripsBalance Strips',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
              // Redeem arrow
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.gold.withValues(alpha: 0.6),
              ),
            ],
          ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Section Label
// ═══════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Settings Card (grouped tiles with dividers)
// ═══════════════════════════════════════════════════════════════════════════

class _SettingsCard extends StatelessWidget {
  final List<_SettingsTile> tiles;
  const _SettingsCard({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i < tiles.length - 1)
                const Divider(
                  height: 1,
                  color: AppColors.glassBorder,
                  indent: 56,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Individual Settings Tile
// ═══════════════════════════════════════════════════════════════════════════

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? subtitleColor;
  final Color? labelColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.subtitleColor,
    this.labelColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppleTouchFeedback(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 14),
            // Label + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: labelColor ?? AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: subtitleColor ?? AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Trailing widget or default chevron
            trailing ??
                (onTap != null
                    ? const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textHint,
                        size: 20,
                      )
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Membership Badge (trailing widget on the membership tile)
// ═══════════════════════════════════════════════════════════════════════════

class _MembershipBadge extends StatelessWidget {
  final dynamic profile;
  const _MembershipBadge({required this.profile});

  @override
  Widget build(BuildContext context) {
    final isActive = profile?.membershipStatus == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: isActive ? AppColors.goldGradient : null,
        color: isActive ? null : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'INACTIVE',
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isActive ? Colors.black : AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sign Out Button
// ═══════════════════════════════════════════════════════════════════════════

class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppleTouchFeedback(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.brandRed.withValues(alpha: 0.35),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.square_arrow_right,
                color: AppColors.brandRed, size: 18),
            const SizedBox(width: 10),
            Text(
              'Sign Out',
              style: AppTypography.headline.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.brandRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Branch Pill (top-right location selector)
// ═══════════════════════════════════════════════════════════════════════════

class _BranchPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _BranchPill({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.location_solid,
                  color: AppColors.gold, size: 13),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_down,
                  color: Colors.white.withValues(alpha: 0.6), size: 11),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Branch Tile (bottom sheet list item)
// ═══════════════════════════════════════════════════════════════════════════

class _BranchTile extends StatelessWidget {
  final String name, city;
  final bool isSelected;
  final VoidCallback onTap;

  const _BranchTile({
    required this.name,
    required this.city,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.12)
                : const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.gold
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFFE4E4E7),
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        city,
                        style: GoogleFonts.poppins(
                          color: isSelected
                              ? AppColors.gold
                              : const Color(0xFFA1A1AA),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.black, size: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BiometricSwitch extends ConsumerStatefulWidget {
  const _BiometricSwitch();

  @override
  ConsumerState<_BiometricSwitch> createState() => _BiometricSwitchState();
}

class _BiometricSwitchState extends ConsumerState<_BiometricSwitch> {
  bool _isEnabled = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final bio = ref.read(biometricServiceProvider);
    final enabled = await bio.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _isEnabled = enabled;
        _isChecking = false;
      });
    }
  }

  Future<void> _toggle(bool val) async {
    final bio = ref.read(biometricServiceProvider);
    if (val) {
      final success = await bio.authenticate(
        reason: 'Confirm Face ID / Touch ID to enable biometric unlock.',
      );
      if (success) {
        await bio.setBiometricEnabled(true);
        if (mounted) setState(() => _isEnabled = true);
      }
    } else {
      await bio.setBiometricEnabled(false);
      if (mounted) setState(() => _isEnabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const SizedBox(
        width: 32,
        height: 20,
        child: CupertinoActivityIndicator(radius: 8),
      );
    }

    return CupertinoSwitch(
      value: _isEnabled,
      activeTrackColor: AppColors.gold,
      onChanged: _toggle,
    );
  }
}
