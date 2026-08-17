import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/apple_touch_feedback.dart';

// ── Notification preference keys ──────────────────────────────────────────────
const _kBookingReminders = 'notif_booking_reminders';
const _kLoyaltyUpdates   = 'notif_loyalty_updates';
const _kPromotions        = 'notif_promotions';
const _kNewMenuItems      = 'notif_new_menu';
const _kMemberEvents      = 'notif_member_events';

class NotifPrefsState {
  final bool bookingReminders;
  final bool loyaltyUpdates;
  final bool promotions;
  final bool newMenuItems;
  final bool memberEvents;

  const NotifPrefsState({
    this.bookingReminders = true,
    this.loyaltyUpdates   = true,
    this.promotions       = true,
    this.newMenuItems     = false,
    this.memberEvents     = true,
  });

  NotifPrefsState copyWith({
    bool? bookingReminders,
    bool? loyaltyUpdates,
    bool? promotions,
    bool? newMenuItems,
    bool? memberEvents,
  }) {
    return NotifPrefsState(
      bookingReminders: bookingReminders ?? this.bookingReminders,
      loyaltyUpdates:   loyaltyUpdates   ?? this.loyaltyUpdates,
      promotions:       promotions       ?? this.promotions,
      newMenuItems:     newMenuItems     ?? this.newMenuItems,
      memberEvents:     memberEvents     ?? this.memberEvents,
    );
  }
}

class NotifPrefsNotifier extends StateNotifier<NotifPrefsState> {
  NotifPrefsNotifier() : super(const NotifPrefsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotifPrefsState(
      bookingReminders: prefs.getBool(_kBookingReminders) ?? true,
      loyaltyUpdates:   prefs.getBool(_kLoyaltyUpdates)   ?? true,
      promotions:       prefs.getBool(_kPromotions)        ?? true,
      newMenuItems:     prefs.getBool(_kNewMenuItems)      ?? false,
      memberEvents:     prefs.getBool(_kMemberEvents)      ?? true,
    );
  }

  Future<void> toggle(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    switch (key) {
      case _kBookingReminders:
        state = state.copyWith(bookingReminders: val);
      case _kLoyaltyUpdates:
        state = state.copyWith(loyaltyUpdates: val);
      case _kPromotions:
        state = state.copyWith(promotions: val);
      case _kNewMenuItems:
        state = state.copyWith(newMenuItems: val);
      case _kMemberEvents:
        state = state.copyWith(memberEvents: val);
    }
  }
}

final notifPrefsProvider =
    StateNotifierProvider<NotifPrefsNotifier, NotifPrefsState>(
  (ref) => NotifPrefsNotifier(),
);

class NotificationPrefsScreen extends ConsumerWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notifPrefsProvider);
    final notifier = ref.read(notifPrefsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: AppleTouchFeedback(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(
              CupertinoIcons.chevron_back,
              size: 22,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        title: Text(
          'Notifications',
          style: AppTypography.headline.copyWith(
            color: AppColors.textPrimary,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('BOOKINGS', style: AppTypography.sectionHeader),
          ),
          _AppleGroupedCard(
            tiles: [
              _NotifRow(
                title: 'Booking Reminders',
                subtitle: 'Reminder 24h before your reservation',
                value: prefs.bookingReminders,
                onChanged: (v) => notifier.toggle(_kBookingReminders, v),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('LOYALTY & STRIPS', style: AppTypography.sectionHeader),
          ),
          _AppleGroupedCard(
            tiles: [
              _NotifRow(
                title: 'Points & Strips Updates',
                subtitle: 'When you earn or redeem Strips',
                value: prefs.loyaltyUpdates,
                onChanged: (v) => notifier.toggle(_kLoyaltyUpdates, v),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('PROMOTIONS & EVENTS', style: AppTypography.sectionHeader),
          ),
          _AppleGroupedCard(
            tiles: [
              _NotifRow(
                title: 'Member Promotions',
                subtitle: 'Exclusive offers and dining deals',
                value: prefs.promotions,
                onChanged: (v) => notifier.toggle(_kPromotions, v),
              ),
              _NotifRow(
                title: 'New Menu Items',
                subtitle: 'When new dishes or cocktails are added',
                value: prefs.newMenuItems,
                onChanged: (v) => notifier.toggle(_kNewMenuItems, v),
              ),
              _NotifRow(
                title: 'Member Events',
                subtitle: 'Exclusive events at your home branch',
                value: prefs.memberEvents,
                onChanged: (v) => notifier.toggle(_kMemberEvents, v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppleGroupedCard extends StatelessWidget {
  final List<_NotifRow> tiles;
  const _AppleGroupedCard({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder, width: 0.8),
      ),
      child: Column(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1)
              const Divider(height: 1, indent: 16, color: AppColors.glassBorder),
          ],
        ],
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.footnote.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.gold,
          ),
        ],
      ),
    );
  }
}
