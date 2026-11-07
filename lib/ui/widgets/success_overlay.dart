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
        color: const Color(0xE611161C),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: KioskColors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6F5EF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: KioskColors.success,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Registro exitoso',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: KioskColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (result.userName.isNotEmpty)
                    Text(
                      result.userName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: KioskColors.textPrimary,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '${result.typeLabel} · ${result.punchedAt}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
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
