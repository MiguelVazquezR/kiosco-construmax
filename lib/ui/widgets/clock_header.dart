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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: KioskColors.surface,
        border: Border(bottom: BorderSide(color: KioskColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 44,
            decoration: BoxDecoration(
              color: KioskColors.brand,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.deviceName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: KioskColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.deviceLocation == null
                      ? widget.appName
                      : '${widget.appName} · ${widget.deviceLocation}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: KioskColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (widget.clockDriftWarning)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(
                Icons.warning_amber_rounded,
                color: KioskColors.brand,
                size: 26,
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: KioskColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: KioskColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
