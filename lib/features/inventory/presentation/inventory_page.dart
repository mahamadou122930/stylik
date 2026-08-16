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

  /// Méthode A — voir `openConsumableUnit`.
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
    final products = ref.watch(productsProvider);
    final lowStock = ref.watch(lowStockProductsProvider);
    final stockValue = ref.watch(stockValueProvider);
    final missingCost = ref.watch(productsWithoutCostProvider);
    final items = ref.watch(filteredProductsProvider);
    final search = ref.watch(productSearchProvider);
    final usageFilter = ref.watch(productUsageFilterProvider);

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
        child: Column(
          children: [
            AppSearchField(
              hint: 'Nom, marque, catégorie, fournisseur…',
              onChanged: (value) =>
                  ref.read(productSearchProvider.notifier).state = value,
            ),
            const SizedBox(height: 10),
            // Revente et consommables ne se pilotent pas pareil : l'un se
            // vend, l'autre s'ouvre. Pouvoir n'afficher que l'un des deux
            // évite de les chercher dans une liste mêlée.
            AppFilterChips(
              items: const ['Tous', 'Revente', 'Consommables'],
              selectedIndex: switch (usageFilter) {
                null => 0,
                ProductUsage.resale => 1,
                ProductUsage.consumable => 2,
              },
              onChanged: (index) =>
                  ref.read(productUsageFilterProvider.notifier).state = switch (
                      index) {
                1 => ProductUsage.resale,
                2 => ProductUsage.consumable,
                _ => null,
              },
            ),
            const SizedBox(height: 12),
            Row(
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
        data: (all) => all.isEmpty
            ? const AppEmptyState(
                title: 'Stock vide',
                message: 'Ajoutez vos produits de revente et consommables.',
                icon: Icons.inventory_2_outlined,
              )
            // Filtre ou recherche sans résultat : ne pas laisser croire au
            // stock vide, et dire lequel des deux critères ne donne rien.
            : items.isEmpty
            ? AppEmptyState(
                title: search.isNotEmpty
                    ? 'Aucun produit trouvé'
                    : usageFilter == ProductUsage.consumable
                        ? 'Aucun consommable'
                        : 'Aucun produit de revente',
                message: search.isNotEmpty
                    ? 'Aucun produit ne correspond à « $search ».'
                    : usageFilter == ProductUsage.consumable
                        // Le cas le plus fréquent : les fiches ont été créées
                        // en « Revente », l'usage par défaut du formulaire.
                        ? 'Aucune fiche n\'est marquée « Consommé en soin ». '
                            'Ouvrez un produit et changez sa destination pour '
                            'pouvoir en déduire les unités ouvertes.'
                        : 'Aucune fiche n\'est marquée « Revendu au client ».',
                icon: Icons.search_off_rounded,
                actionLabel: search.isNotEmpty
                    ? 'Effacer la recherche'
                    : 'Voir tous les produits',
                onAction: () {
                  if (search.isNotEmpty) {
                    ref.read(productSearchProvider.notifier).state = '';
                  } else {
                    ref.read(productUsageFilterProvider.notifier).state = null;
                  }
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (missingCost.isNotEmpty) ...[
                    AppCard(
                      radius: 14,
                      shadow: false,
                      color: AppColors.tintAmber,
                      borderColor: AppColors.amberBorder,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: AppColors.amber,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${missingCost.length} produit(s) sans coût '
                              'd\'achat ne comptent pas dans la valeur du '
                              'stock.',
                              style: AppTypography.manrope(
                                12.5,
                                FontWeight.w600,
                                color: AppColors.amberDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Placés avant la liste : sous quarante produits, personne
                  // ne descendait jusqu'à eux.
                  AppListCard(
                    children: [
                      AppListRow(
                        label: 'Consommation en soin',
                        subtitle: 'Ouvrir une unité, suivre le coût du mois',
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
                  const AppSectionTitle('Produits'),
                  AppListCard(
                    children: [
                      for (final product in items)
                        ProductRow(
                          product: product,
                          // Un consommable ne sort pas du stock par la caisse :
                          // son unique geste, c'est l'ouverture d'une unité.
                          // La proposer ici évite d'ouvrir la fiche pour ça.
                          trailing: product.usage == ProductUsage.consumable
                              ? AppPillButton(
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
                                )
                              : null,
                          onTap: () => Navigator.of(context).pushNamed(
                            ProductDetailPage.routeName,
                            arguments: product.id,
                          ),
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
  const ProductRow({
    super.key,
    required this.product,
    this.onTap,
    this.trailing,
  });

  final Product product;
  final VoidCallback? onTap;

  /// Action ajoutée à droite de la puce de stock (« Ouvrir » d'un
  /// consommable). La puce reste affichée : c'est elle qui dit s'il en reste.
  final Widget? trailing;

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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}
