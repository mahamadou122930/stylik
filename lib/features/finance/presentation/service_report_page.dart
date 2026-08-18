import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/finance_summary.dart';
import 'finance_providers.dart';

/// 8.3 — Rapport par service : répartition du CA et top prestations.
class ServiceReportPage extends ConsumerWidget {
  const ServiceReportPage({super.key});

  static const routeName = '/finance/services';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performance = ref.watch(servicePerformanceProvider);

    return AppScreen(
      title: 'Par service',
      child: performance.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(servicePerformanceProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyState(
              title: 'Aucune donnée',
              message:
                  'Aucune prestation ni vente encaissée sur cette période.',
              icon: Icons.donut_small_outlined,
            );
          }

          final byCategory = <String, int>{};
          for (final item in items) {
            byCategory[item.category] =
                (byCategory[item.category] ?? 0) + item.revenueFcfa;
          }
          final categories = byCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          // Prestations et produits se classent séparément : mis dans le même
          // palmarès, le shampooing le plus vendu chasserait une coupe du
          // top 5 sans qu'on puisse comparer les deux volumes.
          final services = [...items.where((item) => !item.isProduct)]
            ..sort((a, b) => b.revenueFcfa.compareTo(a.revenueFcfa));
          final products = [...items.where((item) => item.isProduct)]
            ..sort((a, b) => b.revenueFcfa.compareTo(a.revenueFcfa));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                radius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: AppDonutChart(
                  slices: [
                    for (final entry in categories.take(5))
                      ChartSlice(label: entry.key, value: entry.value),
                  ],
                ),
              ),
              if (services.isNotEmpty) ...[
                const AppSectionTitle('Top prestations'),
                AppListCard(
                  children: [
                    for (var i = 0; i < services.take(5).length; i++)
                      _TopServiceRow(rank: i + 1, service: services[i]),
                  ],
                ),
              ],
              if (products.isNotEmpty) ...[
                const AppSectionTitle('Top produits vendus'),
                AppListCard(
                  children: [
                    for (var i = 0; i < products.take(5).length; i++)
                      _TopServiceRow(rank: i + 1, service: products[i]),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TopServiceRow extends StatelessWidget {
  const _TopServiceRow({required this.rank, required this.service});

  final int rank;
  final ServicePerformance service;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              style: AppTypography.sora(
                14,
                FontWeight.w800,
                color: AppColors.textFaint,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name, style: AppTypography.rowTitleStrong),
                const SizedBox(height: 1),
                Text(
                  service.countLabel,
                  style: AppTypography.manrope(
                    11,
                    FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Formatters.fcfa(service.revenueFcfa),
            style: AppTypography.sora(
              13,
              FontWeight.w700,
              color: AppColors.textBody,
            ),
          ),
        ],
      ),
    );
  }
}
