import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import 'login_page.dart';
import 'register_page.dart';

/// 1.1 — Bienvenue : héros de marque avec fond clair lumineux et typographie émeraude.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  static const routeName = '/welcome';

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 34),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppLogo(size: 104, radius: 28),
                      const SizedBox(height: 28),
                      Text(
                        'L\'Atelier',
                        textAlign: TextAlign.center,
                        style: AppTypography.sora(
                          40,
                          FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          'La gestion complète de votre salon, dans une seule app.',
                          textAlign: TextAlign.center,
                          style: AppTypography.manrope(
                            15.5,
                            FontWeight.w500,
                            color: AppColors.textSecondary,
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
                      label: 'Créer mon salon',
                      onPressed: () => Navigator.of(context)
                          .pushNamed(RegisterPage.routeName),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'J\'ai déjà un compte',
                      variant: AppButtonVariant.outline,
                      onPressed: () =>
                          Navigator.of(context).pushNamed(LoginPage.routeName),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
