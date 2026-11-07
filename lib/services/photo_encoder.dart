import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../config/kiosk_config.dart';

/// Turns a captured frame into the base64 data URL the backend expects:
/// `data:image/jpeg;base64,<payload>`, JPEG quality 75, longest side 1024 px
/// and at most [KioskConfig.maxPhotoCharacters] characters.
///
/// Throws [PhotoEncodingException] when the frame cannot be decoded or stays
/// too heavy after re-compression.
class PhotoEncoder {
  const PhotoEncoder({
    this.maxSide = KioskConfig.photoMaxSide,
    this.quality = KioskConfig.photoQuality,
    this.maxCharacters = KioskConfig.maxPhotoCharacters,
  });

  final int maxSide;
  final int quality;
  final int maxCharacters;

  String encode(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const PhotoEncodingException('No se pudo procesar la fotografía.');
    }

    var image = decoded;
    final longestSide = image.width > image.height ? image.width : image.height;
    if (longestSide > maxSide) {
      final ratio = maxSide / longestSide;
      image = img.copyResize(
        image,
        width: (image.width * ratio).round(),
        height: (image.height * ratio).round(),
        interpolation: img.Interpolation.average,
      );
    }

    var effectiveQuality = quality;
    var dataUrl = _toDataUrl(image, effectiveQuality);

    while (dataUrl.length > maxCharacters && effectiveQuality > 30) {
      effectiveQuality -= 15;
      dataUrl = _toDataUrl(image, effectiveQuality);
    }

    if (dataUrl.length > maxCharacters) {
      throw const PhotoEncodingException(
        'La fotografía es demasiado grande. Acércate un poco e intenta de nuevo.',
      );
    }

    return dataUrl;
  }

  String _toDataUrl(img.Image image, int effectiveQuality) {
    final jpeg = img.encodeJpg(image, quality: effectiveQuality);
    return 'data:image/jpeg;base64,${base64Encode(jpeg)}';
  }
}

class PhotoEncodingException implements Exception {
  const PhotoEncodingException(this.message);

  final String message;

  @override
  String toString() => message;
}
