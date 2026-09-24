import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../finance/presentation/export_page.dart';
import 'plan_selection_page.dart';
import 'settings_providers.dart';

/// Écran T3 du prototype : « Votre essai est terminé ».
class TrialExpiredPage extends ConsumerWidget {
  const TrialExpiredPage({super.key});

  static const routeName = '/trial/expired';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ce que le salon a fait pendant l'essai, sur la fenêtre de l'essai : les
    // trois chiffres couvrent la même période que le titre qui les surmonte.
    // Tant qu'ils ne sont pas lus, on n'affiche pas de zéros à leur place.
    final recap = ref.watch(trialRecapProvider).valueOrNull;

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
                    // Pastille ambre sablier
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.tintAmber,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.hourglass,
                          size: 30,
                          color: AppColors.amber,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Votre essai est terminé',
                      style: AppTypography.sora(
                        26,
                        FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.7,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Vos données sont conservées 30 jours. '
                      'Choisissez un plan pour retrouver l\'accès de toute l\'équipe.',
                      style: AppTypography.manrope(
                        14,
                        FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    if (recap != null) ...[
                      const SizedBox(height: 22),
                      const AppSectionLabel('Pendant l\'essai'),
                      Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              value: '${recap.ticketCount}',
                              label: 'Ventes',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatBox(
                              value: '${recap.clientCount}',
                              label: 'Clients',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatBox(
                              value: Formatters.fcfaShort(recap.revenueFcfa),
                              label: 'CA (F)',
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    // Recommandé · Pro Salon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recommandé · Pro Salon',
                                  style: AppTypography.manrope(
                                    12,
                                    FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Le prix et la pastille « −20 % annuel » se
                                // partagent une ligne sans contrainte : sur un
                                // écran étroit, le prix débordait de la carte.
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '18 000 F ',
                                        style: AppTypography.sora(
                                          22,
                                          FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        '/ mois',
                                        style: AppTypography.manrope(
                                          12,
                                          FontWeight.w600,
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.mint,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '−20 % annuel',
                              style: AppTypography.manrope(
                                10.5,
                                FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
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
                    label: 'Choisir un plan',
                    height: 56,
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed(PlanSelectionPage.routeName),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pushNamed(ExportPage.routeName),
                    child: Text(
                      'Exporter mes données',
                      style: AppTypography.manrope(
                        13,
                        FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
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

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.sora(
              18,
              FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.manrope(
              10.5,
              FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
