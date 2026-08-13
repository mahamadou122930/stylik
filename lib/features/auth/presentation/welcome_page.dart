import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import 'login_page.dart';
import 'signup_choice_page.dart';

/// 1.1 — Bienvenue : héros de marque sur le dégradé vert de la maquette.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  static const routeName = '/welcome';

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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 34),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Pastille de verre : blanc voilé sur le dégradé, pas
                        // le logo plein des écrans clairs.
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Center(
                            child: AppGlyph(size: 46, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          'L\'Atelier',
                          textAlign: TextAlign.center,
                          style: AppTypography.sora(
                            38,
                            FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text(
                            'La gestion complète de votre salon, dans une seule app.',
                            textAlign: TextAlign.center,
                            style: AppTypography.manrope(
                              15.5,
                              FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.82),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.xl,
                    0,
                    AppSizes.xl,
                    30,
                  ),
                  child: Column(
                    children: [
                      AppButton(
                        label: 'Créer un compte',
                        variant: AppButtonVariant.light,
                        onPressed: () => Navigator.of(context)
                            .pushNamed(SignupChoicePage.routeName),
                      ),
                      const SizedBox(height: 11),
                      AppButton(
                        label: 'J\'ai déjà un compte',
                        variant: AppButtonVariant.outlineLight,
                        onPressed: () => Navigator.of(context)
                            .pushNamed(LoginPage.routeName),
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
