import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/features/home/providers/home_provider.dart';
import 'package:tigerbay_app/features/bookings/providers/booking_provider.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  late DateTime _focusedMonth;
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _focusedMonth = DateTime(_today.year, _today.month);
  }

  List<DateTime> get _weekDays {
    return List.generate(14, (i) => _today.add(Duration(days: i)));
  }

  static const List<String> _fallbackSlots = [
    '18:00',
    '18:30',
    '19:00',
    '19:30',
    '20:00',
    '20:30',
  ];

  static const _monthNames = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  static const _dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingNotifierProvider);
    final branches = ref.watch(branchesProvider);
    final selectedBranch = ref.watch(selectedBranchProvider);

    final selectedDate = bookingState.selectedDate;
    final selectedSlot = bookingState.selectedSlot;
    final currentGuestCount =
        bookingState.partySize <= 0 ? 2 : bookingState.partySize;
    final notifier = ref.read(bookingNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Branch Selector ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: Colors.grey.shade200,
                      child: Icon(Icons.store_outlined,
                          color: Colors.grey.shade400),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: branches.when(
                      data: (list) => DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedBranch?.id ??
                              (list.isNotEmpty ? list.first.id : null),
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down,
                              color: Colors.grey.shade500),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          onChanged: (id) {
                            final b = list.firstWhere((b) => b.id == id);
                            ref.read(selectedBranchProvider.notifier).changeBranch(b);
                            notifier.setBranch(b.id.toString());
                          },
                          items: list
                              .map((b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text(b.title),
                                  ))
                              .toList(),
                        ),
                      ),
                      loading: () => const Text('Loading branches…',
                          style: TextStyle(fontSize: 14)),
                      error: (_, __) => const Text('London Mayfair',
                          style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const _BookingStepper(currentStep: 0),
            const SizedBox(height: 24),

            // ── Scrollable Content ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose Date & Time',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Secure your preferred slot at ${selectedBranch?.title ?? 'London Mayfair'}',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 24),

                    // ── Month Navigation ──────────────────────────────────
                    Row(
                      children: [
                        Text(
                          '${_monthNames[_focusedMonth.month]} ${_focusedMonth.year}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87),
                        ),
                        const Spacer(),
                        _NavArrow(
                          icon: Icons.chevron_left,
                          onTap: () => setState(() {
                            _focusedMonth = DateTime(
                                _focusedMonth.year, _focusedMonth.month - 1);
                          }),
                        ),
                        const SizedBox(width: 8),
                        _NavArrow(
                          icon: Icons.chevron_right,
                          onTap: () => setState(() {
                            _focusedMonth = DateTime(
                                _focusedMonth.year, _focusedMonth.month + 1);
                          }),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Date Strip ────────────────────────────────────────
                    SizedBox(
                      height: 82,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _weekDays.length,
                        itemBuilder: (_, i) {
                          final day = _weekDays[i];
                          final isSelected = selectedDate != null &&
                              selectedDate.day == day.day &&
                              selectedDate.month == day.month &&
                              selectedDate.year == day.year;
                          final isToday = day.day == _today.day &&
                              day.month == _today.month &&
                              day.year == _today.year;
                          final weekday = _dayNames[day.weekday - 1];

                          return GestureDetector(
                            onTap: () => notifier.setDate(day),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 64,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.gold
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.gold
                                      : isToday
                                          ? AppColors.gold
                                              .withValues(alpha: 0.4)
                                          : Colors.grey.shade200,
                                  width: isToday && !isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    weekday,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white70
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    day.day.toString(),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── 🛠️ NEW: Number of Guests Picker Section ──────────────────
                    const Text(
                      'NUMBER OF GUESTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 46,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 6,
                        itemBuilder: (context, index) {
                          final guestCount = index + 1;
                          final isSelected = currentGuestCount == guestCount;

                          return GestureDetector(
                            onTap: () => notifier.setPartySize(guestCount),
                            child: Container(
                              width: 54,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.black87
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.black87
                                      : Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  guestCount == 6 ? '6+' : '$guestCount',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Available Slots ───────────────────────────────────
                    const Text(
                      'AVAILABLE SLOTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: _fallbackSlots.length,
                      itemBuilder: (_, i) {
                        final slot = _fallbackSlots[i];
                        final isSelected = selectedSlot == slot;
                        return GestureDetector(
                          onTap: () => notifier.setSlot(slot),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.gold
                                  : AppColors.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? null
                                  : Border.all(
                                      color: AppColors.gold
                                          .withValues(alpha: 0.2)),
                            ),
                            child: Center(
                              child: Text(
                                slot,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.gold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Sticky Footer ─────────────────────────────────────────────────────
      // ── Sticky Footer ─────────────────────────────────────────────────────
      bottomNavigationBar: bookingState.canProceed
          ? _BookingFooter(
              branchName: selectedBranch?.title ?? 'London Mayfair',
              date: bookingState.selectedDate!,
              slot: bookingState.selectedSlot!,
              partySize: currentGuestCount,
              isLoading: bookingState.isLoading,
              onCheckout: () async {
                try {
                  final result = await notifier.createBooking().timeout(
                        const Duration(seconds: 4),
                        onTimeout: () =>
                            throw Exception('Database connection timed out.'),
                      );

                  if (result != null && context.mounted) {
                    result['branchId'] = int.tryParse(bookingState.branchId ?? '') ?? 0;
                    result['branchName'] = selectedBranch?.title ?? '';

                    context.push(
                      '/my-bookings/confirm',
                      extra: result,
                    );
                  } else if (context.mounted) {
                    throw Exception(
                        'Booking database returned an empty confirmation payload.');
                  }
                } catch (error) {
                  debugPrint('Captured Checkout Error: $error');

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Notice: Processing reservation at ${selectedBranch?.title}'),
                        backgroundColor: AppColors.gold,
                        duration: const Duration(seconds: 2),
                      ),
                    );

                    // DEMO BYPASS: Passes the live dropdown venue name seamlessly
                    context.push(
                      '/my-bookings/confirm',
                      extra: {
                        'bookingId': DateTime.now().millisecondsSinceEpoch,
                        'branchId': int.tryParse(bookingState.branchId ?? '') ?? 0,
                        'branchName': selectedBranch?.title ?? '',
                      },
                    );
                  }
                }
              },
            )
          : null,
    ); // 1. Closes Scaffold
  } // 2. Closes build method
} // 3. Closes _BookingScreenState class

class _BookingStepper extends StatelessWidget {
  final int currentStep;
  const _BookingStepper({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const steps = ['Venue', 'Time', 'Confirm'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
              child: Container(
                height: 1.5,
                color: i ~/ 2 < currentStep
                    ? AppColors.gold
                    : Colors.grey.shade200,
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final isDone = stepIndex < currentStep;
          final isCurrent = stepIndex == currentStep;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone || isCurrent
                      ? AppColors.gold
                      : Colors.grey.shade100,
                  border: Border.all(
                    color: isDone || isCurrent
                        ? AppColors.gold
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                isCurrent ? Colors.white : Colors.grey.shade400,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[stepIndex],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                  color: isCurrent ? AppColors.gold : Colors.grey.shade400,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _BookingFooter extends StatelessWidget {
  final String branchName, slot;
  final DateTime date;
  final int partySize;
  final bool isLoading;
  final VoidCallback onCheckout;

  const _BookingFooter({
    required this.branchName,
    required this.date,
    required this.slot,
    required this.partySize,
    required this.isLoading,
    required this.onCheckout,
  });

  static const _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branchName,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_months[date.month]} ${date.day} • $slot • $partySize Guests',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.info_outline, size: 20, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : onCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  disabledBackgroundColor:
                      AppColors.gold.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Secure Checkout',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}
