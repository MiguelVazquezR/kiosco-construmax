import 'package:flutter/material.dart';

import '../../data/models/kiosk_context.dart';
import '../../state/kiosk_controller.dart';
import '../kiosk_theme.dart';

/// Step 2: "Con mi rostro" / "Con mi número de empleado".
///
/// The face option is always offered (same as the web kiosk); when the
/// biometric provider is not configured the subtitle says so instead of
/// hiding the method.
class MethodSelector extends StatelessWidget {
  const MethodSelector({
    super.key,
    required this.onSelect,
    this.faceConfigured = true,
    this.employeeNumberEnabled = true,
    this.selectedTypeLabel,
  });

  final ValueChanged<IdentificationMethod> onSelect;
  final bool faceConfigured;
  final bool employeeNumberEnabled;

  /// The type chosen in step 1, reminded at the top of the panel.
  final String? selectedTypeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KioskSpacing.lg),
      decoration: BoxDecoration(
        color: KioskColors.surface,
        borderRadius: KioskRadius.cardRadius,
        border: Border.all(color: KioskColors.border),
        boxShadow: KioskShadows.card,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The two options share the leftover height so the card never
          // overflows, even on a phone in landscape.
          final optionCount = employeeNumberEnabled ? 2 : 1;
          final titleHeight = constraints.maxWidth < 420 ? 48.0 : 27.0;
          final reminderHeight = selectedTypeLabel == null ? 0.0 : 32.0;
          final chrome =
              reminderHeight +
              titleHeight +
              KioskSpacing.md +
              (optionCount - 1) * KioskSpacing.sm;
          final available = constraints.maxHeight.isFinite
              ? constraints.maxHeight - chrome
              : optionCount * 112.0;
          final optionHeight = (available / optionCount).clamp(88.0, 116.0);

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selectedTypeLabel != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: KioskColors.brand,
                        ),
                        const SizedBox(width: KioskSpacing.xs),
                        Expanded(
                          child: Text(
                            'Tipo: $selectedTypeLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KioskText.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KioskSpacing.sm),
                  ],
                  const Text(
                    '¿Cómo quieres identificarte?',
                    style: KioskText.sectionTitle,
                  ),
                  const SizedBox(height: KioskSpacing.md),
                  SizedBox(
                    height: optionHeight,
                    child: _MethodButton(
                      icon: Icons.face_retouching_natural_rounded,
                      label: 'Con mi rostro',
                      subtitle: faceConfigured
                          ? 'La cámara te reconoce automáticamente.'
                          : KioskController.faceNotConfiguredMessage,
                      onTap: () => onSelect(IdentificationMethod.face),
                    ),
                  ),
                  if (employeeNumberEnabled) ...[
                    const SizedBox(height: KioskSpacing.sm),
                    SizedBox(
                      height: optionHeight,
                      child: _MethodButton(
                        icon: Icons.dialpad_rounded,
                        label: 'Con mi número de empleado',
                        subtitle: 'Escribe tu número en el teclado.',
                        onTap: () =>
                            onSelect(IdentificationMethod.employeeNumber),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final compact = height < 96;
        final iconBox = compact ? 44.0 : 52.0;
        final padding = compact ? KioskSpacing.sm : KioskSpacing.md;

        return Material(
          color: KioskColors.background,
          borderRadius: KioskRadius.optionRadius,
          child: InkWell(
            borderRadius: KioskRadius.optionRadius,
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: KioskRadius.optionRadius,
                border: Border.all(color: KioskColors.border),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: KioskSpacing.md,
                  vertical: padding,
                ),
                child: Row(
                  children: [
                    Container(
                      width: iconBox,
                      height: iconBox,
                      decoration: BoxDecoration(
                        color: KioskColors.brandSoft,
                        borderRadius: BorderRadius.circular(KioskRadius.button),
                      ),
                      child: Icon(
                        icon,
                        color: KioskColors.brand,
                        size: iconBox * 0.5,
                      ),
                    ),
                    const SizedBox(width: KioskSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KioskText.optionTitle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KioskText.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: KioskSpacing.xs),
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
      },
    );
  }
}
