import 'package:flutter/foundation.dart';
import 'package:pasteboard/pasteboard.dart';

/// An image read from the system clipboard, with the file extension that
/// matches its encoded format.
typedef ClipboardImage = ({Uint8List bytes, String extension});

/// Reads an image from the system clipboard, or returns `null` when the
/// clipboard holds no image or cannot be read.
Future<ClipboardImage?> readClipboardImage() async {
  try {
    final bytes = await Pasteboard.image;
    if (bytes == null || bytes.isEmpty) return null;
    return (bytes: bytes, extension: imageExtensionFor(bytes));
  } catch (_) {
    return null;
  }
}

/// Picks a file extension from the image's magic bytes. `pasteboard` returns
/// raw bytes with no format information; anything that is not JPEG is saved
/// as `.png`, since image decoders sniff the content rather than trust it.
@visibleForTesting
String imageExtensionFor(Uint8List bytes) {
  final isJpeg =
      bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
  return isJpeg ? 'jpg' : 'png';
}
