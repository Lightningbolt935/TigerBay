import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Select Venue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...branches.map((b) => ListTile(
                title:
                    Text(b.title, style: const TextStyle(fontSize: 15)),
                onTap: () {
                  ref.read(selectedBranchProvider.notifier).changeBranch(b);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 16),
        ],
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
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? Image.network(avatarUrl!, fit: BoxFit.cover)
            : Container(
                color: AppColors.surface,
                child: Center(
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

// ── Branch pill ───────────────────────────────────────────────────────────────

class _BranchPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _BranchPill({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down,
                size: 16, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}
