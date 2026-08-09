import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/product.dart';
import 'consumption_page.dart';
import 'inventory_providers.dart';
import 'product_detail_page.dart';
import 'product_form_page.dart';
import 'stock_reception_page.dart';

/// 7.1 — Inventaire : niveaux, alertes et valeur du stock.
class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  static const routeName = '/inventory';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final lowStock = ref.watch(lowStockProductsProvider);
    final stockValue = ref.watch(stockValueProvider);

    return AppScreen(
      title: 'Inventaire',
      largeTitle: true,
      showBack: false,
      action: AppIconButton(
        icon: Icons.add_rounded,
        filled: true,
        onTap: () async {
          final res = await Navigator.of(context)
              .pushNamed(ProductFormPage.routeName);
          if (res == true) {
            ref.invalidate(productsProvider);
          }
        },
      ),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Row(
          children: [
            Expanded(
              child: AppStatTile(
                label: 'Valeur stock',
                value: Formatters.fcfa(stockValue),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppCard(
                radius: 16,
                shadow: false,
                color: AppColors.tintExpense,
                borderColor: AppColors.dangerBorder,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'À réappro.',
                      style: AppTypography.manrope(
                        11.5,
                        FontWeight.w600,
                        color: AppColors.dangerDeep,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${lowStock.length}',
                      style: AppTypography.sora(
                        20,
                        FontWeight.w800,
                        color: AppColors.expense,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      footer: lowStock.isEmpty
          ? null
          : AppButton(
              label: 'Commander les ${lowStock.length} en alerte',
              icon: Icons.receipt_long_rounded,
              onPressed: () => Navigator.of(context)
                  .pushNamed(StockReceptionPage.routeName),
            ),
      child: products.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(productsProvider),
        ),
        data: (items) => items.isEmpty
            ? const AppEmptyState(
                title: 'Stock vide',
                message: 'Ajoutez vos produits de revente et consommables.',
                icon: Icons.inventory_2_outlined,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppListCard(
                    children: [
                      for (final product in items)
                        ProductRow(
                          product: product,
                          onTap: () => Navigator.of(context).pushNamed(
                            ProductDetailPage.routeName,
                            arguments: product.id,
                          ),
                        ),
                    ],
                  ),
                  const AppSectionTitle('Suivi'),
                  AppListCard(
                    children: [
                      AppListRow(
                        label: 'Consommation en soin',
                        subtitle: 'Produits utilisés, non revendus',
                        strong: true,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        leading: const AppIconTile(icon: Icons.science_rounded),
                        trailing: const AppChevron(),
                        onTap: () => Navigator.of(context)
                            .pushNamed(ConsumptionPage.routeName),
                      ),
                      AppListRow(
                        label: 'Réception de stock',
                        subtitle: 'Valider une livraison fournisseur',
                        strong: true,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        leading: const AppIconTile(
                          icon: Icons.local_shipping_rounded,
                          color: AppColors.amber,
                          background: AppColors.tintAmber,
                        ),
                        trailing: const AppChevron(),
                        onTap: () => Navigator.of(context)
                            .pushNamed(StockReceptionPage.routeName),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// Ligne de produit avec puce de niveau de stock.
class ProductRow extends StatelessWidget {
  const ProductRow({super.key, required this.product, this.onTap});

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (product.level) {
      StockLevel.ok => (AppColors.primary, AppColors.tintGreen),
      StockLevel.low => (AppColors.amber, AppColors.tintAmber),
      StockLevel.out => (AppColors.expense, AppColors.tintExpense),
    };

    return AppListRow(
      label: product.name,
      subtitle: product.brand,
      strong: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(
          Icons.local_drink_outlined,
          size: 19,
          color: AppColors.primary,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          product.stockLabel,
          style: AppTypography.sora(12, FontWeight.w700, color: color),
        ),
      ),
    );
  }
}
