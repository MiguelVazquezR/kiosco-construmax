import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../kiosk_theme.dart';

/// Top bar: app/device name, location and the live clock.
class ClockHeader extends StatefulWidget {
  const ClockHeader({
    super.key,
    required this.appName,
    required this.deviceName,
    this.deviceLocation,
    this.clockDriftWarning = false,
  });

  final String appName;
  final String deviceName;
  final String? deviceLocation;
  final bool clockDriftWarning;

  @override
  State<ClockHeader> createState() => _ClockHeaderState();
}

class _ClockHeaderState extends State<ClockHeader> {
  static const List<String> _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static const List<String> _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(_now);
    final dateLabel =
        '${_weekdays[_now.weekday - 1]} ${_now.day} de ${_months[_now.month - 1]}';

    // On narrow screens (phones held in portrait) the date and the big clock
    // would squeeze the device name until it wraps one character per line, so
    // the header shrinks to the essential: name + time.
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final subtitle = widget.deviceLocation == null
            ? widget.appName
            : '${widget.appName} · ${widget.deviceLocation}';

        return Container(
          constraints: BoxConstraints(minHeight: compact ? 76 : 88),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 24,
            vertical: compact ? 10 : 12,
          ),
          decoration: const BoxDecoration(
            color: KioskColors.surface,
            border: Border(bottom: BorderSide(color: KioskColors.border)),
          ),
          child: Row(
            children: [
              // Discreet brand accent next to the identity block.
              Container(
                width: compact ? 4 : 5,
                height: 36,
                decoration: BoxDecoration(
                  color: KioskColors.brand,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: KioskSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: compact
                          ? KioskText.deviceNameCompact
                          : KioskText.deviceName,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KioskText.caption,
                    ),
                  ],
                ),
              ),
              if (widget.clockDriftWarning)
                const Padding(
                  padding: EdgeInsets.only(right: KioskSpacing.sm),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: KioskColors.warningText,
                    size: 24,
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    maxLines: 1,
                    style: compact ? KioskText.clockCompact : KioskText.clock,
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Text(dateLabel, maxLines: 1, style: KioskText.caption),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
