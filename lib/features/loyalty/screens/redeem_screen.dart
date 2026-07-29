import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reward_store_screen.dart';

class RedeemScreen extends ConsumerWidget {
  const RedeemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Forward directly to the modern schema-aligned Reward Store
    // which already implements activeRewardsProvider logic and redeemReward()
    return const RewardStoreScreen();
  }
}
