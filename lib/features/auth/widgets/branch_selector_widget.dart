import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/theme/app_typography.dart';
import 'package:tigerbay_app/features/auth/providers/auth_provider.dart';

/// A dropdown location selector that fetches active branches from Supabase
/// and matches the existing TigerBay form input style precisely:
///   - BorderRadius.circular(16)
///   - Border color: Color(0xFF28282B)
///   - Focused border: AppColors.champagneGold, width 1.2
///   - Error border: AppColors.error red
///   - Apple typography throughout
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
    if (_isFocused) return AppColors.champagneGold;
    return const Color(0xFF28282B);
  }

  double get _borderWidth {
    if (widget.showError) return 1.0;
    if (_isFocused) return 1.2;
    return 0.9;
  }

  void _openPicker(List<Branch> branches) async {
    setState(() => _isFocused = true);

    await showModalBottomSheet<Branch>(
      context: context,
      backgroundColor: const Color(0xFF141416),
      barrierColor: Colors.black.withValues(alpha: 0.75),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: AppTypography.caption1.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
        ],
        branchAsync.when(
          loading: () => _buildContainer(
            child: Row(
              children: [
                const CupertinoActivityIndicator(
                  radius: 8,
                  color: AppColors.champagneGold,
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading venues…',
                  style: AppTypography.body.copyWith(
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
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.exclamationmark_triangle,
                      color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Debug Error: ${error.toString()}',
                      style: AppTypography.caption1.copyWith(color: Colors.red),
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
                  CupertinoIcons.location_solid,
                  size: 18,
                  color: AppColors.champagneGold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.selectedBranch?.title ?? widget.hint,
                    style: AppTypography.body.copyWith(
                      color: widget.selectedBranch != null
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 16,
                  color: AppColors.textHint,
                ),
              ],
            ),
            onTap: () => _openPicker(branches),
          ),
        ),
        if (widget.showError) ...[
          const SizedBox(height: 6),
          Text(
            'Please select your home venue to continue',
            style: AppTypography.caption1.copyWith(
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
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
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
        Text(
          'Select Your Home Venue',
          style: AppTypography.title3.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your closest TigerBay International location',
          style: AppTypography.caption1.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        const Divider(color: Color(0xFF28282B), height: 1),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: branches.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Color(0xFF1C1C1E), height: 1),
            itemBuilder: (_, i) {
              final branch = branches[i];
              final isSelected = selected?.id == branch.id;

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.champagneGold.withValues(alpha: 0.15)
                        : const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.champagneGold.withValues(alpha: 0.4)
                          : const Color(0xFF28282B),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.building_2_fill,
                    size: 18,
                    color: isSelected
                        ? AppColors.champagneGold
                        : AppColors.textSecondary,
                  ),
                ),
                title: Text(
                  branch.title,
                  style: AppTypography.body.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.champagneGold
                        : AppColors.textPrimary,
                  ),
                ),
                subtitle: branch.city != null
                    ? Text(
                        branch.city!,
                        style: AppTypography.caption1.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      )
                    : null,
                trailing: isSelected
                    ? const Icon(CupertinoIcons.checkmark_circle_fill,
                        color: AppColors.champagneGold, size: 20)
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
