import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable network image with cached persistence, smooth dark placeholder,
/// and fallback music icon.
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
                placeholder: (context, url) => Container(
                  color: AppColors.surfaceElevated,
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryLight,
                      ),
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
          color: AppColors.primaryLight.withOpacity(0.6),
          size: width * 0.45,
        ),
      ),
    );
  }
}
