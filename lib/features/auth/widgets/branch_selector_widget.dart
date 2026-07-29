import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/features/auth/providers/auth_provider.dart';

/// A dropdown location selector that fetches active branches from Supabase
/// and matches the existing TigerBay form input style precisely:
///   - BorderRadius.circular(14)
///   - Border color: AppColors.border (#E5E5EA)
///   - Focused border: AppColors.gold gold, width 1.5
///   - Error border: AppColors.error red
///   - Poppins font throughout
///   - Padding: horizontal 16, vertical 16
///
/// Usage:
///   BranchSelectorWidget(
///     selectedBranch: chosenHomeSite,
///     onChanged: (branch) => setState(() => chosenHomeSite = branch),
///     showError: _submitted && chosenHomeSite == null,
///   )
class BranchSelectorWidget extends ConsumerStatefulWidget {
  final Branch? selectedBranch;
  final ValueChanged<Branch?> onChanged;
  final bool showError;
  final String label;
  final String hint;

  const BranchSelectorWidget({
    super.key,
    required this.selectedBranch,
    required this.onChanged,
    this.showError = false,
    this.label = 'Home Location',
    this.hint = 'Select your nearest TigerBay venue',
  });

  @override
  ConsumerState<BranchSelectorWidget> createState() =>
      _BranchSelectorWidgetState();
}

class _BranchSelectorWidgetState extends ConsumerState<BranchSelectorWidget> {
  bool _isFocused = false;

  Color get _borderColor {
    if (widget.showError) return AppColors.error;
    if (_isFocused) return AppColors.gold;
    return AppColors.border;
  }

  double get _borderWidth {
    if (widget.showError) return 1.0;
    if (_isFocused) return 1.5;
    return 1.0;
  }

  void _openPicker(List<Branch> branches) async {
    setState(() => _isFocused = true);

    await showModalBottomSheet<Branch>(
      context: context,
      backgroundColor: const Color(0xFF0A0A0A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BranchPickerSheet(
        branches: branches,
        selected: widget.selectedBranch,
        onSelect: (branch) {
          widget.onChanged(branch);
          Navigator.pop(ctx);
        },
      ),
    );

    setState(() => _isFocused = false);
  }

  @override
  Widget build(BuildContext context) {
    final branchAsync = ref.watch(branchListForAuthProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        branchAsync.when(
          loading: () => _buildContainer(
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Loading venues…',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
            onTap: null,
          ),
          error: (error, stackTrace) {
            debugPrint('🚨 SUPABASE BRANCHES FETCH ERROR: $error');

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Debug Error: ${error.toString()}',
                      style: const TextStyle(fontFamily: 'Poppins', color: Colors.red, fontSize: 11),
                    ),
                  ),
                ],
              ),
            );
          },
          data: (branches) => _buildContainer(
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppColors.brandRed,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.selectedBranch?.title ?? widget.hint,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      color: widget.selectedBranch != null
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: Colors.white38,
                ),
              ],
            ),
            onTap: () => _openPicker(branches),
          ),
        ),
        if (widget.showError) ...[
          const SizedBox(height: 6),
          const Text(
            'Please select your home venue to continue',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: AppColors.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContainer({
    required Widget child,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _borderColor,
            width: _borderWidth,
          ),
        ),
        child: child,
      ),
    );
  }
}

// ── Bottom sheet picker ───────────────────────────────────────────────────────

class _BranchPickerSheet extends StatelessWidget {
  final List<Branch> branches;
  final Branch? selected;
  final ValueChanged<Branch> onSelect;

  const _BranchPickerSheet({
    required this.branches,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Select Your Home Venue',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your closest TigerBay International location',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: branches.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Color(0xFF1C1C1E), height: 1),
            itemBuilder: (_, i) {
              final branch = branches[i];
              final isSelected = selected?.id == branch.id;

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.brandRed.withValues(alpha: 0.1)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.storefront_outlined,
                    size: 20,
                    color: isSelected
                        ? AppColors.brandRed
                        : Colors.white38,
                  ),
                ),
                title: Text(
                  branch.title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: branch.city != null
                    ? Text(
                        branch.city!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : null,
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.gold, size: 22)
                    : null,
                onTap: () => onSelect(branch),
              );
            },
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ],
    );
  }
}
