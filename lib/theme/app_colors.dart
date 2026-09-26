import 'package:flutter/material.dart';

/// Modern dark blue & slate color system for GoTune, matching the Pulse dynamic aesthetic.
class AppColors {
  // Backgrounds & Panels
  static const Color background = Color(0xFF101215);
  static const Color backgroundSecondary = Color(0xFF14171B);
  static const Color surface = Color(0xFF191D22);
  static const Color surfaceElevated = Color(0xFF23282F);
  static const Color surfaceCard = Color(0xFF1B2026);
  static const Color border = Color(0xFF303740);

  // Vibrant Accents
  static const Color primary = Color(0xFF2E8CFF); // Pulse Electric Blue
  static const Color primaryLight = Color(0xFF72B5FF);
  static const Color primaryDark = Color(0xFF1A6FD9);
  static const Color primarySoft = Color(0x292E8CFF); // rgba(46, 140, 255, .16)
  
  static const Color secondary = Color(0xFF00D2C4); // Neon Teal
  static const Color secondaryLight = Color(0xFF22D3EE);

  static const Color accentPink = Color(0xFFEC4899);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);

  // Text Colors
  static const Color textPrimary = Color(0xFFF7F8FA);
  static const Color textSecondary = Color(0xFFA8B0BB);
  static const Color textMuted = Color(0xFF77818D);
  static const Color textDisabled = Color(0xFF4B5563);

  // Status & Feedback
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2E8CFF), Color(0xFF00D2C4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient artTileGradient = LinearGradient(
    colors: [Color(0xFF254E78), Color(0xFF17202A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF191D22), Color(0xFF101215)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient miniPlayerGradient = LinearGradient(
    colors: [Color(0xFF191D22), Color(0xFF14171B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient nowPlayingBackground = LinearGradient(
    colors: [Color(0xFF191D22), Color(0xFF101215)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
