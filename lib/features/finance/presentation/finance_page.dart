import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/finance_summary.dart';
import '../domain/payout.dart';
import 'expenses_page.dart';
import 'export_page.dart';
import 'finance_providers.dart';
import 'payout_requests_page.dart';
import 'service_report_page.dart';
import 'stylist_report_page.dart';

/// Histogramme de la période, dont chaque colonne est sélectionnable pour
/// lire son montant — sinon la hauteur relative des barres est la seule
/// information disponible, et un creux ne se chiffre pas.
class _BreakdownCard extends StatefulWidget {
  const _BreakdownCard({required this.buckets, required this.period});

  final List<FinanceBucket> buckets;
  final FinancePeriod period;

  @override
  State<_BreakdownCard> createState() => _BreakdownCardState();
}

class _BreakdownCardState extends State<_BreakdownCard> {
  int? _selected;

  @override
  void didUpdateWidget(_BreakdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changer de période ou reculer d'un cran recompose les colonnes : garder
    // l'ancienne sélection ferait pointer un montant qui n'est plus le sien.
    if (oldWidget.period != widget.period ||
        oldWidget.buckets.length != widget.buckets.length) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = (_selected != null && _selected! < widget.buckets.length)
        ? _selected
        : null;
    final bucket = selected == null ? null : widget.buckets[selected];

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
                  bucket == null
                      ? (widget.period == FinancePeriod.month
                          ? 'Par semaine'
                          : 'Répartition')
                      : bucket.label,
                  style: AppTypography.sora(14.5, FontWeight.w700),
                ),
              ),
              if (bucket != null)
                Text(
                  Formatters.fcfa(bucket.revenueFcfa),
                  style: AppTypography.sora(
                    13,
                    FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          AppBarChart(
            highlightMax: selected == null,
            highlightIndex: selected,
            onSliceTap: (index) => setState(
              () => _selected = _selected == index ? null : index,
            ),
            slices: [
              for (final item in widget.buckets)
                ChartSlice(label: item.label, value: item.revenueFcfa),
            ],
          ),
          if (bucket != null) ...[
            const SizedBox(height: 10),
            Text(
              bucket.revenueFcfa == 0
                  ? 'Aucun encaissement sur cette tranche.'
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

/// Recul et avance d'une période, avec le libellé de la fenêtre au milieu.
class _PeriodNavigator extends ConsumerWidget {
  const _PeriodNavigator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(financePeriodProvider);
    final offset = ref.watch(financePeriodOffsetProvider);

    void shift(int step) =>
        ref.read(financePeriodOffsetProvider.notifier).state = offset + step;

    return Row(
      children: [
        AppIconButton(
          icon: Icons.chevron_left_rounded,
          onTap: () => shift(-1),
        ),
        Expanded(
          child: GestureDetector(
            // Revenir au présent en un geste, sans remonter cran par cran.
            onTap: offset == 0
                ? null
                : () => ref.read(financePeriodOffsetProvider.notifier).state = 0,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Text(
                  period.labelAt(offset),
                  textAlign: TextAlign.center,
                  style: AppTypography.sora(13.5, FontWeight.w700),
                ),
                if (offset != 0)
                  Text(
                    'Revenir à aujourd\'hui',
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
          // Pas de chiffre d'affaires à venir : l'avance s'arrête au présent,
          // et la flèche se grise pour que ce soit visible.
          onTap: offset >= 0 ? null : () => shift(1),
          color: offset >= 0 ? AppColors.textFaint : null,
        ),
      ],
    );
  }
}

/// 8.1 — Chiffre d'affaires : jour / semaine / mois.
class FinancePage extends ConsumerWidget {
  const FinancePage({super.key});

  static const routeName = '/finance';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(financePeriodProvider);
    final offset = ref.watch(financePeriodOffsetProvider);
    final summary = ref.watch(financeSummaryProvider);
    final allPayouts = ref.watch(allPayoutsProvider).valueOrNull ?? const [];
    final pendingPayoutCount =
        allPayouts.where((p) => p.status == PayoutStatus.pending).length;

    return AppScreen(
      title: 'Chiffre d\'affaires',
      showBack: false,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSegmented(
            boxed: true,
            items: [for (final value in FinancePeriod.values) value.label],
            selectedIndex: FinancePeriod.values.indexOf(period),
            onChanged: (index) {
              ref.read(financePeriodProvider.notifier).state =
                  FinancePeriod.values[index];
              // Changer de granularité ramène à la période en cours : garder
              // « −3 crans » en passant de Jour à Mois ferait sauter de trois
              // jours à trois mois en arrière sans que rien ne le dise.
              ref.read(financePeriodOffsetProvider.notifier).state = 0;
            },
          ),
          const SizedBox(height: 10),
          const _PeriodNavigator(),
        ],
      ),
      child: summary.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(financeSummaryProvider),
        ),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RevenueCard(summary: data, period: period, offset: offset),
            if (pendingPayoutCount > 0) ...[
              const SizedBox(height: 12),
              AppCard(
                onTap: () => Navigator.of(context)
                    .pushNamed(PayoutRequestsPage.routeName),
                radius: 14,
                shadow: false,
                color: AppColors.tintAmber,
                borderColor: AppColors.amberBorder,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 20,
                      color: AppColors.amberDeep,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$pendingPayoutCount demande(s) de versement en attente',
                        style: AppTypography.manrope(
                          13,
                          FontWeight.w600,
                          color: AppColors.amberDeep,
                        ),
                      ),
                    ),
                    const AppChevron(),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppStatTile(
                    label: 'Encaissé',
                    value: Formatters.fcfa(data.collectedFcfa),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppStatTile(
                    label: 'En attente',
                    value: Formatters.fcfa(data.pendingFcfa),
                    valueColor: AppColors.amber,
                  ),
                ),
              ],
            ),
            if (data.buckets.isNotEmpty) ...[
              const SizedBox(height: 12),
              _BreakdownCard(buckets: data.buckets, period: period),
            ],
            const AppSectionTitle('Rapports'),
            AppListCard(
              children: [
                AppListRow(
                  label: 'Par coiffeur',
                  subtitle: 'Performance et commissions',
                  strong: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  leading: const AppIconTile(icon: Icons.people_alt_rounded),
                  trailing: const AppChevron(),
                  onTap: () => Navigator.of(context)
                      .pushNamed(StylistReportPage.routeName),
                ),
                AppListRow(
                  label: 'Demandes de versement',
                  subtitle: 'Valider et régler les versements aux coiffeurs',
                  strong: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  leading: const AppIconTile(
                    icon: Icons.payments_outlined,
                    color: AppColors.amberDeep,
                    background: AppColors.tintAmber,
                  ),
                  trailing: pendingPayoutCount == 0
                      ? const AppChevron()
                      : AppBadge(
                          label: '$pendingPayoutCount',
                          color: AppColors.amberDeep,
                          background: AppColors.tintAmber,
                          dense: true,
                        ),
                  onTap: () => Navigator.of(context)
                      .pushNamed(PayoutRequestsPage.routeName),
                ),
                AppListRow(
                  label: 'Par service',
                  subtitle: 'Répartition et top prestations',
                  strong: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  leading: const AppIconTile(
                    icon: Icons.donut_small_rounded,
                    color: AppColors.blue,
                    background: AppColors.tintBlue,
                  ),
                  trailing: const AppChevron(),
                  onTap: () => Navigator.of(context)
                      .pushNamed(ServiceReportPage.routeName),
                ),
                AppListRow(
                  label: 'Dépenses & charges',
                  subtitle: 'Sorties et résultat net',
                  strong: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  leading: const AppIconTile(
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.expense,
                    background: AppColors.tintExpense,
                  ),
                  trailing: const AppChevron(),
                  onTap: () =>
                      Navigator.of(context).pushNamed(ExpensesPage.routeName),
                ),
                AppListRow(
                  label: 'Export comptable',
                  subtitle: 'Période, format, envoi',
                  strong: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  leading: const AppIconTile(
                    icon: Icons.ios_share_rounded,
                    color: AppColors.amber,
                    background: AppColors.tintAmber,
                  ),
                  trailing: const AppChevron(),
                  onTap: () =>
                      Navigator.of(context).pushNamed(ExportPage.routeName),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte verte du CA de la période, avec écart vs période précédente.
class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.summary,
    required this.period,
    required this.offset,
  });

  final FinanceSummary summary;
  final FinancePeriod period;

  /// Décalage de la fenêtre affichée, `0` pour la période en cours.
  final int offset;

  @override
  Widget build(BuildContext context) {
    final growth = summary.growthPercent;

    return AppGradientCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      bubbleColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CA · ${_periodLabel()}',
            style: AppTypography.manrope(
              13,
              FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.fcfa(summary.revenueFcfa),
              style: AppTypography.sora(
                32,
                FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  growth != null && growth < 0
                      ? Icons.trending_down_rounded
                      : Icons.trending_up_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  growth == null
                      ? '${summary.ticketCount} tickets'
                      : '${growth > 0 ? '+' : ''}$growth % vs période précédente',
                  style: AppTypography.sora(
                    12.5,
                    FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Hors période en cours, on nomme la fenêtre réellement affichée : garder
  /// « aujourd'hui » au-dessus du chiffre d'avant-hier serait un contresens.
  String _periodLabel() {
    if (offset != 0) return period.labelAt(offset).toLowerCase();

    return switch (period) {
      FinancePeriod.day => 'aujourd\'hui',
      FinancePeriod.week => '7 derniers jours',
      FinancePeriod.month => '30 derniers jours',
    };
  }
}
