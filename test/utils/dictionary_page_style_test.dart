import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/utils/dictionary_page_style.dart';

void main() {
  group('buildDarkenCss', () {
    test('sets the background to the inverse of the surface colour', () {
      final css = buildDarkenCss(const Color(0xFF121212));
      expect(css, contains('background: #ededed;'));
      expect(css, contains('html { filter: invert(1) hue-rotate(180deg);'));
    });

    test('pads single-digit channels', () {
      final css = buildDarkenCss(const Color(0xFFFFFFFF));
      expect(css, contains('background: #000000;'));
    });

    test('re-inverts media', () {
      final css = buildDarkenCss(const Color(0xFF121212));
      expect(css, contains('img, picture, video, canvas, iframe'));
      expect(css, contains('[style*="background-image"]'));
    });
  });
}
