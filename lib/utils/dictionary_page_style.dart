import 'dart:ui' show Color;

/// CSS that darkens a light dictionary page by inverting it.
///
/// The page background is set to the channel-wise inverse of [surface], so
/// after the `invert` filter it renders as the app's own surface colour.
/// Media is inverted a second time so it looks normal.
String buildDarkenCss(Color surface) {
  String hex(double channel) =>
      (255 - (channel * 255).round()).toRadixString(16).padLeft(2, '0');
  final background = '#${hex(surface.r)}${hex(surface.g)}${hex(surface.b)}';
  return 'html { filter: invert(1) hue-rotate(180deg); '
      'background: $background; }\n'
      'img, picture, video, canvas, iframe, svg image, '
      '[style*="background-image"] '
      '{ filter: invert(1) hue-rotate(180deg); }';
}
