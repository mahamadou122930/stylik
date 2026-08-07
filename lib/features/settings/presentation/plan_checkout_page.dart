import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../pos/domain/payment_method.dart';
import '../domain/subscription_plan.dart';
import 'settings_providers.dart';

/// Moyens de paiement acceptés pour l'abonnement (pas d'espèces en SaaS).
const List<PaymentMethod> _billingMethods = [
  PaymentMethod.wave,
  PaymentMethod.orangeMoney,
  PaymentMethod.card,
];

/// B — Comparatif & paiement : détail des fonctions, récap et souscription.
class PlanCheckoutPage extends ConsumerStatefulWidget {
  const PlanCheckoutPage({super.key, required this.plan});

  static const routeName = '/settings/subscription/checkout';

  final SubscriptionPlan plan;

  @override
  ConsumerState<PlanCheckoutPage> createState() => _PlanCheckoutPageState();
}

class _PlanCheckoutPageState extends ConsumerState<PlanCheckoutPage> {
  PaymentMethod _method = _billingMethods.first;
  bool _isSubmitting = false;

  Future<void> _subscribe(BillingCycle cycle) async {
    final salonId = ref.read(currentSalonIdProvider);
    if (salonId == null) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(settingsRepositoryProvider).changePlan(
            salonId: salonId,
            plan: widget.plan,
            cycle: cycle,
            paymentLabel: _method.label,
          );
      ref.invalidate(subscriptionProvider);
      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Abonnement ${widget.plan.name} activé.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Souscription impossible : $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final cycle = ref.watch(billingCycleProvider);
    final plans = ref.watch(subscriptionPlansProvider).valueOrNull ?? const [];

    // Colonne de gauche du comparatif : la formule juste en dessous, celle
    // que le gérant quitte en montant en gamme.
    final lower = plans
        .where((other) => other.sortOrder < plan.sortOrder)
        .fold<SubscriptionPlan?>(
          null,
          (best, other) =>
              best == null || other.sortOrder > best.sortOrder ? other : best,
        );

    final charge = cycle.chargeAmount(plan.pricePerMonthFcfa);

    return AppScreen(
      title: '${plan.name} · détail',
      footer: AppButton(
        label: cycle == BillingCycle.annual
            ? 'Passer à l\'annuel'
            : 'Souscrire ${plan.name}',
        trailingLabel: Formatters.fcfa(charge),
        height: 56,
        isLoading: _isSubmitting,
        onPressed: () => _subscribe(cycle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ComparisonTable(plan: plan, reference: lower),
          const SizedBox(height: 14),
          _PriceRecap(plan: plan, cycle: cycle),
          const AppSectionLabel(
            'Moyen de paiement',
            padding: EdgeInsets.fromLTRB(2, 18, 2, 10),
          ),
          Row(
            children: [
              for (final method in _billingMethods) ...[
                if (method != _billingMethods.first) const SizedBox(width: 8),
                Expanded(
                  child: _MethodTile(
                    method: method,
                    selected: _method == method,
                    onTap: () => setState(() => _method = method),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            // Pas de point après la date : `dayMonth` rend « 7 sept. ».
            'Prélèvement renouvelé automatiquement le '
            '${Formatters.dayMonth(cycle.nextChargeFrom(DateTime.now()))} — '
            'vous pouvez changer de formule à tout moment.',
            style: AppTypography.manrope(
              12,
              FontWeight.w500,
              color: AppColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tableau « Fonction · formule actuelle · formule visée ».
class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.plan, this.reference});

  final SubscriptionPlan plan;
  final SubscriptionPlan? reference;

  /// Assez large pour « Multi-salon » sans troncature à 10.5 px.
  static const double _columnWidth = 68;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              border: Border(bottom: BorderSide(color: AppColors.border)),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSizes.radiusLg),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Fonction',
                    style: AppTypography.sora(
                      11.5,
                      FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (reference != null)
                  SizedBox(
                    width: _columnWidth,
                    child: Text(
                      reference!.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sora(
                        10.5,
                        FontWeight.w700,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                SizedBox(
                  width: _columnWidth,
                  child: Text(
                    plan.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sora(
                      10.5,
                      FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final capability in PlanCapability.values)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: capability == PlanCapability.values.last
                    ? null
                    : const Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      capability.label,
                      style: AppTypography.manrope(13, FontWeight.w600),
                    ),
                  ),
                  if (reference != null)
                    SizedBox(
                      width: _columnWidth,
                      child: _CapabilityMark(
                        included: reference!.has(capability),
                      ),
                    ),
                  SizedBox(
                    width: _columnWidth,
                    child: _CapabilityMark(included: plan.has(capability)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Coche verte si la fonction est incluse, croix grise sinon.
class _CapabilityMark extends StatelessWidget {
  const _CapabilityMark({required this.included});

  final bool included;

  @override
  Widget build(BuildContext context) {
    return Icon(
      included ? Icons.check_rounded : Icons.close_rounded,
      size: 17,
      color: included ? AppColors.accent : AppColors.borderStrong,
    );
  }
}

/// Récapitulatif du montant prélevé, avec le tarif plein barré à l'année.
class _PriceRecap extends StatelessWidget {
  const _PriceRecap({required this.plan, required this.cycle});

  final SubscriptionPlan plan;
  final BillingCycle cycle;

  @override
  Widget build(BuildContext context) {
    final annual = cycle == BillingCycle.annual;
    final charge = cycle.chargeAmount(plan.pricePerMonthFcfa);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tintGreenSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.tintGreenBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${plan.name} · ${cycle.label.toLowerCase()}',
                    style: AppTypography.manrope(
                      13,
                      FontWeight.w600,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
                Text(
                  Formatters.fcfa(
                    annual
                        ? cycle.fullYearPrice(plan.pricePerMonthFcfa)
                        : plan.pricePerMonthFcfa,
                  ),
                  style: AppTypography.sora(
                    13,
                    FontWeight.w600,
                    color: AppColors.textBody,
                  ).copyWith(
                    decoration: annual ? TextDecoration.lineThrough : null,
                    color: AppColors.textBody.withValues(
                      alpha: annual ? 0.55 : 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.tintGreenBorder),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    annual
                        ? 'Payé aujourd\'hui (−${cycle.discountPercent} %)'
                        : 'Payé aujourd\'hui',
                    style: AppTypography.manrope(
                      13.5,
                      FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Text(
                  Formatters.fcfa(charge),
                  style: AppTypography.sora(
                    19,
                    FontWeight.w800,
                    color: AppColors.primary,
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

/// Tuile de choix du moyen de paiement (Wave, Orange Money, carte).
class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: selected ? AppColors.tintGreen : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(method.icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              // Libellés courts de la maquette, la tuile fait un tiers d'écran.
              switch (method) {
                PaymentMethod.orangeMoney => 'Orange Money',
                PaymentMethod.card => 'Carte',
                _ => method.label,
              },
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.sora(11.5, FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
