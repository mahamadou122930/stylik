import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/finance_summary.dart';
import 'finance_providers.dart';
import 'stylist_commission_detail_page.dart';

/// 8.2 — Rapport par coiffeur : CA généré et commission due.
class StylistReportPage extends ConsumerWidget {
  const StylistReportPage({super.key});

  static const routeName = '/finance/stylists';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(financePeriodProvider);
    final commissions = ref.watch(commissionsProvider);

    return AppScreen(
      title: 'Par coiffeur',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 12),
            child: Text(
              '${period.label} · CA généré et commission due',
              style: AppTypography.manrope(
                12.5,
                FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          commissions.when(
            loading: () => const AppLoader(),
            error: (error, _) => AppErrorState(
              message: '$error',
              onRetry: () => ref.invalidate(commissionsProvider),
            ),
            data: (items) => items.isEmpty
                ? const AppEmptyState(
                    title: 'Aucune donnée',
                    message: 'Aucune prestation encaissée sur cette période.',
                    icon: Icons.insights_outlined,
                  )
                : Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        _StylistCard(
                          commission: items[i],
                          accent: AppColors
                              .chartSeries[i % AppColors.chartSeries.length],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _StylistCard extends StatelessWidget {
  const _StylistCard({required this.commission, required this.accent});

  final StylistCommission commission;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).pushNamed(
        StylistCommissionDetailPage.routeName,
        arguments: commission,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  Formatters.initials(commission.stylistName),
                  style: AppTypography.sora(15, FontWeight.w700, color: accent),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commission.stylistName,
                      style: AppTypography.manrope(15, FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      [
                        if (commission.speciality?.isNotEmpty ?? false)
                          commission.speciality!,
                        '${commission.clientCount} clients',
                      ].join(' · '),
                      style: AppTypography.rowSubtitle,
                    ),
                  ],
                ),
              ),
              AppBadge(
                label: '${commission.commissionRate.toStringAsFixed(0)} %',
                color: accent,
                background: accent.withValues(alpha: 0.14),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppSplitMetrics(
            entries: [
              (
                value: Formatters.fcfa(commission.revenueFcfa),
                label: 'CA généré',
                color: null,
              ),
              (
                value: Formatters.fcfa(commission.commissionFcfa),
                label: 'Commission',
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
