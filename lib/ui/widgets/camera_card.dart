import 'package:flutter/material.dart';

import '../kiosk_theme.dart';

/// Live preview of the front camera plus the capture / cancel controls.
///
/// The preview owns the whole card: the controls and the hint are overlaid on
/// the bottom edge, so the frame keeps every pixel available. That matters on
/// a tablet held in landscape, where stacked buttons used to leave room for a
/// single line of video.
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
    this.aspectRatio,
  });

  final Widget preview;
  final VoidCallback onCapture;
  final VoidCallback onCancel;
  final bool ready;
  final bool loading;
  final String? hint;
  final String? statusText;

  /// Width / height ratio of the frame as it must be drawn. When known (e.g.
  /// `4 / 3` in landscape) the preview covers the card instead of being
  /// stretched to its box.
  final double? aspectRatio;

  /// Warning shown under the hint, e.g. when the biometric provider is not
  /// configured on the server yet.
  final String? notice;

  @override
  Widget build(BuildContext context) {
    // Portrait fallback for a camera that has not reported its ratio yet.
    final ratio = aspectRatio ?? 3 / 4;
    final hasText = hint != null || statusText != null || notice != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KioskColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KioskColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: const Color(0xFF11161C),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (ready)
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  alignment: Alignment.center,
                  // Fixed logical size with the real frame ratio, so the child
                  // is never stretched; `BoxFit.cover` crops the overflow.
                  child: SizedBox(
                    width: 1000,
                    height: 1000 / ratio,
                    child: preview,
                  ),
                ),
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
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'La cámara no está disponible.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
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
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
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
                                      fontSize: 13,
                                      height: 1.25,
                                      color: Colors.white70,
                                    ),
                                  ),
                                if (statusText != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    statusText!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                                if (notice != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    notice!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.25,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFFFD166),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (hasText) const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: loading ? null : onCancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.35,
                            ),
                            disabledForegroundColor: Colors.white38,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: loading || !ready ? null : onCapture,
                          style: FilledButton.styleFrom(
                            backgroundColor: KioskColors.brand,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white.withValues(
                              alpha: 0.24,
                            ),
                            disabledForegroundColor: Colors.white54,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          icon: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.camera_alt_rounded, size: 18),
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
      ),
    );
  }
}
