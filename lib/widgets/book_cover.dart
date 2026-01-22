import 'dart:io';
import 'package:flutter/material.dart';

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

  static const double maxCoverHeight = 256;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: maxCoverHeight),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(2, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _buildCover(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isCompleted ? Colors.green : Colors.grey[600],
                fontWeight: isCompleted ? FontWeight.bold : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    // If there's a custom image, use it
    if (imagePath != null && imagePath!.isNotEmpty) {
      final file = File(imagePath!);
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
    final hue = (hash % 360).abs().toDouble();
    final baseColor = HSLColor.fromAHSL(1.0, hue, 0.4, 0.35).toColor();
    final lightColor = HSLColor.fromAHSL(1.0, hue, 0.3, 0.45).toColor();

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
            width: 12,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Title on cover
          Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isFolder)
                    Icon(
                      Icons.folder,
                      size: 32,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  if (isFolder) const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
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
      top: 4,
      right: 4,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.check,
          size: 14,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFolderBadge() {
    return Positioned(
      bottom: 4,
      right: 4,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.folder,
          size: 14,
          color: Colors.white,
        ),
      ),
    );
  }
}
