import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';

/// 1.0 — Splash : le temps que la session et le profil se chargent.
///
/// Le même dégradé que l'écran Bienvenue qui suit : l'enchaînement doit se
/// lire comme un seul écran qui se remplit, pas comme deux écrans successifs.
///
/// Il remplace le chargeur beige que montrait la porte d'authentification —
/// lequel n'affichait ni marque, ni raison d'attendre.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  static const routeName = '/splash';

  /// Durée minimale d'affichage.
  ///
  /// Sans elle, une session déjà en cache fait apparaître puis disparaître
  /// l'écran en deux images : on ne voit qu'un clignotement vert. Assez long
  /// pour être perçu comme voulu, assez court pour ne pas faire attendre.
  static const Duration minimumDuration = Duration(milliseconds: 800);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.welcomeGradient),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pastille blanche pleine, contrairement au verre
                        // dépoli de l'écran Bienvenue : au lancement, la
                        // marque s'affirme avant de s'effacer.
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 44,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: AppGlyph(size: 60, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Stylik',
                          style: AppTypography.sora(
                            32,
                            FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 44),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chargement…',
                        style: AppTypography.manrope(
                          12,
                          FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 0.96,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
