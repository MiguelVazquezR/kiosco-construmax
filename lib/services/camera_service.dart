import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'photo_encoder.dart';

/// Front camera used by the "Con mi rostro" method.
///
/// The preview is a widget so the camera card stays dumb; the capture returns
/// the `data:image/jpeg;base64,...` string the backend expects.
abstract class FaceCamera {
  Future<void> initialize();

  bool get isReady;

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
    return CameraPreview(controller);
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
