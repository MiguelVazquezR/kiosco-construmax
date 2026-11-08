import 'package:flutter/material.dart';

import '../kiosk_theme.dart';

/// The default right-hand panel: nothing selected yet ("En espera").
class WaitingPanel extends StatelessWidget {
  const WaitingPanel({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KioskColors.surface,
        borderRadius: KioskRadius.cardRadius,
        border: Border.all(color: KioskColors.border),
        boxShadow: KioskShadows.card,
      ),
      padding: const EdgeInsets.all(KioskSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final circleSize = constraints.maxHeight < 420 ? 72.0 : 92.0;
          final minHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 0.0;

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: const BoxDecoration(
                      color: KioskColors.brandSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.touch_app_rounded,
                      size: circleSize * 0.46,
                      color: KioskColors.brand,
                    ),
                  ),
                  const SizedBox(height: KioskSpacing.md),
                  const Text(
                    'En espera',
                    textAlign: TextAlign.center,
                    style: KioskText.sectionTitle,
                  ),
                  const SizedBox(height: KioskSpacing.xs),
                  Text(
                    message ?? 'Selecciona el tipo de fichaje para comenzar.',
                    textAlign: TextAlign.center,
                    style: KioskText.secondary.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
