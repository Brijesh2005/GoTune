import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Micro-animation visualizer bars that oscillate when playing.
class AnimatedEqualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double size;

  const AnimatedEqualizer({
    super.key,
    required this.isPlaying,
    this.color = AppColors.secondary,
    this.size = 18,
  });

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(0.4 + (0.6 * val)),
              _buildBar(0.9 - (0.5 * val)),
              _buildBar(0.3 + (0.7 * (1.0 - val))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double heightFraction) {
    final clamped = heightFraction.clamp(0.2, 1.0);
    return Container(
      width: widget.size / 4,
      height: widget.size * (widget.isPlaying ? clamped : 0.3),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
