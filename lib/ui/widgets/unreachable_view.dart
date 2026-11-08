import 'package:flutter/material.dart';

import '../kiosk_theme.dart';

/// Shown when the server cannot be reached. The kiosk retries by itself every
/// 15 seconds; the button forces an immediate attempt.
class UnreachableView extends StatelessWidget {
  const UnreachableView({
    super.key,
    required this.onRetry,
    this.title = 'No se pudo conectar con el servidor.',
    this.hint = 'Verifica la red del dispositivo.',
    this.detail,
  });

  final VoidCallback onRetry;
  final String title;
  final String hint;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: KioskColors.surface,
            borderRadius: KioskRadius.cardRadius,
            border: Border.all(color: KioskColors.border),
            boxShadow: KioskShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: const BoxDecoration(
                  color: KioskColors.dangerSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 52,
                  color: KioskColors.danger,
                ),
              ),
              const SizedBox(height: KioskSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: KioskColors.textPrimary,
                ),
              ),
              const SizedBox(height: KioskSpacing.xs),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: KioskText.secondary.copyWith(height: 1.4),
              ),
              if (detail != null && detail != title) ...[
                const SizedBox(height: KioskSpacing.xs),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: KioskText.caption,
                ),
              ],
              const SizedBox(height: KioskSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onRetry,
                  child: const Text('Reintentar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
