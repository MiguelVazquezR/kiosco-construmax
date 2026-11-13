import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosco/services/camera_service.dart';

void main() {
  group('coverFrameSize', () {
    test('keeps the frame ratio instead of filling the box', () {
      const box = Size(1024, 600);

      final portrait = coverFrameSize(box, 3 / 4);
      final landscape = coverFrameSize(box, 4 / 3);

      expect(portrait.width / portrait.height, closeTo(3 / 4, 1e-9));
      expect(landscape.width / landscape.height, closeTo(4 / 3, 1e-9));
    });

    test('always covers the whole box', () {
      const boxes = [Size(1024, 600), Size(600, 900), Size(800, 1280)];
      for (final box in boxes) {
        for (final ratio in [3 / 4, 4 / 3, 9 / 16]) {
          final frame = coverFrameSize(box, ratio);
          expect(frame.width, greaterThanOrEqualTo(box.width));
          expect(frame.height, greaterThanOrEqualTo(box.height));
        }
      }
    });

    test('crops the overflow on the axis that does not fit', () {
      // Landscape frame inside a portrait card: wider than tall, so it fills
      // the height and overflows the sides.
      const portraitBox = Size(600, 900);
      final wide = coverFrameSize(portraitBox, 4 / 3);
      expect(wide.height, closeTo(portraitBox.height, 1e-9));
      expect(wide.width, greaterThan(portraitBox.width));

      // Portrait frame inside a landscape card: the opposite.
      const landscapeBox = Size(1024, 600);
      final tall = coverFrameSize(landscapeBox, 3 / 4);
      expect(tall.width, closeTo(landscapeBox.width, 1e-9));
      expect(tall.height, greaterThan(landscapeBox.height));
    });

    test('an exact match is left untouched', () {
      const box = Size(1200, 900);
      expect(coverFrameSize(box, 4 / 3), box);
    });

    test('degenerate constraints fall back to the box', () {
      expect(coverFrameSize(Size.zero, 4 / 3), Size.zero);
      expect(
        coverFrameSize(const Size(double.infinity, 100), 4 / 3),
        const Size(double.infinity, 100),
      );
      expect(coverFrameSize(const Size(100, 100), 0), const Size(100, 100));
    });
  });
}
