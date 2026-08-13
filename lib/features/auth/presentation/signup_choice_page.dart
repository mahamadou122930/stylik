import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import 'join_salon_page.dart';
import 'register_page.dart';

/// 1.2 — Créer un compte : ouvrir son salon, ou rejoindre celui d'un gérant.
///
/// Les deux parcours divergent complètement — l'un crée le salon et le compte
/// du gérant, l'autre réclame une fiche employé déjà créée — d'où cet
/// aiguillage avant toute saisie.
class SignupChoicePage extends StatelessWidget {
  const SignupChoicePage({super.key});

  static const routeName = '/signup';

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Créer un compte',
      bodyPadding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Vous ouvrez un salon, ou vous rejoignez l\'équipe d\'un salon '
            'déjà inscrit ?',
            style: AppTypography.manrope(
              14,
              FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          _ChoiceCard(
            icon: Icons.storefront_outlined,
            iconColor: AppColors.primary,
            iconBackground: AppColors.tintGreen,
            title: 'Je crée mon salon',
            subtitle: 'Vous êtes le gérant',
            onTap: () =>
                Navigator.of(context).pushNamed(RegisterPage.routeName),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            icon: Icons.person_outline_rounded,
            iconColor: AppColors.blue,
            iconBackground: AppColors.tintBlue,
            title: 'Je rejoins un salon',
            subtitle: 'Coiffeur ou réceptionniste · avec code',
            highlighted: true,
            onTap: () =>
                Navigator.of(context).pushNamed(JoinSalonPage.routeName),
          ),
          const SizedBox(height: 22),
          const AppCallout(
            message: 'Le code d\'invitation est fourni par votre gérant quand '
                'il ajoute votre fiche employé.',
          ),
        ],
      ),
    );
  }
}

/// Carte d'aiguillage : pastille d'icône, titre, sous-titre, chevron.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Choix mis en avant (bordure verte) — celui que la maquette suggère.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      radius: 18,
      shadow: highlighted,
      borderColor: highlighted ? AppColors.accent : AppColors.border,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      child: Row(
        children: [
          AppIconTile(
            icon: icon,
            color: iconColor,
            background: iconBackground,
            size: 48,
            radius: 14,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.sora(16, FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.manrope(
                    12.5,
                    FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppChevron(color: highlighted ? AppColors.primary : null),
        ],
      ),
    );
  }
}
