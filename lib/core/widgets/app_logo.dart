import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_colors.dart';

/// Chemins des icônes de marque exportées (`doc/App gestion coiffeur/export-icones`).
abstract final class AppLogoAssets {
  /// Marque complète : glyphe blanc sur carré dégradé émeraude.
  static const String square = 'assets/icons/icon-square.svg';

  /// Même marque, coins déjà arrondis (à utiliser sans ClipRRect).
  static const String rounded = 'assets/icons/icon-rounded.svg';

  /// Glyphe seul, monochrome — pour filigranes, états vides, en-têtes.
  static const String glyph = 'assets/icons/glyph.svg';
}

/// Logo de l'application, en vectoriel : net à toutes les densités d'écran.
///
/// Le halo émeraude reprend celui des écrans d'accueil et de connexion.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 104,
    this.radius = 28,
    this.shadow = true,
  });

  final double size;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: size * 0.27,
                  offset: Offset(0, size * 0.1),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SvgPicture.asset(
          AppLogoAssets.square,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Glyphe seul, teinté. Sert d'accent discret là où le carré serait trop lourd.
class AppGlyph extends StatelessWidget {
  const AppGlyph({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      AppLogoAssets.glyph,
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}
