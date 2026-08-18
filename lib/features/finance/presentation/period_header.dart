import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import 'finance_providers.dart';

/// En-tête temporel partagé par les écrans Finance et Résultat net.
///
/// Regroupé ici plutôt que dupliqué : les deux écrans lisent la même période
/// et la même ancre, et les voir diverger serait déroutant.
class FinancePeriodHeader extends ConsumerWidget {
  const FinancePeriodHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(financePeriodProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSegmented(
          boxed: true,
          items: [for (final value in FinancePeriod.values) value.label],
          selectedIndex: FinancePeriod.values.indexOf(period),
          onChanged: (index) {
            ref.read(financePeriodProvider.notifier).state =
                FinancePeriod.values[index];
            // Changer d'échelle ramène au présent : garder une ancre de mars
            // en passant à « Jour » afficherait un jour de mars.
            final now = DateTime.now();
            ref.read(financeAnchorProvider.notifier).state = DateTime(
              now.year,
              now.month,
              now.day,
            );
          },
        ),
        // Le mois et l'année se lisent dans un exercice : le sélecteur évite
        // de reculer douze fois pour atteindre l'an dernier.
        if (period.hasYearPicker) ...[
          const SizedBox(height: 10),
          const FinanceYearChips(),
        ],
        const SizedBox(height: 10),
        const FinanceAnchorNavigator(),
      ],
    );
  }
}

/// Choix de l'année, pour les échelles Mois et Année.
class FinanceYearChips extends ConsumerWidget {
  const FinanceYearChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final years = ref.watch(financeYearsProvider);
    final anchor = ref.watch(financeAnchorProvider);

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: years.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final year = years[index];
          final selected = year == anchor.year;

          return GestureDetector(
            onTap: () => ref.read(financeAnchorProvider.notifier).state =
                DateTime(year, anchor.month, 1),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? AppColors.tintGreen : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: selected ? AppColors.primary : AppColors.textFaint,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Année $year',
                    style: AppTypography.manrope(
                      12.5,
                      FontWeight.w600,
                      color: selected ? AppColors.primary : AppColors.textBody,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Recul et avance d'une période, avec le libellé de la fenêtre au milieu.
class FinanceAnchorNavigator extends ConsumerWidget {
  const FinanceAnchorNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(financePeriodProvider);
    final anchor = ref.watch(financeAnchorProvider);
    final now = DateTime.now();

    // On ne dépasse pas la période en cours : il n'y a pas de chiffre
    // d'affaires à venir.
    final isCurrent = period.rangeFor(anchor).from == period.rangeFor(now).from;

    void shift(int steps) => ref.read(financeAnchorProvider.notifier).state =
        period.shift(anchor, steps);

    return Row(
      children: [
        AppIconButton(icon: Icons.chevron_left_rounded, onTap: () => shift(-1)),
        Expanded(
          child: GestureDetector(
            // Revenir au présent en un geste, sans remonter cran par cran.
            onTap: isCurrent
                ? null
                : () => ref.read(financeAnchorProvider.notifier).state =
                      DateTime(now.year, now.month, now.day),
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Text(
                  period.titleFor(anchor),
                  textAlign: TextAlign.center,
                  style: AppTypography.sora(13.5, FontWeight.w700),
                ),
                if (!isCurrent)
                  Text(
                    "Revenir à aujourd'hui",
                    style: AppTypography.manrope(
                      10.5,
                      FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
        AppIconButton(
          icon: Icons.chevron_right_rounded,
          enabled: !isCurrent,
          onTap: () => shift(1),
        ),
      ],
    );
  }
}
