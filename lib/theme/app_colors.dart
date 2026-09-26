import 'package:flutter/material.dart';

/// Curated modern dark color system for GoTune.
/// High contrast, vibrant neon accents, deep obsidian surfaces.
class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF090A0F);
  static const Color backgroundSecondary = Color(0xFF0F111A);
  static const Color surface = Color(0xFF151824);
  static const Color surfaceElevated = Color(0xFF1D2132);
  static const Color surfaceCard = Color(0xFF181B2B);
  static const Color border = Color(0xFF262A3E);

  // Vibrant Accents
  static const Color primary = Color(0xFF8B5CF6); // Electric Violet
  static const Color primaryLight = Color(0xFFA78BFA);
  static const Color primaryDark = Color(0xFF6D28D9);
  
  static const Color secondary = Color(0xFF06B6D4); // Neon Cyan
  static const Color secondaryLight = Color(0xFF22D3EE);

  static const Color accentPink = Color(0xFFEC4899); // Sonic Pink
  static const Color accentGreen = Color(0xFF10B981); // Emerald Mint
  static const Color accentAmber = Color(0xFFF59E0B); // Amber Glow

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF4B5563);

  // Status & Feedback
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1B1E30), Color(0xFF121422)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient miniPlayerGradient = LinearGradient(
    colors: [Color(0xFF1E2238), Color(0xFF131525)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient nowPlayingBackground = LinearGradient(
    colors: [Color(0xFF1A152E), Color(0xFF090A0F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
