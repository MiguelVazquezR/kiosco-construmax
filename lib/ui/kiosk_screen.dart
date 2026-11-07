import 'package:flutter/material.dart';

import '../data/models/kiosk_context.dart';
import '../state/kiosk_controller.dart';
import 'kiosk_theme.dart';
import 'widgets/banners.dart';
import 'widgets/camera_card.dart';
import 'widgets/clock_header.dart';
import 'widgets/keypad_card.dart';
import 'widgets/method_selector.dart';
import 'widgets/punch_type_grid.dart';
import 'widgets/success_overlay.dart';
import 'widgets/unreachable_view.dart';
import 'widgets/waiting_panel.dart';

/// The whole kiosk: header with the clock, punch-type selector, identification
/// selector, camera preview or keypad, and the success overlay.
class KioskScreen extends StatefulWidget {
  const KioskScreen({super.key, required this.controller});

  final KioskController controller;

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> {
  KioskController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final status = _controller.status;

              return Stack(
                children: [
                  Column(
                    children: [
                      if (status == KioskStatus.ready)
                        ClockHeader(
                          appName: _controller.appName,
                          deviceName: _controller.deviceName,
                          deviceLocation: _controller.deviceLocation,
                          clockDriftWarning: _controller.clockDriftWarning,
                        ),
                      if (status == KioskStatus.ready &&
                          _controller.clockDriftWarning)
                        const WarningBanner(
                          message: KioskController.clockDriftMessage,
                          icon: Icons.schedule_rounded,
                        ),
                      if (status == KioskStatus.ready &&
                          _controller.locationPermissionMissing)
                        const WarningBanner(
                          message:
                              'La ubicación está desactivada. Actívala para registrar tu fichaje.',
                        ),
                      Expanded(child: _buildBody(status)),
                    ],
                  ),
                  if (_controller.lastResult != null)
                    SuccessOverlay(
                      result: _controller.lastResult!,
                      onDismiss: _controller.dismissSuccess,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(KioskStatus status) {
    switch (status) {
      case KioskStatus.checking:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 20),
              Text(
                KioskController.verifyingMessage,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: KioskColors.textMuted,
                ),
              ),
            ],
          ),
        );
      case KioskStatus.unreachable:
        return UnreachableView(
          onRetry: _controller.retry,
          detail: _controller.errorMessage,
        );
      case KioskStatus.ready:
        return _buildReady();
    }
  }

  Widget _buildReady() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;
        final types = _buildTypeSection();
        final identification = _buildIdentificationSection();

        if (isWide) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: types),
                const SizedBox(width: 20),
                Expanded(flex: 4, child: identification),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(flex: 4, child: types),
              const SizedBox(height: 16),
              Expanded(flex: 6, child: identification),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeSection() {
    final selected = _controller.selectedType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '1. Elige el tipo de fichaje',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: KioskColors.textPrimary,
                ),
              ),
            ),
            if (selected != null)
              TextButton.icon(
                onPressed: _controller.isSubmitting
                    ? null
                    : _controller.clearType,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Cambiar tipo'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: PunchTypeGrid(
            types: _controller.punchTypes,
            selectedKey: selected?.key,
            enabled: !_controller.isSubmitting,
            onSelect: _controller.selectType,
          ),
        ),
      ],
    );
  }

  Widget _buildIdentificationSection() {
    final error = _controller.errorMessage;
    final statusText = _controller.isLocating ? 'Obteniendo ubicación…' : null;

    Widget panel;
    if (!_controller.faceEnabled && !_controller.employeeNumberEnabled) {
      panel = const WaitingPanel(
        hasMethods: false,
        message: KioskController.noMethodMessage,
      );
    } else if (_controller.method == IdentificationMethod.face) {
      panel = CameraCard(
        preview: _controller.camera?.buildPreview() ?? const SizedBox.shrink(),
        ready: _controller.cameraReady,
        loading: _controller.isSubmitting,
        hint: KioskController.faceHint,
        statusText: statusText,
        onCapture: _controller.submitFace,
        // Closing the preview returns the kiosk to "En espera".
        onCancel: _controller.clearType,
      );
    } else if (_controller.method == IdentificationMethod.employeeNumber) {
      panel = KeypadCard(
        value: _controller.employeeNumber,
        loading: _controller.isSubmitting,
        statusText: statusText,
        notice: KioskController.personalNotice,
        onKey: _controller.appendKey,
        onDelete: _controller.deleteLastKey,
        onClear: _controller.clearNumber,
        onSubmit: _controller.submitEmployeeNumber,
        // Closing the keypad returns the kiosk to "En espera".
        onCancel: _controller.clearType,
      );
    } else if (_controller.selectedType != null) {
      panel = MethodSelector(
        faceEnabled: _controller.faceEnabled,
        employeeNumberEnabled: _controller.employeeNumberEnabled,
        selectedTypeLabel: _controller.selectedType?.label,
        onSelect: _controller.selectMethod,
      );
    } else {
      panel = const WaitingPanel();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          ErrorBanner(message: error),
          const SizedBox(height: 12),
        ],
        Expanded(child: panel),
      ],
    );
  }
}
