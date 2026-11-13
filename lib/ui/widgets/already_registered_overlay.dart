import 'package:flutter/material.dart';

import '../../data/models/punch_not_allowed.dart';
import '../kiosk_theme.dart';

/// Full-screen dialog shown when the server rejects a punch because the daily
/// sequence does not allow it (duplicate or out of order).
class AlreadyRegisteredOverlay extends StatelessWidget {
  const AlreadyRegisteredOverlay({
    super.key,
    required this.rejection,
    required this.onDismiss,
  });

  final PunchNotAllowed rejection;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: KioskColors.dangerScrim,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KioskSpacing.xl),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
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
                      color: KioskColors.dangerSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: KioskColors.danger,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: KioskSpacing.md),
                  Text(
                    rejection.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: KioskColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: KioskSpacing.sm),
                  Text(
                    rejection.message,
                    textAlign: TextAlign.center,
                    style: KioskText.body,
                  ),
                  if (rejection.lastRegisteredAt != null) ...[
                    const SizedBox(height: KioskSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KioskSpacing.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: KioskColors.dangerSoft,
                        borderRadius: KioskRadius.bannerRadius,
                        border: Border.all(color: KioskColors.dangerBorder),
                      ),
                      child: Text(
                        '${rejection.typeLabel} · Registrado a las '
                        '${rejection.lastRegisteredAt}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: KioskColors.danger,
                        ),
                      ),
                    ),
                  ],
                  if (rejection.showsHint) ...[
                    const SizedBox(height: KioskSpacing.sm),
                    const Text(
                      PunchNotAllowed.hint,
                      textAlign: TextAlign.center,
                      style: KioskText.secondary,
                    ),
                  ],
                  const SizedBox(height: KioskSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: KioskColors.danger,
                      ),
                      onPressed: onDismiss,
                      child: const Text('Elegir otro registro'),
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
