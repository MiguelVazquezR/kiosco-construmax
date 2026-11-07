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
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: KioskColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: KioskColors.danger,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: KioskColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: KioskColors.textMuted,
                ),
              ),
              if (detail != null && detail != title) ...[
                const SizedBox(height: 8),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: KioskColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 24),
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
