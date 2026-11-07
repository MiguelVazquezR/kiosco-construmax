import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kiosco/services/photo_encoder.dart';

Uint8List _jpegOf(int width, int height, {bool noisy = false}) {
  final image = img.Image(width: width, height: height);
  if (noisy) {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(x, y, (x * 37 + y * 11) % 256, (x * 17) % 256, (y * 29) % 256);
      }
    }
  } else {
    img.fill(image, color: img.ColorRgb8(120, 80, 40));
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

Uint8List _decodeDataUrl(String dataUrl) {
  const prefix = 'data:image/jpeg;base64,';
  expect(dataUrl.startsWith(prefix), isTrue);
  return base64Decode(dataUrl.substring(prefix.length));
}

void main() {
  group('PhotoEncoder', () {
    test('returns a JPEG data URL the backend accepts', () {
      const encoder = PhotoEncoder();
      final dataUrl = encoder.encode(_jpegOf(320, 240));

      expect(dataUrl, startsWith('data:image/jpeg;base64,'));
      expect(dataUrl.length, lessThan(2000000));

      final decoded = img.decodeImage(_decodeDataUrl(dataUrl));
      expect(decoded, isNotNull);
      expect(decoded!.width, 320);
      expect(decoded.height, 240);
    });

    test('downscales the longest side to 1024 px', () {
      const encoder = PhotoEncoder();
      final dataUrl = encoder.encode(_jpegOf(3000, 2000, noisy: true));

      final decoded = img.decodeImage(_decodeDataUrl(dataUrl))!;
      expect(decoded.width, 1024);
      expect((decoded.height - 683).abs(), lessThanOrEqualTo(1));
    });

    test('throws when the photo cannot be compressed under the limit', () {
      const encoder = PhotoEncoder(maxCharacters: 200);

      expect(
        () => encoder.encode(_jpegOf(256, 256, noisy: true)),
        throwsA(isA<PhotoEncodingException>()),
      );
    });

    test('throws on bytes that are not an image', () {
      const encoder = PhotoEncoder();

      expect(
        () => encoder.encode(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<PhotoEncodingException>()),
      );
    });
  });
}
