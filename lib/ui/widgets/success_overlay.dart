import 'package:flutter/material.dart';

import '../../data/models/punch_result.dart';
import '../kiosk_theme.dart';

/// Full-screen confirmation shown for seven seconds after a punch.
class SuccessOverlay extends StatelessWidget {
  const SuccessOverlay({
    super.key,
    required this.result,
    required this.onDismiss,
  });

  final PunchResult result;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: KioskColors.successScrim,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: KioskColors.surface,
                borderRadius: KioskRadius.overlayRadius,
                boxShadow: KioskShadows.card,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: KioskColors.successSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: KioskColors.success,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: KioskSpacing.md),
                  const Text(
                    'Registro exitoso',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: KioskColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: KioskSpacing.sm),
                  if (result.userName.isNotEmpty)
                    Text(
                      result.userName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: KioskColors.textPrimary,
                      ),
                    ),
                  const SizedBox(height: KioskSpacing.xs),
                  Text(
                    '${result.typeLabel} · ${result.punchedAt}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: KioskColors.brand,
                    ),
                  ),
                  if (result.dateLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      result.dateLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: KioskColors.textMuted,
                      ),
                    ),
                  ],
                  if (result.suggestedNextLabel != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Siguiente registro sugerido: '
                      '${result.suggestedNextLabel}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: KioskColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onDismiss,
                      child: const Text('Continuar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
