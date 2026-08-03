import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/strips_ledger_entry.dart';
import '../providers/reward_provider.dart';

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(stripsLedgerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Transaction History',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: txAsync.when(
        data: (txList) => txList.isEmpty
            ? _buildEmpty()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: txList.length,
                separatorBuilder: (_, __) => Divider(
                    color: Colors.white.withValues(alpha: 0.1), height: 1),
                itemBuilder: (_, i) => _TransactionTile(tx: txList[i]),
              ),
        loading: () => const Center(
          child:
              CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: AppColors.brandRed,
              )),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.white24),
          SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final StripsLedgerEntry tx;
  const _TransactionTile({required this.tx});

  // Soft neon accents for OLED dark mode
  static const Color _creditColor = Color(0xFF4ADE80); // Emerald neon
  static const Color _debitColor  = Color(0xFFF87171); // Soft red

  // Deep tinted badge backgrounds
  static const Color _creditBg = Color(0xFF064E3B);
  static const Color _debitBg  = Color(0xFF7F1D1D);

  @override
  Widget build(BuildContext context) {
    final bool isCredit = tx.isEarned;
    final Color statusColor = isCredit ? _creditColor : _debitColor;
    final Color statusBg    = isCredit ? _creditBg    : _debitBg;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Dark OLED surface
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Subtle Circular Icon Badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusBg.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.add_rounded : Icons.remove_rounded,
              color: statusColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Title and Timestamp
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tx.description.isNotEmpty
                      ? tx.description
                      : tx.transactionType.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFAFAFA),
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tx.formattedDate,
                  style: const TextStyle(
                    color: Color(0xFFA1A1AA),
                    fontSize: 11,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),

          // Amount Display (+X Strips / -X Strips)
          Text(
            tx.displayAmount,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              letterSpacing: -0.2,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}
