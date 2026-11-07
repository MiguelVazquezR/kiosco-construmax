import 'package:flutter/material.dart';

import '../kiosk_theme.dart';

/// The default right-hand panel: nothing selected yet ("En espera").
class WaitingPanel extends StatelessWidget {
  const WaitingPanel({
    super.key,
    this.message,
    this.hasMethods = true,
  });

  final String? message;

  /// `false` when the ERP disabled every identification method.
  final bool hasMethods;

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
          Icon(
            hasMethods ? Icons.touch_app_rounded : Icons.report_problem_rounded,
            size: 56,
            color: hasMethods ? KioskColors.brand : KioskColors.danger,
          ),
          const SizedBox(height: 16),
          Text(
            hasMethods ? 'En espera' : 'Sin método de registro',
            textAlign: TextAlign.center,
            style: const TextStyle(
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
