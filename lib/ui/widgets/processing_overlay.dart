import 'package:flutter/material.dart';

import '../kiosk_theme.dart';

/// Blocks the whole kiosk while a punch is being sent, so a double tap or a
/// second collaborator cannot start another request (see §5).
class ProcessingOverlay extends StatelessWidget {
  const ProcessingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: KioskColors.overlayScrim,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: KioskColors.surface,
                borderRadius: KioskRadius.overlayRadius,
                boxShadow: KioskShadows.card,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(strokeWidth: 4),
                  ),
                  const SizedBox(height: KioskSpacing.md),
                  const Text(
                    'Procesando tu registro…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: KioskColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: KioskSpacing.xs),
                  Text(
                    'Esto tarda solo un momento.',
                    textAlign: TextAlign.center,
                    style: KioskText.secondary,
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
