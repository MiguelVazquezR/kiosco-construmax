import 'package:flutter/material.dart';

import '../kiosk_theme.dart';

/// Surfaces a message near the punch controls. Validation errors and the
/// location warning share the same slot (§5).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: KioskSpacing.md,
        vertical: KioskSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: KioskColors.dangerSoft,
        borderRadius: KioskRadius.bannerRadius,
        border: Border.all(color: KioskColors.dangerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: KioskColors.danger,
            size: 22,
          ),
          const SizedBox(width: KioskSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                height: 1.3,
                color: KioskColors.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Persistent warning banner shown while the kiosk needs the operator's
/// attention (location disabled, wrong device clock). It can carry a short
/// action (`Activar`) so the operator fixes the problem without leaving the
/// kiosk.
class WarningBanner extends StatelessWidget {
  const WarningBanner({
    super.key,
    required this.message,
    this.icon = Icons.location_off_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: KioskSpacing.md,
        vertical: KioskSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: KioskColors.warningSoft,
        border: Border(bottom: BorderSide(color: KioskColors.warningBorder)),
      ),
      child: Row(
        children: [
          Icon(icon, color: KioskColors.warningText, size: 22),
          const SizedBox(width: KioskSpacing.sm),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.3,
                color: KioskColors.warningText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: KioskSpacing.xs),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: KioskColors.warningText,
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: KioskSpacing.sm,
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
