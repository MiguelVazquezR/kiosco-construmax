import 'package:flutter/material.dart';

import '../kiosk_theme.dart';

/// Numeric keypad used by the employee-number method.
///
/// While it is open the screen hides the punch-type grid, so this card owns
/// almost the whole viewport. The keys are sized from the available height:
/// even on a phone the display, every key and both actions stay visible
/// without scrolling (scrolling is only the last-resort fallback).
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

  static const List<List<String>> _digitRows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight.isFinite && constraints.maxHeight < 560;
        final pad = compact ? 12.0 : KioskSpacing.lg;
        final gap = compact ? 6.0 : KioskSpacing.xs;
        final rowGap = compact ? 6.0 : 10.0;
        final displayHeight = compact ? 46.0 : 64.0;
        final submitHeight = compact ? 48.0 : 60.0;
        final cancelHeight = compact ? 44.0 : 52.0;
        final labelHeight = compact ? 14.0 : 16.0;

        // Everything that is not a key row, so the four rows split the rest.
        final chrome =
            pad * 2 +
            labelHeight +
            gap + // "NÚMERO DE EMPLEADO" label
            displayHeight +
            gap +
            (statusText != null ? (compact ? 22.0 : 26.0) : 0.0) +
            (notice != null ? (compact ? 40.0 : 44.0) : 0.0) +
            gap + // spacing before the actions
            submitHeight +
            gap +
            cancelHeight;

        final available = constraints.maxHeight.isFinite
            ? constraints.maxHeight - chrome
            : 4 * 64.0;
        final keyHeight = (available / 4 - rowGap).clamp(
          compact ? 40.0 : 48.0,
          compact ? 64.0 : 76.0,
        );

        return Container(
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: KioskColors.surface,
            borderRadius: KioskRadius.cardRadius,
            border: Border.all(color: KioskColors.border),
            boxShadow: KioskShadows.card,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NÚMERO DE EMPLEADO',
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    letterSpacing: compact ? 1.2 : 1.4,
                    fontWeight: FontWeight.w700,
                    color: KioskColors.textMuted,
                  ),
                ),
                SizedBox(height: gap),
                _buildDisplay(compact: compact, height: displayHeight),
                SizedBox(height: gap),
                ..._buildDigitRows(
                  compact: compact,
                  height: keyHeight,
                  gap: rowGap,
                ),
                _buildSecondaryRow(
                  compact: compact,
                  height: keyHeight,
                  gap: rowGap,
                ),
                if (statusText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    statusText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: KioskColors.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                SizedBox(height: gap),
                if (notice != null) ...[
                  Text(
                    notice!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      height: 1.3,
                      color: KioskColors.textMuted,
                    ),
                  ),
                  SizedBox(height: gap),
                ],
                _buildSubmit(compact: compact, height: submitHeight),
                SizedBox(height: gap),
                SizedBox(
                  height: cancelHeight,
                  child: OutlinedButton(
                    onPressed: loading ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      textStyle: TextStyle(
                        fontSize: compact ? 15 : 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDisplay({required bool compact, required double height}) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: KioskColors.background,
        borderRadius: KioskRadius.displayRadius,
        border: Border.all(color: KioskColors.border),
      ),
      child: Text(
        value.isEmpty ? 'Número de empleado' : value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 26 : 34,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: value.isEmpty
              ? KioskColors.textMuted
              : KioskColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSubmit({required bool compact, required double height}) {
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: loading ? null : onSubmit,
        style: FilledButton.styleFrom(
          textStyle: TextStyle(
            fontSize: compact ? 16 : 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: KioskColors.white,
                ),
              )
            : const Text('Registrar'),
      ),
    );
  }

  List<Widget> _buildDigitRows({
    required bool compact,
    required double height,
    required double gap,
  }) {
    return [
      for (final row in _digitRows) ...[
        _row(
          [for (final digit in row) _digitKey(digit, compact)],
          height: height,
          gap: gap,
        ),
        SizedBox(height: gap),
      ],
    ];
  }

  Widget _buildSecondaryRow({
    required bool compact,
    required double height,
    required double gap,
  }) {
    return _row(
      [
        _KeyButton(
          label: 'Limpiar',
          small: true,
          dense: compact,
          onTap: loading ? null : onClear,
        ),
        _digitKey('0', compact),
        _KeyButton(
          icon: Icons.backspace_outlined,
          dense: compact,
          onTap: loading ? null : onDelete,
        ),
      ],
      height: height,
      gap: gap,
    );
  }

  Widget _digitKey(String digit, bool compact) => _KeyButton(
    label: digit,
    dense: compact,
    onTap: loading ? null : () => onKey(digit),
  );

  Widget _row(
    List<Widget> keys, {
    required double height,
    required double gap,
  }) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: keys[i]),
          ],
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
    this.dense = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool small;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KioskColors.background,
      borderRadius: KioskRadius.keyRadius,
      child: InkWell(
        borderRadius: KioskRadius.keyRadius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: KioskRadius.keyRadius,
            border: Border.all(color: KioskColors.border),
          ),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    size: dense ? 22 : 26,
                    color: KioskColors.textPrimary,
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label ?? '',
                      style: TextStyle(
                        fontSize: small ? (dense ? 12 : 14) : (dense ? 22 : 26),
                        fontWeight: FontWeight.w700,
                        color: KioskColors.textPrimary,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
