import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
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
        const SizedBox(height: 12),
        const FinanceAnchorNavigator(),
      ],
    );
  }
}

/// Recul et avance d'une période, avec le libellé de la fenêtre au milieu
/// et le menu déroulant de choix d'année à l'angle pour les échelles pertinentes.
class FinanceAnchorNavigator extends ConsumerWidget {
  const FinanceAnchorNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(financePeriodProvider);
    final anchor = ref.watch(financeAnchorProvider);
    final now = DateTime.now();

    // On ne dépasse pas la période en cours : il n'y a pas de chiffre
    // d'affaires à venir.
    final isCurrent =
        period
            .rangeFor(anchor)
            .from
            .isAtSameMomentAs(period.rangeFor(now).from) ||
        period.rangeFor(anchor).from.isAfter(period.rangeFor(now).from);

    void shift(int steps) => ref.read(financeAnchorProvider.notifier).state =
        period.shift(anchor, steps);

    return Row(
      children: [
        AppIconButton(icon: LucideIcons.chevronLeft, onTap: () => shift(-1)),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          icon: LucideIcons.chevronRight,
          enabled: !isCurrent,
          onTap: () => shift(1),
        ),
        if (period.hasYearPicker) ...[
          const SizedBox(width: 8),
          const FinanceYearDropdown(),
        ],
      ],
    );
  }
}

/// Menu déroulant de choix d'année, positionné à l'angle du navigateur.
class FinanceYearDropdown extends ConsumerWidget {
  const FinanceYearDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final years = ref.watch(financeYearsProvider);
    final anchor = ref.watch(financeAnchorProvider);

    return PopupMenuButton<int>(
      initialValue: anchor.year,
      tooltip: 'Changer d\'année',
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      onSelected: (year) {
        final now = DateTime.now();
        var targetMonth = anchor.month;
        if (year == now.year && targetMonth > now.month) {
          targetMonth = now.month;
        }
        ref.read(financeAnchorProvider.notifier).state = DateTime(
          year,
          targetMonth,
          anchor.day.clamp(1, 28),
        );
      },
      itemBuilder: (context) => [
        for (final year in years)
          PopupMenuItem<int>(
            value: year,
            height: 42,
            child: Row(
              children: [
                Icon(
                  LucideIcons.calendar,
                  size: 14,
                  color: year == anchor.year
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Année $year',
                  style: AppTypography.manrope(
                    13,
                    year == anchor.year ? FontWeight.w700 : FontWeight.w500,
                    color: year == anchor.year
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (year == anchor.year)
                  const Icon(
                    LucideIcons.check,
                    size: 15,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
      ],
      child: Container(
        height: AppSizes.iconButtonSize,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.calendar,
              size: 13,
              color: AppColors.primary,
            ),
            const SizedBox(width: 5),
            Text(
              '${anchor.year}',
              style: AppTypography.manrope(
                12.5,
                FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              LucideIcons.chevronDown,
              size: 13,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Alias rétrocompatible.
typedef FinanceYearChips = FinanceYearDropdown;
