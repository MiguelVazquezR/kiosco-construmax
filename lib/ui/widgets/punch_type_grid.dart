import 'package:flutter/material.dart';

import '../../data/models/kiosk_context.dart';
import '../kiosk_theme.dart';

/// Step 1: the six punch types sent by `/bootstrap`, rendered in a 2×3 grid.
class PunchTypeGrid extends StatelessWidget {
  const PunchTypeGrid({
    super.key,
    required this.types,
    required this.onSelect,
    this.selectedKey,
    this.enabled = true,
  });

  final List<PunchType> types;
  final ValueChanged<PunchType> onSelect;
  final String? selectedKey;
  final bool enabled;

  static const Map<String, IconData> _icons = {
    'check_in': Icons.login_rounded,
    'lunch_start': Icons.restaurant_rounded,
    'lunch_end': Icons.restaurant_menu_rounded,
    'break_start': Icons.logout_rounded,
    'break_end': Icons.replay_rounded,
    'check_out': Icons.exit_to_app_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty) {
      return const Center(
        child: Text(
          'No hay tipos de fichaje disponibles.',
          style: TextStyle(color: KioskColors.textMuted),
        ),
      );
    }

    // Fixed 2×3 grid (never scrolls): the six options must always be visible.
    const spacing = KioskSpacing.sm;
    final rows = (types.length / 2).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final available = maxHeight.isFinite
            ? maxHeight
            : rows * 96.0 + spacing * (rows - 1);
        final rowHeight = ((available - spacing * (rows - 1)) / rows).clamp(
          48.0,
          100.0,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) const SizedBox(height: spacing),
              SizedBox(
                height: rowHeight,
                child: Row(
                  children: [
                    for (var column = 0; column < 2; column++) ...[
                      if (column > 0) const SizedBox(width: spacing),
                      Expanded(child: _buildTile(row * 2 + column)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTile(int index) {
    if (index >= types.length) {
      return const SizedBox.shrink();
    }
    final type = types[index];
    return _PunchTypeButton(
      label: type.label,
      icon: _icons[type.key] ?? Icons.fingerprint_rounded,
      selected: type.key == selectedKey,
      onTap: enabled ? () => onSelect(type) : null,
    );
  }
}

class _PunchTypeButton extends StatelessWidget {
  const _PunchTypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? KioskColors.brand : KioskColors.border;
    final background = selected ? KioskColors.brandSoft : KioskColors.surface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final iconSize = height < 60 ? 24.0 : 30.0;

        return Material(
          color: background,
          borderRadius: KioskRadius.optionRadius,
          child: InkWell(
            borderRadius: KioskRadius.optionRadius,
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: KioskRadius.optionRadius,
                border: Border.all(color: borderColor, width: selected ? 2 : 1),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KioskSpacing.md,
                  vertical: KioskSpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: iconSize,
                      color: selected
                          ? KioskColors.brand
                          : KioskColors.textMuted,
                    ),
                    const SizedBox(width: KioskSpacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: height < 64 ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: KioskText.optionTitle.copyWith(
                          fontSize: height < 60 ? 15 : 17,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? KioskColors.brand
                              : KioskColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
