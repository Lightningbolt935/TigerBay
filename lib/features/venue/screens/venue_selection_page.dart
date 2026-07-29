import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';

/// Shown ONLY the first time a user logs in — i.e. when
/// `profiles.last_selected_branch_id` is still null.
///
/// Routing logic (implement in your top-level auth/router guard, e.g.
/// inside your GoRouter redirect callback):
///
///   final profile = await Supabase.instance.client
///       .from('profiles')
///       .select('last_selected_branch_id')
///       .eq('id', userId)
///       .single();
///
///   if (profile['last_selected_branch_id'] == null) {
///     return '/venue-selection';
///   }
///   return '/home';
class VenueSelectionPage extends StatefulWidget {
  const VenueSelectionPage({super.key});

  @override
  State<VenueSelectionPage> createState() => _VenueSelectionPageState();
}

class _VenueSelectionPageState extends State<VenueSelectionPage> {
  late final Future<List<Branch>> _branchesFuture;
  bool _isSubmitting = false;
  int? _tappedBranchId;

  static const Color _gold = Color(0xFFC9A84C);
  static const Color _black = Color(0xFF0A0A0A);

  @override
  void initState() {
    super.initState();
    _branchesFuture = _fetchBranches();
  }

  Future<List<Branch>> _fetchBranches() async {
    final response = await Supabase.instance.client
        .from('branches')
        .select()
        .eq('is_active', true)
        .order('title');

    return (response as List)
        .map((row) => Branch.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> _selectBranch(Branch branch) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _tappedBranchId = branch.id;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No authenticated user found.');
      }

      // ── 1. Update the user's profile with their chosen branch ─────────
      await Supabase.instance.client
          .from('profiles')
          .update({'last_selected_branch_id': branch.id})
          .eq('id', userId);

      // ── 2. Log a row for real-time customer density analytics ─────────
      await Supabase.instance.client.from('user_login_sessions').insert({
        'user_id': userId,
        'selected_branch_id': branch.id,
      });

      if (!mounted) return;

      // ── 3. Route straight into the main dashboard home layout ─────────
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not select venue: $error'),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      setState(() {
        _isSubmitting = false;
        _tappedBranchId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 4),
              child: Text(
                'Choose Your Venue',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _black,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Text(
                'Select the branch you visit most — you can switch any time from your profile.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Color(0xFF6C6C70),
                  height: 1.4,
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Branch>>(
                future: _branchesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: _gold,
                        strokeWidth: 2,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load venues: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Color(0xFFFF3B30),
                          ),
                        ),
                      ),
                    );
                  }

                  final branches = snapshot.data ?? [];

                  if (branches.isEmpty) {
                    return const Center(
                      child: Text(
                        'No venues are currently available.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF6C6C70),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: branches.length,
                    itemBuilder: (context, index) {
                      final branch = branches[index];
                      final isThisCardLoading =
                          _isSubmitting && _tappedBranchId == branch.id;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _VenueCard(
                          branch: branch,
                          isLoading: isThisCardLoading,
                          isDisabled: _isSubmitting,
                          onTap: () => _selectBranch(branch),
                        ),
                      );
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
}

// ── Individual venue card widget ──────────────────────────────────────────────

class _VenueCard extends StatelessWidget {
  final Branch branch;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onTap;

  const _VenueCard({
    required this.branch,
    required this.isLoading,
    required this.isDisabled,
    required this.onTap,
  });

  static const Color _gold = Color(0xFFC9A84C);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDisabled && !isLoading ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Venue imagery background ───────────────────────────────
              Image.network(
                branch.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.storefront_outlined,
                    size: 36,
                    color: Color(0xFFAEAEB2),
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(color: Colors.grey.shade100);
                },
              ),

              // ── Gradient overlay for text legibility ───────────────────
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),

              // ── Active status chip ──────────────────────────────────────
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: branch.isActive
                        ? const Color(0xFF34C759)
                        : Colors.grey.shade500,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    branch.isActive ? 'Open' : 'Closed',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),

              // ── Venue title ──────────────────────────────────────────────
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        branch.title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: _gold,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
