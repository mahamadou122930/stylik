import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/product.dart';
import 'inventory_providers.dart';
import 'product_form_page.dart';

/// 7.2 — Fiche produit : stock, seuil d'alerte, fournisseur.
class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({super.key, required this.productId});

  static const routeName = '/inventory/product';

  final String productId;

  Future<void> _adjustStock(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final delta = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => _AdjustStockSheet(product: product),
    );
    if (delta == null || delta == 0) return;

    await ref
        .read(inventoryRepositoryProvider)
        .adjustStock(productId: product.id, delta: delta, reason: 'adjustment');
    ref.invalidate(productDetailProvider(product.id));
    ref.invalidate(productsProvider);
  }

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
    final product = ref.watch(productDetailProvider(productId));

    return AppScreen(
      title: product.valueOrNull?.name ?? 'Produit',
      action: product.valueOrNull == null
          ? null
          : AppIconButton(
              icon: Icons.edit_outlined,
              onTap: () async {
                final saved = await Navigator.of(context).pushNamed(
                  ProductFormPage.routeName,
                  arguments: product.value,
                );
                if (saved == true) {
                  ref.invalidate(productDetailProvider(productId));
                }
              },
            ),
      footer: product.valueOrNull == null
          ? null
          : Row(
              children: [
                Expanded(
                  child: AppButton.outline(
                    label: 'Ajuster le stock',
                    onPressed: () => _adjustStock(context, ref, product.value!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  // Un produit de revente sort du stock par la caisse ; un
                  // consommable, lui, n'a que cette porte de sortie.
                  child: product.value!.usage == ProductUsage.consumable
                      ? AppButton(
                          label: 'Ouvrir une unité',
                          icon: Icons.local_drink_outlined,
                          onPressed: product.value!.stockQuantity <= 0
                              ? null
                              : () => _openUnit(context, ref, product.value!),
                        )
                      : AppButton(
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
            (value: '${product.alertThreshold}', label: 'Seuil', color: null),
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
  /// Quantité **finale** saisie, et non l'écart : après un inventaire
  /// physique, on connaît le nombre en rayon, pas l'écart avec la base. Le
  /// delta se déduit, il n'a pas à être calculé de tête.
  late final TextEditingController _target = TextEditingController(
    text: '${widget.product.stockQuantity}',
  );

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  int? get _parsed {
    final value = int.tryParse(_target.text.trim());
    if (value == null || value < 0) return null;
    return value;
  }

  void _bump(int step) {
    final base = _parsed ?? widget.product.stockQuantity;
    final next = (base + step).clamp(0, 1 << 31);
    setState(() {
      _target.text = '$next';
      _target.selection = TextSelection.collapsed(offset: _target.text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = _parsed;
    final delta = target == null ? 0 : target - widget.product.stockQuantity;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          4,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
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
              children: [
                AppIconButton(
                  icon: Icons.remove_rounded,
                  onTap: () => _bump(-1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _target,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: AppTypography.sora(28, FontWeight.w800),
                    decoration: const InputDecoration(
                      labelText: 'Quantité en stock',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AppIconButton(
                  icon: Icons.add_rounded,
                  filled: true,
                  onTap: () => _bump(1),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              switch (delta) {
                0 =>
                  target == null
                      ? 'Saisissez un nombre entier positif.'
                      : 'Aucun changement.',
                > 0 => 'Entrée de $delta unité(s).',
                _ => 'Sortie de ${delta.abs()} unité(s).',
              },
              textAlign: TextAlign.center,
              style: AppTypography.manrope(
                12.5,
                FontWeight.w600,
                color: delta == 0 ? AppColors.textSecondary : AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Valider',
              onPressed: delta == 0
                  ? null
                  : () => Navigator.pop(context, delta),
            ),
          ],
        ),
      ),
    );
  }
}
