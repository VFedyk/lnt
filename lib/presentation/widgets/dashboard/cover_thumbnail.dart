import 'dart:io';

import 'package:flutter/material.dart';

import '../../../utils/cover_image_helper.dart';

abstract class CoverThumbnailConstants {
  static const double thumbnailWidth = 40.0;
  static const double thumbnailHeight = 56.0;
  static const double thumbnailBorderRadius = 4.0;
}

class CoverThumbnail extends StatelessWidget {
  final String? coverImage;
  final IconData fallbackIcon;

  const CoverThumbnail({super.key, this.coverImage, required this.fallbackIcon});

  @override
  Widget build(BuildContext context) {
    final resolvedCover = CoverImageHelper.resolve(coverImage);
    if (resolvedCover != null && File(resolvedCover).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(CoverThumbnailConstants.thumbnailBorderRadius),
        child: Image.file(
          File(resolvedCover),
          width: CoverThumbnailConstants.thumbnailWidth,
          height: CoverThumbnailConstants.thumbnailHeight,
          fit: BoxFit.cover,
        ),
      );
    }
    return SizedBox(
      width: CoverThumbnailConstants.thumbnailWidth,
      height: CoverThumbnailConstants.thumbnailHeight,
      child: Icon(fallbackIcon, size: CoverThumbnailConstants.thumbnailWidth),
    );
  }
}
