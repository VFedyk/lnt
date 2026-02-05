import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/cover_image_helper.dart';

abstract class _BookCoverConstants {
  // Layout
  static const double maxCoverHeight = 256.0;
  static const double aspectRatioWidth = 2.0;
  static const double aspectRatioHeight = 3.0;
  static const double spineWidth = 12.0;

  // Shadows
  static const double shadowBlurRadius = 8.0;
  static const double shadowOffsetX = 2.0;
  static const double shadowOffsetY = 4.0;
  static const double shadowOpacity = 0.3;
  static const double textShadowBlurRadius = 4.0;
  static const double textShadowOpacity = 0.5;

  // Generated cover colors
  static const double baseSaturation = 0.4;
  static const double baseLightness = 0.35;
  static const double lightSaturation = 0.3;
  static const double lightLightness = 0.45;
  static const int hueModulo = 360;

  // Icon sizes
  static const double folderIconSize = 32.0;
  static const double badgeIconSize = 14.0;

  // Opacity
  static const double folderIconOpacity = 0.9;
  static const double titleTextOpacity = 0.95;
  static const double folderBadgeBackgroundOpacity = 0.6;

  // Text
  static const int titleMaxLines = 2;
  static const int coverTitleMaxLines = 4;
  static const int subtitleMaxLines = 1;
  static const double coverTitleFontSize = 11.0;
}

class BookCover extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imagePath;
  final bool isFolder;
  final bool isCompleted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BookCover({
    super.key,
    required this.title,
    this.subtitle,
    this.imagePath,
    this.isFolder = false,
    this.isCompleted = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: _BookCoverConstants.maxCoverHeight,
            ),
            child: AspectRatio(
              aspectRatio: _BookCoverConstants.aspectRatioWidth /
                  _BookCoverConstants.aspectRatioHeight,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadiusS),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: _BookCoverConstants.shadowOpacity,
                      ),
                      blurRadius: _BookCoverConstants.shadowBlurRadius,
                      offset: const Offset(
                        _BookCoverConstants.shadowOffsetX,
                        _BookCoverConstants.shadowOffsetY,
                      ),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadiusS),
                  child: _buildCover(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Tooltip(
            message: title,
            child: Text(
              title,
              maxLines: _BookCoverConstants.titleMaxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppConstants.fontSizeCaption,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: _BookCoverConstants.subtitleMaxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppConstants.fontSizeXS,
                color: isCompleted
                    ? AppConstants.successColor
                    : AppConstants.subtitleColor,
                fontWeight: isCompleted ? FontWeight.bold : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    // If there's a custom image, use it
    final resolvedPath = CoverImageHelper.resolve(imagePath);
    if (resolvedPath != null && resolvedPath.isNotEmpty) {
      final file = File(resolvedPath);
      if (file.existsSync()) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              file,
              fit: BoxFit.cover,
            ),
            if (isCompleted) _buildCompletedBadge(),
            if (isFolder) _buildFolderBadge(),
          ],
        );
      }
    }

    // Generate a cover based on title
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildGeneratedCover(context),
        if (isCompleted) _buildCompletedBadge(),
        if (isFolder) _buildFolderBadge(),
      ],
    );
  }

  Widget _buildGeneratedCover(BuildContext context) {
    // Generate a color based on title hash
    final hash = title.hashCode;
    final hue =
        (hash % _BookCoverConstants.hueModulo).abs().toDouble();
    final baseColor = HSLColor.fromAHSL(
      1.0,
      hue,
      _BookCoverConstants.baseSaturation,
      _BookCoverConstants.baseLightness,
    ).toColor();
    final lightColor = HSLColor.fromAHSL(
      1.0,
      hue,
      _BookCoverConstants.lightSaturation,
      _BookCoverConstants.lightLightness,
    ).toColor();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lightColor, baseColor],
        ),
      ),
      child: Stack(
        children: [
          // Spine effect
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _BookCoverConstants.spineWidth,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(
                      alpha: _BookCoverConstants.shadowOpacity,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Title on cover
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isFolder)
                    Icon(
                      Icons.folder,
                      size: _BookCoverConstants.folderIconSize,
                      color: Colors.white.withValues(
                        alpha: _BookCoverConstants.folderIconOpacity,
                      ),
                    ),
                  if (isFolder)
                    const SizedBox(height: AppConstants.spacingS),
                  Text(
                    title,
                    maxLines: _BookCoverConstants.coverTitleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: _BookCoverConstants.titleTextOpacity,
                      ),
                      fontSize: _BookCoverConstants.coverTitleFontSize,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(
                            alpha: _BookCoverConstants.textShadowOpacity,
                          ),
                          blurRadius:
                              _BookCoverConstants.textShadowBlurRadius,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedBadge() {
    return Positioned(
      top: AppConstants.spacingXS,
      right: AppConstants.spacingXS,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingXS),
        decoration: BoxDecoration(
          color: AppConstants.successColor,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
        ),
        child: const Icon(
          Icons.check,
          size: _BookCoverConstants.badgeIconSize,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFolderBadge() {
    return Positioned(
      bottom: AppConstants.spacingXS,
      right: AppConstants.spacingXS,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingXS),
        decoration: BoxDecoration(
          color: Colors.black.withValues(
            alpha: _BookCoverConstants.folderBadgeBackgroundOpacity,
          ),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
        ),
        child: const Icon(
          Icons.folder,
          size: _BookCoverConstants.badgeIconSize,
          color: Colors.white,
        ),
      ),
    );
  }
}
