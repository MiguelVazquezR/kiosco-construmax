import 'package:flutter/material.dart';

import '../kiosk_theme.dart';

/// Live preview of the front camera plus the capture / cancel controls.
///
/// The preview owns the whole card: the controls and the hint are overlaid on
/// the bottom edge, so the frame keeps every pixel available. That matters on
/// a tablet held in landscape, where stacked buttons used to leave room for a
/// single line of video.
///
/// [preview] is expected to fill its box by itself (cover: real frame ratio,
/// overflow cropped), so the card never stretches it to a different shape.
class CameraCard extends StatelessWidget {
  const CameraCard({
    super.key,
    required this.preview,
    required this.onCapture,
    required this.onCancel,
    this.ready = true,
    this.loading = false,
    this.hint,
    this.statusText,
    this.notice,
  });

  final Widget preview;
  final VoidCallback onCapture;
  final VoidCallback onCancel;
  final bool ready;
  final bool loading;
  final String? hint;
  final String? statusText;

  /// Warning shown under the hint, e.g. when the biometric provider is not
  /// configured on the server yet.
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final hasText = hint != null || statusText != null || notice != null;

    // The preview owns the whole card: the dark surface, the rounded corners
    // and every pixel of height belong to the camera frame.
    return ClipRRect(
      borderRadius: KioskRadius.cardRadius,
      child: ColoredBox(
        color: KioskColors.cameraBackground,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready) preview,
            // Oval guide so the collaborator centres the face.
            IgnorePointer(
              child: Center(
                child: FractionallySizedBox(
                  heightFactor: 0.82,
                  child: AspectRatio(
                    aspectRatio: 0.74,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(200),
                        border: Border.all(color: Colors.white70, width: 3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!ready)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(KioskSpacing.lg),
                  child: Text(
                    'La cámara no está disponible.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: KioskColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            // Controls and hint sit on a scrim over the bottom of the frame,
            // so they never take height away from the preview.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                // Flat 72 % scrim: the controls stay readable without
                // darkening the whole frame.
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(KioskSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasText)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hint != null)
                                Text(
                                  hint!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.3,
                                    color: Colors.white70,
                                  ),
                                ),
                              if (statusText != null) ...[
                                const SizedBox(height: KioskSpacing.xxs),
                                Text(
                                  statusText!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: KioskColors.white,
                                  ),
                                ),
                              ],
                              if (notice != null) ...[
                                const SizedBox(height: KioskSpacing.xxs),
                                Text(
                                  notice!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                    color: KioskColors.cameraWarning,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (hasText) const SizedBox(width: KioskSpacing.md),
                      OutlinedButton.icon(
                        onPressed: loading ? null : onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KioskColors.white,
                          backgroundColor: Colors.transparent,
                          disabledForegroundColor: Colors.white38,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(
                            horizontal: KioskSpacing.lg,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: KioskRadius.buttonRadius,
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        label: const Text('Cancelar'),
                      ),
                      const SizedBox(width: KioskSpacing.sm),
                      FilledButton.icon(
                        onPressed: loading || !ready ? null : onCapture,
                        style: FilledButton.styleFrom(
                          backgroundColor: KioskColors.brand,
                          foregroundColor: KioskColors.white,
                          disabledBackgroundColor: Colors.white.withValues(
                            alpha: 0.24,
                          ),
                          disabledForegroundColor: Colors.white54,
                          minimumSize: const Size(0, 58),
                          padding: const EdgeInsets.symmetric(
                            horizontal: KioskSpacing.xl,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: KioskRadius.buttonRadius,
                          ),
                        ),
                        icon: loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: KioskColors.white,
                                ),
                              )
                            : const Icon(Icons.camera_alt_rounded, size: 20),
                        label: const Text('Capturar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
