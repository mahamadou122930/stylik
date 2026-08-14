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

/// 8.1 — Chiffre d'affaires : jour / semaine / mois.
class FinancePage extends ConsumerWidget {
  const FinancePage({super.key});

  static const routeName = '/finance';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(financePeriodProvider);
    final summary = ref.watch(financeSummaryProvider);
    final allPayouts = ref.watch(allPayoutsProvider).valueOrNull ?? const [];
    final pendingPayoutCount =
        allPayouts.where((p) => p.status == PayoutStatus.pending).length;

    return AppScreen(
      title: 'Chiffre d\'affaires',
      showBack: false,
      header: AppSegmented(
        boxed: true,
        items: [for (final value in FinancePeriod.values) value.label],
        selectedIndex: FinancePeriod.values.indexOf(period),
        onChanged: (index) => ref.read(financePeriodProvider.notifier).state =
            FinancePeriod.values[index],
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
            _RevenueCard(summary: data, period: period),
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
              AppCard(
                radius: 18,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      period == FinancePeriod.month
                          ? 'Par semaine'
                          : 'Répartition',
                      style: AppTypography.sora(14.5, FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    AppBarChart(
                      slices: [
                        for (final bucket in data.buckets)
                          ChartSlice(
                            label: bucket.label,
                            value: bucket.revenueFcfa,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
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
  const _RevenueCard({required this.summary, required this.period});

  final FinanceSummary summary;
  final FinancePeriod period;

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

  String _periodLabel() => switch (period) {
        FinancePeriod.day => 'aujourd\'hui',
        FinancePeriod.week => '7 derniers jours',
        FinancePeriod.month => '30 derniers jours',
      };
}
