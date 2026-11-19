import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/utils/clipboard_image.dart';

void main() {
  group('imageExtensionFor', () {
    test('JPEG signature maps to jpg', () {
      expect(
        imageExtensionFor(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00])),
        'jpg',
      );
    });

    test('PNG signature maps to png', () {
      expect(
        imageExtensionFor(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ),
        'png',
      );
    });

    test('unknown or too-short data falls back to png', () {
      expect(imageExtensionFor(Uint8List.fromList([0x49, 0x49, 0x2A])), 'png');
      expect(imageExtensionFor(Uint8List.fromList([0xFF, 0xD8])), 'png');
    });
  });
}
