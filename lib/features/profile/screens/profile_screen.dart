import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/safe_network_image.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/home_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final branches = ref.watch(branchesProvider);
    final selectedBranch = ref.watch(selectedBranchProvider);

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      body: SafeArea(
        child: profileState.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.gold, strokeWidth: 2),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // ── Header row ──────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        // Branch selector
                        branches.when(
                          data: (list) => _BranchPill(
                            label: selectedBranch?.title ??
                                'Loading...', // ◄ Displays the dynamic home site title automatically
                            onTap: () => _showBranchPicker(context, ref, list),
                          ),
                          loading: () => const _BranchPill(label: 'Loading...'),
                          error: (_, __) =>
                              const _BranchPill(label: 'Error Loading Site'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── PROFILE label ───────────────────────────────────
                    const Text(
                      'PROFILE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.3,
                        color: Colors.black45,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Avatar + Edit Photo ─────────────────────────────
                    Row(
                      children: [
                        _AvatarInitials(
                          initials: profileState.profile?.initials ?? '??',
                          avatarUrl: profileState.profile?.avatarUrl,
                        ),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => context.push(AppRoutes.editProfile),
                              child: const Text(
                                'Edit Photo',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.gold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'JPG or PNG. Max 5MB',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Full Name ───────────────────────────────────────
                    const _FieldLabel('FULL NAME'),
                    const SizedBox(height: 8),
                    _ReadOnlyField(
                      value: profileState.profile?.fullName ?? '',
                      hint: 'Your full name',
                      onTap: () => context.push(AppRoutes.editProfile),
                    ),

                    const SizedBox(height: 18),

                    // ── Email Address ───────────────────────────────────
                    const _FieldLabel('EMAIL ADDRESS'),
                    const SizedBox(height: 8),
                    _ReadOnlyField(
                      value: profileState.profile?.email ?? '',
                      hint: 'your@email.com',
                      onTap: () => context.push(AppRoutes.editProfile),
                    ),

                    const SizedBox(height: 18),

                    // ── Mobile Number ───────────────────────────────────
                    const _FieldLabel('MOBILE NUMBER'),
                    const SizedBox(height: 8),
                    _ReadOnlyField(
                      value: profileState.profile?.phone ?? '',
                      hint: '+44 7700 900000',
                      onTap: () => context.push(AppRoutes.editProfile),
                    ),

                    const SizedBox(height: 28),

                    // ── Save Changes button ─────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: () => context.push(AppRoutes.editProfile),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.gold, width: 1.2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Information & Legal ─────────────────────────────
                    const Text(
                      'INFORMATION & LEGAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.3,
                        color: Colors.black45,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _LegalTile(
                      label: 'Privacy Policy',
                      onTap: () =>
                          _launch('https://tigerbayinternational.com/privacy'),
                    ),
                    Divider(color: Colors.grey.shade100, height: 0),
                    _LegalTile(
                      label: 'Terms of Service',
                      onTap: () =>
                          _launch('https://tigerbayinternational.com/terms'),
                    ),
                    Divider(color: Colors.grey.shade100, height: 0),
                    _LegalTile(
                      label: 'GDPR Compliance',
                      onTap: () =>
                          _launch('https://tigerbayinternational.com/gdpr'),
                    ),
                    Divider(color: Colors.grey.shade100, height: 0),

                    const SizedBox(height: 28),

                    // ── Sign Out ────────────────────────────────────────
                    Center(
                      child: TextButton(
                        onPressed: () => _confirmSignOut(context, ref),
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.brandRed,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  void _showBranchPicker(BuildContext context, WidgetRef ref, List branches) {
    final selectedBranch = ref.read(selectedBranchProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212), // Premium dark surface
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
            // Drag handle
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

            // Header
            const Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFFD4AF37), // TigerBay Gold
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Select Branch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Branch list
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
                      ref
                          .read(selectedBranchProvider.notifier)
                          .changeBranch(b);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Sign Out?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('You will be returned to the login screen.',
            style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () {
              // 1. Instantly close the alert dialog box overlay cleanly
              Navigator.of(context, rootNavigator: true).pop();

              // 2. Defer the state mutation cleanly to prevent lifecycle crashes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(authProvider.notifier).signOut();
              });
            },
            child: const Text('Sign Out',
                style: TextStyle(
                    color: AppColors.brandRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Avatar with gold ring + initials ─────────────────────────────────────────

class _AvatarInitials extends StatelessWidget {
  final String initials;
  final String? avatarUrl;
  const _AvatarInitials({required this.initials, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      child: ClipOval(
        child: SafeNetworkImage(
          imageUrl: avatarUrl,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          fallback: Container(
            color: AppColors.surface,
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Field label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
        fontFamily: 'Poppins',
      ),
    );
  }
}

// ── Read-only tappable field ──────────────────────────────────────────────────

class _ReadOnlyField extends StatelessWidget {
  final String value;
  final String hint;
  final VoidCallback onTap;
  const _ReadOnlyField(
      {required this.value, required this.hint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          value.isEmpty ? hint : value,
          style: TextStyle(
            fontSize: 14,
            color: value.isEmpty ? AppColors.textHint : AppColors.textPrimary,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }
}

// ── Legal tile ────────────────────────────────────────────────────────────────

class _LegalTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LegalTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
      trailing:
          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
      onTap: onTap,
    );
  }
}

// ── Branch location chip ──────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07), // Glassmorphic tint
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: Color(0xFFD4AF37), // TigerBay Gold
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dark-luxury branch tile ───────────────────────────────────────────────────

class _BranchTile extends StatelessWidget {
  final String name;
  final String city;
  final bool isSelected;
  final VoidCallback onTap;

  const _BranchTile({
    required this.name,
    required this.city,
    required this.isSelected,
    required this.onTap,
  });

  static const Color _gold = Color(0xFFD4AF37);

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
            // Selected: gold tint. Unselected: elevated dark surface
            color: isSelected
                ? _gold.withValues(alpha: 0.12)
                : const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? _gold : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // High-visibility branch name
                    Text(
                      name,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFFE4E4E7),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        city,
                        style: TextStyle(
                          color: isSelected
                              ? _gold
                              : const Color(0xFFA1A1AA),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Gold checkmark badge for active selection
              if (isSelected)
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: _gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.black,
                    size: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
