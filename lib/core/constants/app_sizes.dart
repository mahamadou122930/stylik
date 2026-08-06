import 'package:flutter/widgets.dart';

/// Espacements, rayons et points de rupture, calés sur la maquette (390 px).
abstract final class AppSizes {
  // Espacements
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Marge horizontale du corps des écrans (`padding:0 18px`).
  static const double screenPadding = 18;

  /// Marge horizontale de l'en-tête (`padding:6px 16px 12px`).
  static const double headerPadding = 16;

  // Rayons
  static const double radiusSm = 7;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusPill = 999;

  // Composants
  static const double ctaHeight = 54;
  static const double iconButtonSize = 40;
  static const double iconTileSize = 40;
  static const double avatarSize = 44;
  static const double inputHeight = 50;
  static const double toggleWidth = 44;
  static const double toggleHeight = 26;

  // Points de rupture
  static const double tabletBreakpoint = 720;
  static const double desktopBreakpoint = 1100;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;
}
