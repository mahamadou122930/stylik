import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/salon_service.dart';
import 'catalog_providers.dart';

/// 5.3 — Packages / forfaits : services combinés à prix réduit.
class PackagesPage extends ConsumerWidget {
  const PackagesPage({super.key});

  static const routeName = '/catalog/packages';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(packagesProvider);
    final services = ref.watch(servicesProvider);

    return AppScreen(
      title: 'Forfaits',
      largeTitle: true,
      action: AppIconButton(
        icon: Icons.add_rounded,
        filled: true,
        onTap: () {
          // TODO(catalog): assistant de création d'un forfait.
        },
      ),
      child: services.isLoading
          ? const AppLoader()
          : packages.isEmpty
              ? const AppEmptyState(
                  title: 'Aucun forfait',
                  message: 'Combinez plusieurs prestations à prix réduit pour '
                      'augmenter le panier moyen.',
                  icon: Icons.auto_awesome_rounded,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < packages.length; i++) ...[
                      _PackageCard(
                        package: packages[i],
                        accent: AppColors
                            .chartSeries[i % AppColors.chartSeries.length],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
    );
  }
}

class _PackageCard extends ConsumerWidget {
  const _PackageCard({required this.package, required this.accent});

  final SalonService package;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(packageContentProvider(package));
    final discount = package.discountPercent;

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconTile(
                icon: Icons.auto_awesome_rounded,
                color: accent,
                background: accent.withValues(alpha: 0.14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.name,
                      style: AppTypography.sora(15.5, FontWeight.w700),
                    ),
                    if (package.description?.isNotEmpty ?? false)
                      Text(
                        package.description!,
                        style: AppTypography.manrope(
                          12,
                          FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.fcfa(package.priceFcfa),
                style: AppTypography.sora(
                  24,
                  FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
              if (package.originalPriceFcfa != null) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    Formatters.fcfa(package.originalPriceFcfa!),
                    style: AppTypography.manrope(
                      14,
                      FontWeight.w600,
                      color: AppColors.textFaint,
                    ).copyWith(decoration: TextDecoration.lineThrough),
                  ),
                ),
              ],
              if (discount != null) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: AppBadge(
                    label: '−$discount %',
                    color: AppColors.primary,
                    background: AppColors.tintGreen,
                    dense: true,
                  ),
                ),
              ],
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final service in content)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      service.name,
                      style: AppTypography.manrope(
                        11.5,
                        FontWeight.w600,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
