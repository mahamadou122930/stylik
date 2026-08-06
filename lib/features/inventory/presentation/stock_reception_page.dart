import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/product.dart';
import 'inventory_providers.dart';

/// 7.3 — Réception de stock : valider une livraison fournisseur.
class StockReceptionPage extends ConsumerStatefulWidget {
  const StockReceptionPage({super.key});

  static const routeName = '/inventory/reception';

  @override
  ConsumerState<StockReceptionPage> createState() => _StockReceptionPageState();
}

class _StockReceptionPageState extends ConsumerState<StockReceptionPage> {
  /// Quantités saisies par produit.
  final Map<String, int> _quantities = {};
  bool _isSaving = false;

  int _totalFcfa(List<Product> products) {
    var total = 0;
    for (final product in products) {
      total += (_quantities[product.id] ?? 0) * product.unitCostFcfa;
    }
    return total;
  }

  Future<void> _validate(List<Product> products) async {
    final lines = Map<String, int>.fromEntries(
      _quantities.entries.where((entry) => entry.value > 0),
    );
    if (lines.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(inventoryRepositoryProvider).receiveDelivery(
            quantitiesByProductId: lines,
            supplierLabel: products
                .firstWhere((product) => product.id == lines.keys.first)
                .supplier,
          );
      ref.invalidate(productsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${lines.length} ligne(s) réceptionnée(s)')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Réception impossible : $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final items = products.valueOrNull ?? const <Product>[];
    final hasLines = _quantities.values.any((quantity) => quantity > 0);

    return AppScreen(
      title: 'Réception',
      footer: AppButton(
        label: 'Valider la réception',
        icon: Icons.check_rounded,
        isLoading: _isSaving,
        onPressed: hasLines ? () => _validate(items) : null,
      ),
      child: products.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(productsProvider),
        ),
        data: (data) => data.isEmpty
            ? const AppEmptyState(
                title: 'Aucun produit',
                message: 'Créez vos produits avant d\'enregistrer une '
                    'livraison.',
                icon: Icons.local_shipping_outlined,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppSectionTitle(
                    'Produits livrés',
                    padding: EdgeInsets.fromLTRB(2, 2, 2, 10),
                  ),
                  for (final product in data) ...[
                    _ReceptionRow(
                      product: product,
                      quantity: _quantities[product.id] ?? 0,
                      onChanged: (value) => setState(
                        () => _quantities[product.id] = value,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 6),
                  AppCard(
                    radius: 14,
                    shadow: false,
                    color: AppColors.tintGreenSoft,
                    borderColor: AppColors.tintGreenBorder,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total livraison',
                          style: AppTypography.manrope(13, FontWeight.w600,
                              color: AppColors.textBody),
                        ),
                        Text(
                          Formatters.fcfa(_totalFcfa(data)),
                          style: AppTypography.sora(
                            16,
                            FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ReceptionRow extends StatelessWidget {
  const _ReceptionRow({
    required this.product,
    required this.quantity,
    required this.onChanged,
  });

  final Product product;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: AppTypography.rowTitleStrong),
                const SizedBox(height: 1),
                Text(
                  [
                    if (product.packaging?.isNotEmpty ?? false)
                      product.packaging!,
                    Formatters.fcfa(product.unitCostFcfa),
                  ].join(' · '),
                  style: AppTypography.rowSubtitle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          AppStepper(
            value: quantity,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
