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

class _KioskScreenState extends State<KioskScreen> with WidgetsBindingObserver {
  KioskController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The operator may have turned the location switch on (or granted the
    // permission) in the OS settings, so the banner is refreshed on resume.
    if (state == AppLifecycleState.resumed) {
      _controller.refreshLocationState();
    }
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
                        WarningBanner(
                          message: KioskController.locationDisabledMessage,
                          actionLabel: _controller.isEnablingLocation
                              ? KioskController.locationEnablingAction
                              : KioskController.locationEnableAction,
                          onAction: _controller.isEnablingLocation
                              ? null
                              : _controller.enableLocation,
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
                width: 44,
                height: 44,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: KioskSpacing.lg),
              Text(
                KioskController.verifyingMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
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
        final identification = _buildIdentificationSection();
        final isWide = constraints.maxWidth >= 820;

        // Step 2 in progress (camera preview or keypad): it takes the whole
        // screen. The punch-type grid is hidden so the keypad fits even on a
        // small phone, where it used to be pushed out of view.
        if (_controller.method != null) {
          const vertical = KioskSpacing.md;
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? KioskSpacing.lg : KioskSpacing.md,
              vertical: vertical,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // A landscape tablet has plenty of width, so the preview can
                  // be wider than the phone-friendly 640.
                  maxWidth: isWide ? 960 : 640,
                  maxHeight: (constraints.maxHeight - vertical * 2).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: identification,
              ),
            ),
          );
        }

        final types = _buildTypeSection();

        if (isWide) {
          return Padding(
            padding: KioskSpacing.pageLandscape,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 56, child: types),
                const SizedBox(width: KioskSpacing.xl),
                Expanded(flex: 44, child: identification),
              ],
            ),
          );
        }

        return Padding(
          padding: KioskSpacing.pagePortrait,
          child: Column(
            children: [
              Expanded(flex: 46, child: types),
              const SizedBox(height: KioskSpacing.md),
              Expanded(flex: 54, child: identification),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeSection() {
    final selected = _controller.selectedType;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        final onChange = _controller.isSubmitting
            ? null
            : _controller.clearType;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '1. Elige el tipo de fichaje',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KioskText.screenTitle,
                  ),
                ),
                if (selected != null)
                  if (narrow)
                    IconButton(
                      onPressed: onChange,
                      tooltip: 'Cambiar tipo',
                      color: KioskColors.brand,
                      icon: const Icon(Icons.close_rounded),
                    )
                  else
                    TextButton.icon(
                      onPressed: onChange,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: KioskSpacing.sm,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Cambiar tipo'),
                    ),
              ],
            ),
            const SizedBox(height: KioskSpacing.sm),
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
      },
    );
  }

  Widget _buildIdentificationSection() {
    final error = _controller.errorMessage;
    final statusText = _controller.isLocating ? 'Obteniendo ubicación…' : null;

    Widget panel;
    if (_controller.method == IdentificationMethod.face) {
      panel = CameraCard(
        preview: _controller.camera?.buildPreview() ?? const SizedBox.shrink(),
        ready: _controller.cameraReady,
        aspectRatio: _controller.camera?.previewAspectRatio,
        loading: _controller.isSubmitting,
        hint: KioskController.faceHint,
        // The face method is always offered (like the web kiosk); when the
        // biometric provider is not ready the camera warns instead of hiding.
        notice: _controller.faceConfigured
            ? null
            : KioskController.faceNotConfiguredMessage,
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
        faceConfigured: _controller.faceConfigured,
        employeeNumberEnabled: _controller.employeeNumberEnabled,
        selectedTypeLabel: _controller.selectedType?.label,
        onSelect: _controller.selectMethod,
      );
    } else {
      panel = const WaitingPanel();
    }

    final selectedType = _controller.selectedType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          ErrorBanner(message: error),
          const SizedBox(height: 12),
        ],
        // Step 2 hides the punch-type grid, so the chosen type is reminded
        // here; "Cambiar tipo" goes back to "En espera".
        if (_controller.method != null && selectedType != null) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 520;

              return Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: KioskColors.brand,
                  ),
                  const SizedBox(width: KioskSpacing.xs),
                  Expanded(
                    child: Text(
                      'Tipo: ${selectedType.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KioskText.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (narrow)
                    IconButton(
                      onPressed: _controller.isSubmitting
                          ? null
                          : _controller.clearType,
                      tooltip: 'Cambiar tipo',
                      color: KioskColors.brand,
                      icon: const Icon(Icons.close_rounded),
                    )
                  else
                    TextButton(
                      onPressed: _controller.isSubmitting
                          ? null
                          : _controller.clearType,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: KioskSpacing.sm,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Cambiar tipo'),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: KioskSpacing.xs),
        ],
        Expanded(child: panel),
      ],
    );
  }
}
