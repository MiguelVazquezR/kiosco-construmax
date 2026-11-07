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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KioskColors.border),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.touch_app_rounded,
            size: 56,
            color: KioskColors.brand,
          ),
          const SizedBox(height: 16),
          const Text(
            'En espera',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: KioskColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message ?? 'Selecciona el tipo de fichaje para comenzar.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: KioskColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
