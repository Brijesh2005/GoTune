import 'package:flutter/material.dart';

/// Modern dark blue & slate color system for GoTune, matching the Pulse dynamic aesthetic.
class AppColors {
  // Backgrounds & Panels (YouTube Music deep black & dark grey)
  static const Color background = Color(0xFF030303);
  static const Color backgroundSecondary = Color(0xFF0F0F0F);
  static const Color surface = Color(0xFF121212);
  static const Color surfaceElevated = Color(0xFF212121);
  static const Color surfaceCard = Color(0xFF1E1E1E);
  static const Color surfacePill = Color(0xFF272727);
  static const Color border = Color(0xFF2E2E2E);
  static const Color chipBorder = Color(0x33FFFFFF);

  // YouTube Music Red & Vibrant Accents
  static const Color youtubeRed = Color(0xFFFF0000);
  static const Color primary = Color(0xFFFF0000); // YouTube Red
  static const Color primaryLight = Color(0xFFFF4E4E);
  static const Color primaryDark = Color(0xFFCC0000);
  static const Color primarySoft = Color(0x29FF0000); // rgba(255, 0, 0, .16)
  
  static const Color secondary = Color(0xFF2E8CFF);
  static const Color secondaryLight = Color(0xFF72B5FF);

  static const Color accentBlue = Color(0xFF2E8CFF);
  static const Color accentBlueLight = Color(0xFF72B5FF);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textMuted = Color(0xFF717171);
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
