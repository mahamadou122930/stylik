import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/subscription.dart';
import '../domain/subscription_plan.dart';
import '../domain/subscription_request.dart';
import 'payment_instructions_page.dart';
import 'plan_selection_page.dart';
import 'settings_providers.dart';

/// 10.4 — Abonnement : formule en cours, contenu et facturation.
class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  static const routeName = '/settings/subscription';

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  @override
  void initState() {
    super.initState();
    // L'abonnement change hors de l'application : c'est l'opérateur qui
    // l'active, depuis la console. Sans relecture, un gérant qui vient de
    // payer verrait encore son essai expiré jusqu'au redémarrage. La valeur
    // en cache reste affichée pendant la relecture : pas de clignotement.
    Future.microtask(() {
      ref.invalidate(subscriptionProvider);
      ref.invalidate(pendingSubscriptionRequestProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                message:
                    'Ce salon n\'a pas encore de formule active. '
                    'Comparez les formules pour en activer une.',
                icon: LucideIcons.award,
                actionLabel: 'Choisir un abonnement',
                onAction: () => Navigator.of(
                  context,
                ).pushNamed(PlanSelectionPage.routeName),
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
        const _PendingRequestBanner(),
        if (subscription.isTrial && !subscription.isExpired)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.tintGreen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppIconTile(
                      icon: LucideIcons.sparkles,
                      size: 34,
                      radius: 10,
                      color: AppColors.primary,
                      background: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Période d\'essai Pro (15 jours)',
                            style: AppTypography.sora(
                              14,
                              FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subscription.trialDaysRemaining <= 1
                                ? 'Dernier jour pour tester toutes les fonctionnalités'
                                : '${subscription.trialDaysRemaining} jours restants sans aucun engagement',
                            style: AppTypography.manrope(
                              12,
                              FontWeight.w500,
                              color: AppColors.textBody,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: subscription.trialProgress,
                    backgroundColor: Colors.white,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          )
        else if (subscription.isTrial && subscription.isExpired)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.tintDanger,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.dangerBorder),
            ),
            child: Row(
              children: [
                const AppIconTile(
                  icon: LucideIcons.triangleAlert,
                  size: 34,
                  radius: 10,
                  color: AppColors.danger,
                  background: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Période d\'essai terminée',
                        style: AppTypography.sora(
                          14,
                          FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Votre essai de 15 jours est arrivé à échéance. Activez votre formule pour continuer.',
                        style: AppTypography.manrope(
                          12,
                          FontWeight.w500,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                    subscription.isTrial && !subscription.isExpired
                        ? 'Offert'
                        : Formatters.fcfaShort(subscription.pricePerMonthFcfa),
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
                      subscription.isTrial && !subscription.isExpired
                          ? '(puis ${Formatters.fcfaShort(subscription.pricePerMonthFcfa)} / mois)'
                          : '/ mois',
                      style: AppTypography.manrope(
                        13,
                        FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              if (subscription.billingCycle == BillingCycle.annual &&
                  !subscription.isTrial) ...[
                const SizedBox(height: 4),
                _AnnualRate(planCode: subscription.planCode),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (subscription.isTrial) ...[
          AppButton(
            label: subscription.isExpired
                ? 'Activer mon abonnement'
                : 'Choisir une formule définitive',
            icon: LucideIcons.award,
            onPressed: () =>
                Navigator.of(context).pushNamed(PlanSelectionPage.routeName),
          ),
          if (!subscription.isExpired) ...[
            const SizedBox(height: 8),
            AppButton.outline(
              label: 'Comparer les formules',
              icon: LucideIcons.arrowLeftRight,
              onPressed: () =>
                  Navigator.of(context).pushNamed(PlanSelectionPage.routeName),
            ),
          ],
        ] else ...[
          AppButton.outline(
            label: 'Changer de formule',
            icon: LucideIcons.arrowLeftRight,
            onPressed: () =>
                Navigator.of(context).pushNamed(PlanSelectionPage.routeName),
          ),
        ],
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
                            LucideIcons.check,
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
                icon: LucideIcons.creditCard,
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
                icon: LucideIcons.fileText,
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

/// Demande d'activation déposée et pas encore payée.
///
/// Sans elle, un gérant qui revient sur cet écran ne retrouve ni sa
/// référence ni le numéro où payer, et redépose une demande — qui remplace la
/// première, référence comprise.
class _PendingRequestBanner extends ConsumerWidget {
  const _PendingRequestBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SubscriptionRequest? request = ref
        .watch(pendingSubscriptionRequestProvider)
        .valueOrNull;
    if (request == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () =>
            Navigator.of(context).pushNamed(PaymentInstructionsPage.routeName),
        radius: 16,
        shadow: false,
        color: AppColors.tintAmber,
        borderColor: AppColors.amberBorder,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(LucideIcons.hourglass, size: 22, color: AppColors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demande en attente de paiement',
                    style: AppTypography.sora(
                      14,
                      FontWeight.w700,
                      color: AppColors.amberDeep,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${request.planName} · '
                    '${Formatters.fcfa(request.amountFcfa)} · '
                    'réf. ${request.reference}',
                    style: AppTypography.manrope(
                      12,
                      FontWeight.w600,
                      color: AppColors.textBody,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: AppColors.amberDeep,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarif annuel en vigueur de la formule du salon.
///
/// L'abonnement ne garde pas la remise qu'il a obtenue — le montant réglé est
/// au registre de la console, pas ici. Le montant affiché est donc celui du
/// catalogue aujourd'hui, et il est présenté comme tel plutôt que comme
/// « facturé » : une remise changée depuis ferait mentir ce mot.
class _AnnualRate extends ConsumerWidget {
  const _AnnualRate({required this.planCode});

  final String? planCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(subscriptionPlansProvider).valueOrNull ?? const [];
    final plan = plans.where((p) => p.code == planCode).firstOrNull;
    if (plan == null) return const SizedBox.shrink();

    return Text(
      'Tarif annuel en vigueur : '
      '${Formatters.fcfa(plan.chargeFor(BillingCycle.annual))}',
      style: AppTypography.manrope(12, FontWeight.w600, color: Colors.white70),
    );
  }
}
