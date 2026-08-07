import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/subscription.dart';
import '../domain/subscription_plan.dart';
import 'plan_selection_page.dart';
import 'settings_providers.dart';

/// 10.4 — Abonnement : formule en cours, contenu et facturation.
class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  static const routeName = '/settings/subscription';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);

    return AppScreen(
      title: 'Abonnement',
      child: subscription.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(subscriptionProvider),
        ),
        data: (data) => data == null
            ? AppEmptyState(
                title: 'Aucun abonnement',
                message: 'Ce salon n\'a pas encore de formule active. '
                    'Comparez les formules pour en activer une.',
                icon: Icons.workspace_premium_outlined,
                actionLabel: 'Choisir un abonnement',
                onAction: () => Navigator.of(context)
                    .pushNamed(PlanSelectionPage.routeName),
              )
            : _SubscriptionBody(subscription: data),
      ),
    );
  }
}

class _SubscriptionBody extends StatelessWidget {
  const _SubscriptionBody({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppGradientCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Formule actuelle',
                          style: AppTypography.manrope(
                            12,
                            FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subscription.planName,
                          style: AppTypography.sora(
                            24,
                            FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppBadge.onDark(label: subscription.statusLabel),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.fcfaShort(subscription.pricePerMonthFcfa),
                    style: AppTypography.sora(
                      28,
                      FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '/ mois',
                      style: AppTypography.manrope(
                        13,
                        FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              if (subscription.billingCycle == BillingCycle.annual) ...[
                const SizedBox(height: 4),
                Text(
                  'Facturé ${Formatters.fcfa(subscription.chargeAmountFcfa)} '
                  'par an',
                  style: AppTypography.manrope(
                    12,
                    FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppButton.outline(
          label: 'Changer de formule',
          icon: Icons.swap_horiz_rounded,
          onPressed: () =>
              Navigator.of(context).pushNamed(PlanSelectionPage.routeName),
        ),
        if (subscription.features.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inclus dans ${subscription.planName}',
                  style: AppTypography.sora(14, FontWeight.w700),
                ),
                const SizedBox(height: 12),
                for (final feature in subscription.features)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: AppColors.tintGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            feature,
                            style: AppTypography.manrope(
                              13,
                              FontWeight.w600,
                              color: AppColors.textBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const AppSectionTitle('Facturation'),
        AppListCard(
          children: [
            AppListRow(
              label: subscription.paymentLabel ?? 'Moyen de paiement',
              subtitle: subscription.nextChargeLabel,
              strong: true,
              padding: const EdgeInsets.symmetric(vertical: 12),
              leading: const AppIconTile(
                icon: Icons.credit_card_rounded,
                radius: 11,
                size: 36,
              ),
              trailing: AppPillButton(
                label: 'Modifier',
                background: Colors.transparent,
                onTap: () {
                  // TODO(settings): modifier le moyen de paiement.
                },
              ),
            ),
            AppListRow(
              label: 'Factures',
              subtitle: 'Historique de paiement',
              strong: true,
              padding: const EdgeInsets.symmetric(vertical: 12),
              leading: const AppIconTile.neutral(
                icon: Icons.description_outlined,
                radius: 11,
                size: 36,
              ),
              trailing: const AppChevron(),
              onTap: () {
                // TODO(settings): écran d'historique des factures.
              },
            ),
          ],
        ),
      ],
    );
  }
}
