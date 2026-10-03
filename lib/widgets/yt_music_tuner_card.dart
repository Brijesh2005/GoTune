import 'package:flutter/material.dart';

import 'music_tuner_sheet.dart';

/// "Your music tuner" interactive card matching Screen 1 (Home Screen).
/// Tapping opens the [MusicTunerSheet] to customize variety, blend, and filters.
class YtMusicTunerCard extends StatelessWidget {
  final VoidCallback? onTunerOpened;

  const YtMusicTunerCard({
    super.key,
    this.onTunerOpened,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-header
        const Text(
          'CREATE A RADIO',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        // Section Title
        const Text(
          'Your music tuner',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 14),

        // Hero Card
        GestureDetector(
          onTap: () {
            onTunerOpened?.call();
            MusicTunerSheet.show(context);
          },
          child: Container(
            height: 148,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF1B1D28), Color(0xFF0F1017)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0x18FFFFFF), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Stylized audio soundwave lines in background
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SoundwavePainter(),
                    ),
                  ),

                  // Overlapping artist circles collage
                  Positioned(
                    left: 20,
                    top: 24,
                    bottom: 24,
                    child: Row(
                      children: [
                        _buildArtistCircle(
                          color: const Color(0xFFE91E63),
                          initials: 'LN',
                          size: 74,
                        ),
                        Transform.translate(
                          offset: const Offset(-20, 0),
                          child: _buildArtistCircle(
                            color: const Color(0xFF00BCD4),
                            initials: 'DC',
                            size: 82,
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(-40, 0),
                          child: _buildArtistCircle(
                            color: const Color(0xFF9C27B0),
                            initials: 'BE',
                            size: 70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right Centered Plus Button
                  Positioned(
                    right: 24,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.black,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArtistCircle({
    required Color color,
    required String initials,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.32,
          ),
        ),
      ),
    );
  }
}

class _SoundwavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x18FFFFFF)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const barWidth = 6.0;
    const spacing = 9.0;
    final count = (size.width / (barWidth + spacing)).toInt();

    final heights = [
      0.3, 0.5, 0.7, 0.4, 0.85, 0.6, 0.4, 0.9, 0.75, 0.45, 0.8, 0.65, 0.5,
      0.7, 0.85, 0.4, 0.6, 0.95, 0.5, 0.75, 0.6, 0.85, 0.4, 0.7, 0.5, 0.8,
    ];

    for (int i = 0; i < count; i++) {
      final x = i * (barWidth + spacing) + 8;
      final hFactor = heights[i % heights.length];
      final barHeight = size.height * hFactor * 0.7;
      final yStart = (size.height - barHeight) / 2;

      canvas.drawLine(
        Offset(x, yStart),
        Offset(x, yStart + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
