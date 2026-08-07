import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/subscription.dart';
import '../domain/subscription_plan.dart';
import 'plan_checkout_page.dart';
import 'settings_providers.dart';

/// A — Choix du plan : trois formules, bascule mensuel / annuel.
class PlanSelectionPage extends ConsumerWidget {
  const PlanSelectionPage({super.key});

  static const routeName = '/settings/subscription/plans';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(subscriptionPlansProvider);
    final cycle = ref.watch(billingCycleProvider);
    final current = ref.watch(subscriptionProvider).valueOrNull;

    return AppScreen(
      title: 'Abonnement',
      header: AppSegmented(
        boxed: true,
        items: [
          BillingCycle.monthly.label,
          '${BillingCycle.annual.label} '
              '−${BillingCycle.annual.discountPercent} %',
        ],
        selectedIndex: cycle == BillingCycle.annual ? 1 : 0,
        onChanged: (index) => ref.read(billingCycleProvider.notifier).state =
            index == 1 ? BillingCycle.annual : BillingCycle.monthly,
      ),
      child: plans.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(subscriptionPlansProvider),
        ),
        data: (items) => items.isEmpty
            ? const AppEmptyState(
                title: 'Aucune formule',
                message: 'Le catalogue des abonnements est vide. '
                    'Contactez le support.',
                icon: Icons.workspace_premium_outlined,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final plan in items) ...[
                    _PlanCard(
                      plan: plan,
                      cycle: cycle,
                      current: current,
                      onTap: () => Navigator.of(context).pushNamed(
                        PlanCheckoutPage.routeName,
                        arguments: plan,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Facturation en FCFA via Wave, Orange Money ou carte. '
                    'Résiliable à tout moment.',
                    textAlign: TextAlign.center,
                    style: AppTypography.manrope(
                      12,
                      FontWeight.w500,
                      color: AppColors.textFaint,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Carte d'une formule — sombre et surmontée d'un badge si elle est mise
/// en avant, blanche sinon.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.cycle,
    required this.current,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final BillingCycle cycle;
  final Subscription? current;
  final VoidCallback onTap;

  bool get _isCurrent =>
      current != null &&
      (current!.planCode == plan.code || current!.planName == plan.name);

  IconData get _icon => switch (plan.code) {
        'solo' => Icons.person_outline_rounded,
        'multi' => Icons.apartment_rounded,
        _ => Icons.star_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final price = cycle.monthlyPrice(plan.pricePerMonthFcfa);
    final onDark = plan.isPopular;

    final head = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onDark
                ? AppColors.accent
                : (plan.code == 'multi'
                    ? AppColors.tintViolet
                    : AppColors.surfaceMuted),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _icon,
            size: 20,
            color: onDark
                ? Colors.white
                : (plan.code == 'multi'
                    ? AppColors.violet
                    : AppColors.textBody),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.name,
                style: AppTypography.sora(
                  16,
                  FontWeight.w700,
                  color: onDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              if (plan.tagline != null)
                Text(
                  plan.tagline!,
                  style: AppTypography.manrope(
                    11.5,
                    FontWeight.w500,
                    color: onDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        if (plan.isPopular)
          AppBadge(
            label: 'Populaire',
            color: AppColors.textPrimary,
            background: AppColors.mint,
          ),
      ],
    );

    final priceRow = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          Formatters.fcfa(price),
          style: AppTypography.sora(
            onDark ? 26 : 24,
            FontWeight.w800,
            color: onDark ? Colors.white : AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '/ mois',
          style: AppTypography.manrope(
            12.5,
            FontWeight.w600,
            color: onDark
                ? Colors.white.withValues(alpha: 0.65)
                : AppColors.textSecondary,
          ),
        ),
      ],
    );

    final summary = Text(
      cycle == BillingCycle.annual
          ? '${plan.summary ?? ''}\nFacturé '
              '${Formatters.fcfa(cycle.chargeAmount(plan.pricePerMonthFcfa))} '
              'par an'
          : (plan.summary ?? ''),
      style: AppTypography.manrope(
        12,
        FontWeight.w500,
        color: onDark
            ? Colors.white.withValues(alpha: 0.7)
            : AppColors.textSecondary,
      ),
    );

    if (!onDark) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        radius: AppSizes.radiusXl,
        onTap: _isCurrent ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            head,
            const SizedBox(height: 12),
            priceRow,
            const SizedBox(height: 6),
            summary,
            if (_isCurrent) ...[
              const SizedBox(height: 12),
              _CurrentPlanTag(onDark: false),
            ],
          ],
        ),
      );
    }

    return AppGradientCard(
      gradient: AppColors.darkGradient,
      bubbleColor: AppColors.accent.withValues(alpha: 0.28),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head,
          const SizedBox(height: 12),
          priceRow,
          const SizedBox(height: 6),
          summary,
          const SizedBox(height: 14),
          if (_isCurrent)
            _CurrentPlanTag(onDark: true)
          else
            AppButton(
              label: 'Choisir ${plan.name}',
              height: 46,
              onPressed: onTap,
            ),
        ],
      ),
    );
  }
}

/// Bandeau « Plan actuel » — la formule en cours n'est pas re-souscriptible.
class _CurrentPlanTag extends StatelessWidget {
  const _CurrentPlanTag({required this.onDark});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onDark ? AppColors.accent : AppColors.tintGreen,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        'Plan actuel',
        style: AppTypography.sora(
          14,
          FontWeight.w700,
          color: onDark ? Colors.white : AppColors.primary,
        ),
      ),
    );
  }
}
