import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import 'finance_providers.dart';

/// Résultat net : ce qui reste au salon une fois l'équipe et les charges
/// payées.
///
/// Écran à part entière plutôt qu'une carte dans Finance : c'est le chiffre
/// que le gérant vient chercher, et il se lit sur quatre échelles de temps.
class NetResultPage extends ConsumerWidget {
  const NetResultPage({super.key});

  static const routeName = '/finance/net-result';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(financePeriodProvider);
    final offset = ref.watch(financePeriodOffsetProvider);
    final summary = ref.watch(financeSummaryProvider);

    final revenue = summary.valueOrNull?.revenueFcfa ?? 0;
    final commissions = ref.watch(periodCommissionsProvider);
    final expenses = ref.watch(expensesTotalProvider);
    final net = ref.watch(netResultProvider);
    final margin = ref.watch(netMarginProvider);

    return AppScreen(
      title: 'Résultat net',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        child: AppSegmented(
          boxed: true,
          items: [for (final value in FinancePeriod.values) value.label],
          selectedIndex: FinancePeriod.values.indexOf(period),
          onChanged: (index) {
            ref.read(financePeriodProvider.notifier).state =
                FinancePeriod.values[index];
            ref.read(financePeriodOffsetProvider.notifier).state = 0;
          },
        ),
      ),
      child: summary.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(financeSummaryProvider),
        ),
        data: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroCard(
              net: net,
              margin: margin,
              periodLabel: period.labelAt(offset).toLowerCase(),
            ),
            const SizedBox(height: 12),
            AppCard(
              radius: 18,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Line(label: 'Chiffre d\'affaires', value: revenue),
                  _Line(
                    label: 'Dépenses / charges',
                    value: expenses,
                    isDeduction: true,
                  ),
                  _Line(
                    label: 'Commissions coiffeurs',
                    value: commissions,
                    isDeduction: true,
                  ),
                  const Divider(height: 20, color: AppColors.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Résultat net',
                        style: AppTypography.sora(15, FontWeight.w800),
                      ),
                      Text(
                        Formatters.fcfa(net),
                        style: AppTypography.sora(
                          16,
                          FontWeight.w800,
                          color:
                              net < 0 ? AppColors.expense : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _NetChartCard(),
            const SizedBox(height: 14),
            Text(
              'Le chiffre d\'affaires retenu est celui des tickets encaissés '
              'sur la période. Les commissions sont celles dues à l\'équipe, '
              'qu\'elles aient déjà été versées ou non.',
              style: AppTypography.manrope(
                12,
                FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau vert : le net et la marge.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.net,
    required this.margin,
    required this.periodLabel,
  });

  final int net;
  final int? margin;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final isLoss = net < 0;

    return AppCard(
      color: isLoss ? AppColors.expense : AppColors.primary,
      borderColor: isLoss ? AppColors.expense : AppColors.primary,
      shadow: false,
      radius: 18,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Résultat net · $periodLabel',
            style: AppTypography.manrope(
              12.5,
              FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.fcfa(net),
              maxLines: 1,
              style: AppTypography.sora(
                30,
                FontWeight.w800,
                letterSpacing: -0.8,
                color: Colors.white,
              ),
            ),
          ),
          if (margin != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLoss
                        ? Icons.trending_down_rounded
                        : Icons.trending_up_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'marge $margin %',
                    style: AppTypography.manrope(
                      12,
                      FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Histogramme du net par sous-période, dont chaque colonne se touche pour
/// lire son montant.
class _NetChartCard extends ConsumerStatefulWidget {
  const _NetChartCard();

  @override
  ConsumerState<_NetChartCard> createState() => _NetChartCardState();
}

class _NetChartCardState extends ConsumerState<_NetChartCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(financePeriodProvider);
    final buckets = ref.watch(netBucketsProvider);

    final title = switch (period) {
      FinancePeriod.day => 'Net par tranche horaire',
      FinancePeriod.week => 'Net par jour',
      FinancePeriod.month => 'Net par semaine',
      FinancePeriod.year => 'Net par mois',
    };

    final rows = buckets.valueOrNull ?? const [];
    // Changer d'échelle recompose les colonnes : garder l'ancienne sélection
    // ferait pointer un montant qui n'est plus le sien.
    final selected =
        (_selected != null && _selected! < rows.length) ? _selected : null;

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  selected == null ? title : rows[selected].label,
                  style: AppTypography.sora(14.5, FontWeight.w700),
                ),
              ),
              if (selected != null)
                Text(
                  Formatters.fcfa(rows[selected].netFcfa),
                  style: AppTypography.sora(
                    13,
                    FontWeight.w700,
                    color: rows[selected].netFcfa < 0
                        ? AppColors.expense
                        : AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          buckets.when(
            loading: () => const AppLoader(compact: true),
            error: (error, _) => AppErrorState(
              message: '$error',
              compact: true,
              onRetry: () => ref.invalidate(netBucketsProvider),
            ),
            data: (_) => rows.isEmpty
                ? const AppEmptyState(
                    compact: true,
                    title: 'Aucune donnée',
                    message: 'Aucun encaissement sur cette période.',
                    icon: Icons.insights_outlined,
                  )
                : AppBarChart(
                    height: 96,
                    highlightMax: selected == null,
                    highlightIndex: selected,
                    onSliceTap: (index) => setState(
                      () => _selected = _selected == index ? null : index,
                    ),
                    slices: [
                      for (final row in rows)
                        ChartSlice(
                          label: row.label,
                          // Une tranche déficitaire ne peut pas se dessiner en
                          // hauteur : elle reste au sol, en rouge, plutôt que
                          // de fausser l'échelle des autres.
                          value: row.netFcfa < 0 ? 0 : row.netFcfa,
                          color: row.netFcfa < 0 ? AppColors.expense : null,
                        ),
                    ],
                  ),
          ),
          if (selected != null) ...[
            const SizedBox(height: 10),
            Text(
              rows[selected].netFcfa == 0
                  ? 'Aucune activité sur cette tranche.'
                  : 'Touchez à nouveau la colonne pour revenir à la vue '
                      'd\'ensemble.',
              style: AppTypography.manrope(
                11.5,
                FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ligne du récapitulatif : ce qui entre, ce qui sort.
class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.isDeduction = false,
  });

  final String label;

  /// Toujours positif : c'est [isDeduction] qui porte le sens. Se fier au
  /// signe affichait « + 0 F » sur une charge nulle, ce qui se lit comme une
  /// recette.
  final int value;

  final bool isDeduction;

  @override
  Widget build(BuildContext context) {
    final isOut = isDeduction;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.manrope(
              13,
              FontWeight.w500,
              color: AppColors.textBody,
            ),
          ),
          Text(
            '${isOut ? '− ' : '+ '}${Formatters.fcfa(value.abs())}',
            style: AppTypography.sora(
              13.5,
              FontWeight.w700,
              color: isOut ? AppColors.expense : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
