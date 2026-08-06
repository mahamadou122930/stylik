import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/product.dart';
import 'inventory_providers.dart';

/// 7.2 — Fiche produit : stock, seuil d'alerte, fournisseur.
class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({super.key, required this.productId});

  static const routeName = '/inventory/product';

  final String productId;

  Future<void> _adjustStock(BuildContext context, WidgetRef ref, Product product) async {
    final delta = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => _AdjustStockSheet(product: product),
    );
    if (delta == null || delta == 0) return;

    await ref.read(inventoryRepositoryProvider).adjustStock(
          productId: product.id,
          delta: delta,
          reason: 'adjustment',
        );
    ref.invalidate(productDetailProvider(product.id));
    ref.invalidate(productsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(productId));

    return AppScreen(
      title: product.valueOrNull?.name ?? 'Produit',
      action: AppIconButton(
        icon: Icons.edit_outlined,
        onTap: () {
          // TODO(inventory): édition de la fiche produit.
        },
      ),
      footer: product.valueOrNull == null
          ? null
          : Row(
              children: [
                Expanded(
                  child: AppButton.outline(
                    label: 'Ajuster le stock',
                    onPressed: () =>
                        _adjustStock(context, ref, product.value!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'Commander',
                    onPressed: () {
                      // TODO(inventory): générer une commande fournisseur.
                    },
                  ),
                ),
              ],
            ),
      child: product.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(productDetailProvider(productId)),
        ),
        data: (data) => data == null
            ? const AppEmptyState(
                title: 'Produit introuvable',
                icon: Icons.inventory_2_outlined,
              )
            : _ProductBody(product: data),
      ),
    );
  }
}

class _ProductBody extends StatelessWidget {
  const _ProductBody({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (product.isLowStock) ...[
          AppCard(
            radius: 16,
            shadow: false,
            color: product.isOutOfStock
                ? AppColors.tintExpense
                : AppColors.tintAmber,
            borderColor: product.isOutOfStock
                ? AppColors.dangerBorder
                : AppColors.amberBorder,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 22,
                  color: product.isOutOfStock
                      ? AppColors.expense
                      : AppColors.amber,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.isOutOfStock ? 'Rupture de stock' : 'Stock bas',
                        style: AppTypography.sora(
                          14,
                          FontWeight.w700,
                          color: product.isOutOfStock
                              ? AppColors.expense
                              : AppColors.amber,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${product.stockQuantity} restants, '
                        'sous le seuil de ${product.alertThreshold}.',
                        style: AppTypography.manrope(
                          12,
                          FontWeight.w500,
                          color: AppColors.amberDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        AppSplitMetrics(
          entries: [
            (
              value: '${product.stockQuantity}',
              label: 'En stock',
              color: product.isLowStock ? AppColors.amber : null,
            ),
            (
              value: '${product.alertThreshold}',
              label: 'Seuil',
              color: null,
            ),
            (
              value: Formatters.fcfa(product.unitCostFcfa),
              label: 'P.U. achat',
              color: null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppListCard(
          children: [
            AppListRow(label: 'Marque', value: product.brand),
            AppListRow(label: 'Catégorie', value: product.category),
            if (product.supplier?.isNotEmpty ?? false)
              AppListRow(label: 'Fournisseur', value: product.supplier!),
            if (product.packaging?.isNotEmpty ?? false)
              AppListRow(label: 'Conditionnement', value: product.packaging!),
            AppListRow(label: 'Usage', value: product.usage.label),
            AppListRow(
              label: 'Prix de vente',
              value: Formatters.fcfa(product.unitSalePriceFcfa),
            ),
          ],
        ),
      ],
    );
  }
}

/// Feuille d'ajustement rapide du stock (+ / −).
class _AdjustStockSheet extends StatefulWidget {
  const _AdjustStockSheet({required this.product});

  final Product product;

  @override
  State<_AdjustStockSheet> createState() => _AdjustStockSheetState();
}

class _AdjustStockSheetState extends State<_AdjustStockSheet> {
  int _delta = 0;

  @override
  Widget build(BuildContext context) {
    final result = widget.product.stockQuantity + _delta;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ajuster le stock',
              style: AppTypography.sora(17, FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.product.name} · ${widget.product.stockQuantity} en stock',
              style: AppTypography.rowSubtitle,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIconButton(
                  icon: Icons.remove_rounded,
                  onTap: () => setState(() => _delta--),
                ),
                SizedBox(
                  width: 96,
                  child: Text(
                    '$result',
                    textAlign: TextAlign.center,
                    style: AppTypography.sora(28, FontWeight.w800),
                  ),
                ),
                AppIconButton(
                  icon: Icons.add_rounded,
                  filled: true,
                  onTap: () => setState(() => _delta++),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Valider',
              onPressed:
                  _delta == 0 ? null : () => Navigator.pop(context, _delta),
            ),
          ],
        ),
      ),
    );
  }
}
