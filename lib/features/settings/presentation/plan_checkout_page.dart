import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/error_messages.dart';
import '../domain/subscription_plan.dart';
import 'payment_instructions_page.dart';
import 'settings_providers.dart';

/// B — Comparatif & paiement : détail des fonctions, récap et souscription.
class PlanCheckoutPage extends ConsumerStatefulWidget {
  const PlanCheckoutPage({super.key, required this.plan});

  static const routeName = '/settings/subscription/checkout';

  final SubscriptionPlan plan;

  @override
  ConsumerState<PlanCheckoutPage> createState() => _PlanCheckoutPageState();
}

class _PlanCheckoutPageState extends ConsumerState<PlanCheckoutPage> {
  /// Moyen choisi parmi les comptes configurés. Nul tant qu'aucun n'est
  /// choisi : le premier compte est alors proposé.
  String? _method;
  bool _isSubmitting = false;

  /// Dépose la demande, puis montre où et comment payer.
  ///
  /// L'application ne s'active plus elle-même : `changePlan` passait le salon
  /// en formule payée sans que rien ne soit payé. La formule est activée
  /// depuis la console, une fois l'argent reçu.
  Future<void> _request(BillingCycle cycle, String? method) async {
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .requestActivation(plan: widget.plan, cycle: cycle, method: method);
      ref.invalidate(pendingSubscriptionRequestProvider);
      if (!mounted) return;

      Navigator.of(
        context,
      ).pushReplacementNamed(PaymentInstructionsPage.routeName);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorMessages.humanize(error))));
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

    final charge = plan.chargeFor(cycle);

    // Les moyens proposés sont ceux où un compte attend l'argent : proposer
    // une carte bancaire qu'aucun processus ne débite ferait payer dans le
    // vide.
    final accounts = ref.watch(paymentAccountsProvider).valueOrNull ?? const [];
    final methods = <String>[];
    for (final account in accounts) {
      if (!methods.contains(account.method)) methods.add(account.method);
    }
    final method = methods.contains(_method)
        ? _method
        : (methods.isEmpty ? null : methods.first);

    return AppScreen(
      title: '${plan.name} · détail',
      footer: AppButton(
        label: "Demander l'activation",
        trailingLabel: Formatters.fcfa(charge),
        height: 56,
        isLoading: _isSubmitting,
        onPressed: () => _request(cycle, method),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ComparisonTable(plan: plan, reference: lower),
          const SizedBox(height: 14),
          _PriceRecap(plan: plan, cycle: cycle),
          if (methods.isNotEmpty) ...[
            const AppSectionLabel(
              'Moyen de paiement',
              padding: EdgeInsets.fromLTRB(2, 18, 2, 10),
            ),
            Row(
              children: [
                for (final option in methods) ...[
                  if (option != methods.first) const SizedBox(width: 8),
                  Expanded(
                    child: _MethodTile(
                      label: option,
                      selected: method == option,
                      onTap: () => setState(() => _method = option),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            // Rien n'est prélevé automatiquement : l'annoncer ferait attendre
            // un débit qui ne viendra pas, et laisserait le salon s'éteindre
            // à l'échéance sans qu'il ait compris pourquoi.
            'Pas de prélèvement automatique : vous recevez une référence et '
            'le numéro où envoyer le paiement. Votre formule est activée dès '
            "réception, et court jusqu'à la fin de la période réglée.",
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
                    : const Border(bottom: BorderSide(color: AppColors.border)),
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
      included ? LucideIcons.check : LucideIcons.x,
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
    final charge = plan.chargeFor(cycle);

    // Rien n'est payé dans l'application : c'est un montant à envoyer.
    final paymentLabel = annual
        ? 'À régler (−${plan.discountPercentFor(cycle)} %)'
        : 'À régler';

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
                    annual ? plan.fullYearPrice : plan.pricePerMonthFcfa,
                  ),
                  style:
                      AppTypography.sora(
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
                    paymentLabel,
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

/// Tuile de choix du moyen de paiement, une par compte configuré.
class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
            Icon(LucideIcons.smartphone, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
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
