import 'package:flutter/widgets.dart';
import 'package:kiosco/services/camera_service.dart';

/// Camera double: renders a tiny placeholder and returns a canned data URL.
class FakeFaceCamera implements FaceCamera {
  FakeFaceCamera({
    this.ready = true,
    this.capturedDataUrl = 'data:image/jpeg;base64,ZmFrZQ==',
  });

  bool ready;
  String? capturedDataUrl;
  int initializeCalls = 0;
  int captureCalls = 0;
  bool disposed = false;

  @override
  bool get isReady => ready;

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Widget buildPreview() =>
      const SizedBox.expand(key: ValueKey('fake-camera-preview'));

  @override
  double? get previewAspectRatio => 3 / 4;

  @override
  Future<String?> capture() async {
    captureCalls++;
    return capturedDataUrl;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class FakeCameraFactory implements FaceCameraFactory {
  FakeCameraFactory({this.camera});

  FakeFaceCamera? camera;
  final List<FakeFaceCamera> created = [];

  @override
  FaceCamera create() {
    final instance = camera ?? FakeFaceCamera();
    created.add(instance);
    return instance;
  }
}
