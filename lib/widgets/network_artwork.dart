import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable network image with memory-capped cached persistence (150-500px),
/// smooth dark placeholder, and fallback music icon.
class NetworkArtwork extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  const NetworkArtwork({
    super.key,
    required this.imageUrl,
    this.width = 56,
    this.height = 56,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final validUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;

    final targetMemWidth = (width * 2).clamp(100.0, 500.0).toInt();
    final targetMemHeight = (height * 2).clamp(100.0, 500.0).toInt();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        color: AppColors.surfaceElevated,
        child: validUrl
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                width: width,
                height: height,
                fit: fit,
                memCacheWidth: targetMemWidth,
                memCacheHeight: targetMemHeight,
                maxWidthDiskCache: 500,
                maxHeightDiskCache: 500,
                placeholder: (context, url) => Container(
                  color: AppColors.surfaceElevated,
                  child: Center(
                    child: Icon(
                      Icons.music_note_rounded,
                      color: const Color(0x33FFFFFF),
                      size: width * 0.35,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildFallback(),
              )
            : _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF23273D), Color(0xFF161827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppColors.primaryLight.withValues(alpha: 0.6),
          size: width * 0.45,
        ),
      ),
    );
  }
}
