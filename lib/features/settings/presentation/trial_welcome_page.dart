import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import 'settings_providers.dart';

/// Écran T1 du prototype : « 15 jours pour essayer Stylik, gratuitement ».
class TrialWelcomePage extends ConsumerWidget {
  const TrialWelcomePage({super.key});

  static const routeName = '/trial/welcome';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider).valueOrNull;
    final endDate =
        subscription?.nextChargeAt ??
        DateTime.now().add(const Duration(days: 15));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Logo Stylik dans le badge vert dégradé
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1FB877), Color(0xFF0F9560)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0F9560,
                            ).withValues(alpha: 0.32),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.sparkles,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      '15 jours pour essayer Stylik, gratuitement',
                      style: AppTypography.sora(
                        28,
                        FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.8,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Toutes les fonctions Pro Salon, sans carte ni paiement. '
                      'Vous choisissez un plan à la fin de l\'essai.',
                      style: AppTypography.manrope(
                        14.5,
                        FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Timeline des 3 étapes
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      radius: 18,
                      child: Column(
                        children: [
                          _TimelineStep(
                            badge: 'J1',
                            badgeColor: Colors.white,
                            badgeBackground: AppColors.primary,
                            title: 'Aujourd\'hui',
                            subtitle: 'Accès complet débloqué',
                            showDivider: true,
                          ),
                          _TimelineStep(
                            badge: 'J12',
                            badgeColor: AppColors.primary,
                            badgeBackground: AppColors.tintGreen,
                            title: 'Rappel',
                            subtitle: 'Notification 3 jours avant la fin',
                            showDivider: true,
                          ),
                          _TimelineStep(
                            badge: 'J15',
                            badgeColor: AppColors.textSecondary,
                            badgeBackground: AppColors.surfaceMuted,
                            title:
                                'Fin de l\'essai · ${Formatters.dayMonth(endDate)}',
                            subtitle: 'Choix du plan et paiement',
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
              child: Column(
                children: [
                  AppButton(
                    label: 'Commencer l\'essai gratuit',
                    height: 56,
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      // `pop()` seul retombait sur l'écran d'inscription
                      // quand la pile en comptait plusieurs : on remonte
                      // jusqu'à l'accueil, quel que soit le chemin suivi.
                      if (navigator.canPop()) {
                        navigator.popUntil((route) => route.isFirst);
                      } else {
                        navigator.pushReplacementNamed('/');
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Aucun prélèvement automatique',
                    style: AppTypography.manrope(
                      12,
                      FontWeight.w500,
                      color: AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.badge,
    required this.badgeColor,
    required this.badgeBackground,
    required this.title,
    required this.subtitle,
    required this.showDivider,
  });

  final String badge;
  final Color badgeColor;
  final Color badgeBackground;
  final String title;
  final String subtitle;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: badgeBackground,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              badge,
              style: AppTypography.sora(
                12.5,
                FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.manrope(
                    14,
                    FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.manrope(
                    12,
                    FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
