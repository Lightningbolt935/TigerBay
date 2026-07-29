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
                separatorBuilder: (_, __) =>
                    Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                itemBuilder: (_, i) => _TransactionTile(tx: txList[i]),
              ),
        loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.gold, strokeWidth: 2),
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

  @override
  Widget build(BuildContext context) {
    final isEarned = tx.isEarned;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isEarned
                  ? AppColors.gold.withValues(alpha: 0.1)
                  : AppColors.brandRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEarned ? Icons.add_rounded : Icons.remove_rounded,
              size: 22,
              color: isEarned ? AppColors.gold : AppColors.brandRed,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tx.formattedDate,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tx.displayAmount,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isEarned ? AppColors.gold : AppColors.brandRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
