import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/data/models/strips_ledger_entry.dart';
import 'package:tigerbay_app/features/auth/providers/profile_state_provider.dart';
import 'package:tigerbay_app/features/loyalty/providers/reward_provider.dart';
import 'package:tigerbay_app/shared/widgets/tigerbay_brand_header.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Dashboard Screen
/// ═══════════════════════════════════════════════════════════════════════════
/// Premium dashboard displaying the member's Strips wallet header with
/// gold-bordered balance component, tier badge, and a chronological
/// transaction ledger from the strips_ledger table.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileStateProvider);
    final ledgerAsync = ref.watch(stripsLedgerProvider);
    final profile = profileState.profile;

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      body: Column(
        children: [
          const TigerBayBrandHeader(),

          Expanded(
            child: profileState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 2,
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.gold,
                    backgroundColor: AppColors.surface,
                    onRefresh: () async {
                      await ref
                          .read(profileStateProvider.notifier)
                          .refreshProfile();
                      ref.invalidate(stripsLedgerProvider);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ── Strips Wallet Header Card ────────────────────
                        _StripsWalletCard(
                          balance: profile?.stripsBalance ?? 0,
                          tierName: _resolveTierName(
                              profile?.membershipTierId),
                        ),

                        const SizedBox(height: 24),

                        // ── Section Header ──────────────────────────────
                        Text(
                          'TRANSACTION HISTORY',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Transaction Ledger ──────────────────────────
                        ledgerAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.gold,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          error: (err, __) => _ErrorRetryWidget(
                            message: 'Could not load transactions',
                            onRetry: () =>
                                ref.invalidate(stripsLedgerProvider),
                          ),
                          data: (entries) {
                            if (entries.isEmpty) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.receipt_long_outlined,
                                        size: 48,
                                        color: AppColors.border,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No transactions yet',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Book a table to earn your first Strips!',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return Column(
                              children: entries
                                  .map((entry) =>
                                      _LedgerTile(entry: entry))
                                  .toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _resolveTierName(int? tierId) {
    if (tierId == null) return 'Member';
    const tierNames = {
      1: 'Bronze',
      2: 'Silver',
      3: 'Gold',
      4: 'Platinum',
      5: 'Black Diamond',
    };
    return tierNames[tierId] ?? 'Member';
  }
}

// ── Strips Wallet Card ────────────────────────────────────────────────────

class _StripsWalletCard extends StatelessWidget {
  final int balance;
  final String tierName;

  const _StripsWalletCard({
    required this.balance,
    required this.tierName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Tier Badge ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STRIPS WALLET',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gold),
                ),
                child: Text(
                  tierName.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Balance Display ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold, width: 1.5),
            ),
            child: Column(
              children: [
                Text(
                  '$balance',
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'STRIPS',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ledger Tile ───────────────────────────────────────────────────────────

class _LedgerTile extends StatelessWidget {
  final StripsLedgerEntry entry;

  const _LedgerTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // ── Icon ──────────────────────────────────────────────────
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: entry.isEarned
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              entry.isEarned
                  ? Icons.add_circle_outline_rounded
                  : Icons.remove_circle_outline_rounded,
              color: entry.isEarned
                  ? AppColors.success
                  : AppColors.textSecondary,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          // ── Description & Timestamp ───────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  entry.formattedDate,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),

          // ── Amount ────────────────────────────────────────────────
          Text(
            entry.displayAmount,
            style: entry.isEarned
                ? GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  )
                : GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Error Retry Widget ────────────────────────────────────────────────────

class _ErrorRetryWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetryWidget({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.error_outline,
              size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
