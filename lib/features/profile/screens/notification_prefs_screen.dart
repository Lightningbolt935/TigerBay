import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';

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

  Future<void> toggle(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    switch (key) {
      case _kBookingReminders:
        state = state.copyWith(bookingReminders: value);
      case _kLoyaltyUpdates:
        state = state.copyWith(loyaltyUpdates: value);
      case _kPromotions:
        state = state.copyWith(promotions: value);
      case _kNewMenuItems:
        state = state.copyWith(newMenuItems: value);
      case _kMemberEvents:
        state = state.copyWith(memberEvents: value);
    }
  }
}

final notifPrefsProvider =
    StateNotifierProvider<NotifPrefsNotifier, NotifPrefsState>(
        (_) => NotifPrefsNotifier());

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationPrefsScreen extends ConsumerWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notifPrefsProvider);
    final notifier = ref.read(notifPrefsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      appBar: AppBar(
        backgroundColor: AppColors.brandBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontFamily: 'Poppins',
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const _SectionLabel('BOOKINGS'),
          const SizedBox(height: 8),
          _NotifTile(
            title: 'Booking Reminders',
            subtitle: 'Reminder 24h before your reservation',
            value: prefs.bookingReminders,
            onChanged: (v) => notifier.toggle(_kBookingReminders, v),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('LOYALTY'),
          const SizedBox(height: 8),
          _NotifTile(
            title: 'Points Updates',
            subtitle: 'When you earn or redeem points',
            value: prefs.loyaltyUpdates,
            onChanged: (v) => notifier.toggle(_kLoyaltyUpdates, v),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('PROMOTIONS'),
          const SizedBox(height: 8),
          _NotifTile(
            title: 'Member Promotions',
            subtitle: 'Exclusive offers and deals',
            value: prefs.promotions,
            onChanged: (v) => notifier.toggle(_kPromotions, v),
          ),
          _NotifTile(
            title: 'New Menu Items',
            subtitle: 'When new dishes or cocktails are added',
            value: prefs.newMenuItems,
            onChanged: (v) => notifier.toggle(_kNewMenuItems, v),
          ),
          _NotifTile(
            title: 'Member Events',
            subtitle: 'Exclusive events at your branch',
            value: prefs.memberEvents,
            onChanged: (v) => notifier.toggle(_kMemberEvents, v),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.3,
        color: AppColors.textSecondary,
        fontFamily: 'Poppins',
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Poppins',
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
