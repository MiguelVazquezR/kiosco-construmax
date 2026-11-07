import 'package:flutter/material.dart';

import '../kiosk_theme.dart';

/// Live preview of the front camera plus the capture / cancel controls.
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
  });

  final Widget preview;
  final VoidCallback onCapture;
  final VoidCallback onCancel;
  final bool ready;
  final bool loading;
  final String? hint;
  final String? statusText;

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
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: const Color(0xFF11161C),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (ready)
                      FittedBox(
                        fit: BoxFit.cover,
                        // Fixed logical size so FittedBox has an intrinsic
                        // child; the real CameraPreview then lays out in a
                        // bounded box and is scaled to cover the card.
                        child: SizedBox(
                          width: 480,
                          height: 640,
                          child: preview,
                        ),
                      ),
                    // Oval guide so the collaborator centres the face.
                    IgnorePointer(
                      child: Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.62,
                          heightFactor: 0.78,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.circular(200),
                              border: Border.all(
                                color: Colors.white70,
                                width: 3,
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
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (hint != null)
            Text(
              hint!,
              style: const TextStyle(
                fontSize: 13,
                color: KioskColors.textMuted,
              ),
            ),
          if (statusText != null) ...[
            const SizedBox(height: 6),
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
          FilledButton(
            onPressed: loading || !ready ? null : onCapture,
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text('Capturar'),
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
