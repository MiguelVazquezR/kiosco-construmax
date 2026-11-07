import 'package:flutter/material.dart';

import '../../data/models/kiosk_context.dart';
import '../kiosk_theme.dart';

/// Step 2: "Con mi rostro" / "Con mi número de empleado".
class MethodSelector extends StatelessWidget {
  const MethodSelector({
    super.key,
    required this.onSelect,
    this.faceEnabled = true,
    this.employeeNumberEnabled = true,
    this.selectedTypeLabel,
  });

  final ValueChanged<IdentificationMethod> onSelect;
  final bool faceEnabled;
  final bool employeeNumberEnabled;
  final String? selectedTypeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KioskColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KioskColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selectedTypeLabel != null) ...[
            Text(
              'Tipo: $selectedTypeLabel',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: KioskColors.brand,
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            '¿Cómo quieres identificarte?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: KioskColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (faceEnabled)
            _MethodButton(
              icon: Icons.face_retouching_natural_rounded,
              label: 'Con mi rostro',
              subtitle: 'La cámara te reconoce automáticamente.',
              onTap: () => onSelect(IdentificationMethod.face),
            ),
          if (faceEnabled && employeeNumberEnabled) const SizedBox(height: 12),
          if (employeeNumberEnabled)
            _MethodButton(
              icon: Icons.dialpad_rounded,
              label: 'Con mi número de empleado',
              subtitle: 'Escribe tu número en el teclado.',
              onTap: () => onSelect(IdentificationMethod.employeeNumber),
            ),
        ],
      ),
    );
  }
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KioskColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KioskColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: KioskColors.brandSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: KioskColors.brand, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: KioskColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: KioskColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: KioskColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
