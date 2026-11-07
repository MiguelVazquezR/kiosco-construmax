import 'package:flutter/material.dart';

import '../kiosk_theme.dart';

/// Numeric keypad used by the employee-number method.
class KeypadCard extends StatelessWidget {
  const KeypadCard({
    super.key,
    required this.value,
    required this.onKey,
    required this.onDelete,
    required this.onClear,
    required this.onSubmit,
    required this.onCancel,
    this.notice,
    this.loading = false,
    this.statusText,
  });

  final String value;
  final ValueChanged<String> onKey;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final String? notice;
  final bool loading;
  final String? statusText;

  static const List<String> _digits = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KioskColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KioskColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'NÚMERO DE EMPLEADO',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: KioskColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KioskColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KioskColors.border),
            ),
            child: Text(
              value.isEmpty ? 'Número de empleado' : value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: value.isEmpty
                    ? KioskColors.textMuted
                    : KioskColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.7,
              children: [
                for (final digit in _digits)
                  _KeyButton(
                    label: digit,
                    onTap: loading ? null : () => onKey(digit),
                  ),
                _KeyButton(
                  label: 'Limpiar',
                  small: true,
                  onTap: loading ? null : onClear,
                ),
                _KeyButton(
                  label: '0',
                  onTap: loading ? null : () => onKey('0'),
                ),
                _KeyButton(
                  icon: Icons.backspace_outlined,
                  onTap: loading ? null : onDelete,
                ),
              ],
            ),
          ),
          if (statusText != null) ...[
            const SizedBox(height: 8),
            Text(
              statusText!,
              style: const TextStyle(
                fontSize: 13,
                color: KioskColors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (notice != null) ...[
            Text(
              notice!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: KioskColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: loading ? null : onSubmit,
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text('Registrar'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: loading ? null : onCancel,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    this.label,
    this.icon,
    this.onTap,
    this.small = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KioskColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KioskColors.border),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, size: 22, color: KioskColors.textPrimary)
                : Text(
                    label ?? '',
                    style: TextStyle(
                      fontSize: small ? 14 : 22,
                      fontWeight: FontWeight.w700,
                      color: KioskColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
