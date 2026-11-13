import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'photo_encoder.dart';

/// Front camera used by the "Con mi rostro" method.
///
/// The preview is a widget so the camera card stays dumb; the capture returns
/// the `data:image/jpeg;base64,...` string the backend expects.
abstract class FaceCamera {
  Future<void> initialize();

  bool get isReady;

  /// Live frame that fills its whole box (`BoxFit.cover`): it keeps the real
  /// sensor ratio in any orientation and only crops the overflow, so the image
  /// is never stretched.
  Widget buildPreview();

  /// `null` when no frame could be captured.
  Future<String?> capture();

  Future<void> dispose();
}

abstract class FaceCameraFactory {
  FaceCamera create();
}

class DeviceFaceCameraFactory implements FaceCameraFactory {
  const DeviceFaceCameraFactory({this.encoder = const PhotoEncoder()});

  final PhotoEncoder encoder;

  @override
  FaceCamera create() => DeviceFaceCamera(encoder: encoder);
}

class DeviceFaceCamera implements FaceCamera {
  DeviceFaceCamera({required this.encoder});

  final PhotoEncoder encoder;

  CameraController? _controller;
  bool _ready = false;

  @override
  bool get isReady => _ready;

  @override
  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      _controller = controller;
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return _CoverCameraPreview(controller: controller);
  }

  @override
  Future<String?> capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return null;
    if (controller.value.isTakingPicture) return null;

    try {
      final file = await controller.takePicture();
      final bytes = await File(file.path).readAsBytes();
      return encoder.encode(bytes);
    } on PhotoEncodingException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    _ready = false;
    final controller = _controller;
    _controller = null;
    try {
      await controller?.dispose();
    } catch (_) {
      // The controller may already be gone.
    }
  }
}

/// Live preview that fills its box the way `BoxFit.cover` does.
///
/// `CameraPreview` rotates the texture and sizes itself with an `AspectRatio`
/// whose ratio depends on the device orientation, so the box handed to it must
/// have that same ratio: a tight box with a different ratio (as the card used
/// to build) makes `AspectRatio` ignore its ratio and stretch the image, which
/// is what happened when the tablet was held in landscape.
///
/// The widget listens to the controller, so rotating the tablet recomputes the
/// box instead of keeping the previous orientation's ratio. The overflow is
/// cropped, never squeezed.
class _CoverCameraPreview extends StatelessWidget {
  const _CoverCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CameraValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (!value.isInitialized) return const SizedBox.shrink();
        final ratio = _displayAspectRatio(value);
        return ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final box = constraints.biggest;
              if (!box.width.isFinite || !box.height.isFinite || box.isEmpty) {
                return CameraPreview(controller);
              }
              // Cover: the frame keeps its ratio and the overflow is cropped.
              final frame = coverFrameSize(box, ratio);
              return OverflowBox(
                minWidth: frame.width,
                maxWidth: frame.width,
                minHeight: frame.height,
                maxHeight: frame.height,
                child: CameraPreview(controller),
              );
            },
          ),
        );
      },
    );
  }

  /// Width / height ratio of the frame on screen. Mirrors the rule used by
  /// `CameraPreview`: the texture is already upright, so the sensor ratio is
  /// inverted while the device is held in portrait.
  static double _displayAspectRatio(CameraValue value) {
    final orientation = value.isRecordingVideo
        ? value.recordingOrientation ?? value.deviceOrientation
        : value.previewPauseOrientation ??
              value.lockedCaptureOrientation ??
              value.deviceOrientation;
    final isLandscape =
        orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
    return isLandscape ? value.aspectRatio : 1 / value.aspectRatio;
  }
}

/// Box that covers [available] while keeping [aspectRatio] (width / height).
///
/// The result always has the requested ratio, so a frame drawn into it is never
/// stretched, and it is never smaller than [available] on either axis, so the
/// leftover area can just be clipped. Degenerate constraints are returned as-is
/// because there is nothing sensible to compute from them.
Size coverFrameSize(Size available, double aspectRatio) {
  if (!available.width.isFinite ||
      !available.height.isFinite ||
      available.isEmpty ||
      aspectRatio <= 0) {
    return available;
  }
  final width = (available.width / available.height) > aspectRatio
      ? available.width
      : available.height * aspectRatio;
  return Size(width, width / aspectRatio);
}
