import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/product.dart';
import 'inventory_providers.dart';

/// 7.4 — Consommation en soin : produits utilisés en cabine, non revendus.
class ConsumptionPage extends ConsumerWidget {
  const ConsumptionPage({super.key});

  static const routeName = '/inventory/consumption';

  Future<void> _openUnit(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await openConsumableUnit(ref, product);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayConsumptionProvider);
    final monthCost = ref.watch(monthConsumptionCostProvider);
    final top = ref.watch(topConsumedProductsProvider);
    final consumables = ref.watch(consumablesProvider);
    final maxCost = top.isEmpty ? 0 : top.first.costFcfa;

    return AppScreen(
      title: 'Consommation',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: AppGradientCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          bubbleColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coût produits consommés · ce mois',
                style: AppTypography.manrope(
                  12,
                  FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Formatters.fcfa(monthCost),
                style: AppTypography.sora(
                  24,
                  FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionTitle(
            'Ouvrir une unité',
            padding: EdgeInsets.fromLTRB(2, 2, 2, 4),
          ),
          // Sans consommable en fiche, la section était entièrement masquée :
          // on arrivait sur un écran muet, sans savoir quoi faire pour que le
          // bouton apparaisse.
          if (consumables.isEmpty)
            const AppEmptyState(
              compact: true,
              title: 'Aucun consommable',
              message:
                  'Aucune fiche produit n\'est marquée « Consommé en '
                  'soin ». Ouvrez un produit depuis Stock et changez sa '
                  'destination : le bouton « Ouvrir » apparaîtra ici.',
              icon: Icons.science_outlined,
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 10),
              child: Text(
                'Une unité entière quitte le stock à l\'ouverture du '
                'contenant, quel que soit le nombre de clients servis avec.',
                style: AppTypography.manrope(
                  11.5,
                  FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            AppListCard(
              children: [
                for (final product in consumables)
                  AppListRow(
                    label: product.name,
                    subtitle: product.packaging == null
                        ? product.stockLabel
                        : '${product.packaging} · ${product.stockLabel}',
                    strong: true,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    trailing: AppPillButton(
                      label: 'Ouvrir',
                      color: product.isOutOfStock
                          ? AppColors.textFaint
                          : AppColors.primary,
                      background: product.isOutOfStock
                          ? AppColors.toggleOff
                          : AppColors.tintGreen,
                      onTap: product.isOutOfStock
                          ? null
                          : () => _openUnit(context, ref, product),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          const AppSectionTitle(
            'Utilisés aujourd\'hui',
            padding: EdgeInsets.fromLTRB(2, 2, 2, 10),
          ),
          today.when(
            loading: () => const AppLoader(compact: true),
            error: (error, _) => AppErrorState(
              message: '$error',
              compact: true,
              onRetry: () => ref.invalidate(todayConsumptionProvider),
            ),
            data: (movements) => movements.isEmpty
                ? const AppEmptyState(
                    compact: true,
                    title: 'Aucune consommation',
                    message:
                        'Les produits utilisés en cabine apparaîtront ici.',
                    icon: Icons.science_outlined,
                  )
                : AppListCard(
                    children: [
                      for (final movement in movements)
                        AppListRow(
                          label: movement.productName ?? 'Produit',
                          subtitle: movement.contextLabel,
                          strong: true,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          trailing: Text(
                            movement.unitLabel ??
                                '${movement.quantity.abs()} unité(s)',
                            style: AppTypography.manrope(
                              12.5,
                              FontWeight.w600,
                              color: AppColors.textBody,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top produits consommés',
                    style: AppTypography.sora(14, FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < top.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              top[i].name,
                              style: AppTypography.manrope(13, FontWeight.w700),
                            ),
                            Text(
                              Formatters.fcfa(top[i].costFcfa),
                              style: AppTypography.sora(
                                12.5,
                                FontWeight.w700,
                                color: AppColors.textBody,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        AppProgressBar(
                          value: maxCost == 0 ? 0 : top[i].costFcfa / maxCost,
                          background: AppColors.trackNeutral,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
