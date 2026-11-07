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

    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: types.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.4,
      ),
      itemBuilder: (context, index) {
        final type = types[index];
        final selected = type.key == selectedKey;

        return _PunchTypeButton(
          label: type.label,
          icon: _icons[type.key] ?? Icons.fingerprint_rounded,
          selected: selected,
          onTap: enabled ? () => onSelect(type) : null,
        );
      },
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

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 30,
                  color: selected ? KioskColors.brand : KioskColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w600,
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
  }
}
