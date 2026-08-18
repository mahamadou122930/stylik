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

  /// Recherche propre à cet écran, volontairement séparée de celle de
  /// l'inventaire : filtrer une liste de réception ne doit pas modifier ce
  /// que le gérant voit ensuite dans son stock.
  String _search = '';

  bool _isSaving = false;

  /// Produits proposés à la saisie, filtrés par la recherche.
  ///
  /// Une ligne déjà saisie reste visible même si elle ne correspond plus au
  /// texte : sinon on la croirait perdue en affinant sa recherche.
  List<Product> _visible(List<Product> products) {
    final query = Formatters.searchable(_search.trim());
    if (query.isEmpty) return products;

    return products.where((product) {
      if ((_quantities[product.id] ?? 0) > 0) return true;

      final haystack = Formatters.searchable(
        [
          product.name,
          product.brand,
          product.category,
          product.supplier ?? '',
        ].join(' '),
      );
      return haystack.contains(query);
    }).toList();
  }

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
      await ref
          .read(inventoryRepositoryProvider)
          .receiveDelivery(
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Réception impossible : $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final items = products.valueOrNull ?? const <Product>[];
    final hasLines = _quantities.values.any((quantity) => quantity > 0);

    final visible = _visible(items);

    return AppScreen(
      title: 'Réception',
      header: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        child: AppSearchField(
          hint: 'Nom, marque, catégorie, fournisseur…',
          onChanged: (value) => setState(() => _search = value),
        ),
      ),
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
                message:
                    'Créez vos produits avant d\'enregistrer une '
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
                  if (visible.isEmpty)
                    AppEmptyState(
                      compact: true,
                      title: 'Aucun produit trouvé',
                      message: 'Aucun produit ne correspond à « $_search ».',
                      icon: Icons.search_off_rounded,
                    ),
                  for (final product in visible) ...[
                    _ReceptionRow(
                      // Clé stable : sans elle, filtrer la liste recomposerait
                      // les lignes et viderait le champ en cours de saisie.
                      key: ValueKey(product.id),
                      product: product,
                      quantity: _quantities[product.id] ?? 0,
                      onChanged: (value) =>
                          setState(() => _quantities[product.id] = value),
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
                          style: AppTypography.manrope(
                            13,
                            FontWeight.w600,
                            color: AppColors.textBody,
                          ),
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

class _ReceptionRow extends StatefulWidget {
  const _ReceptionRow({
    super.key,
    required this.product,
    required this.quantity,
    required this.onChanged,
  });

  final Product product;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  State<_ReceptionRow> createState() => _ReceptionRowState();
}

class _ReceptionRowState extends State<_ReceptionRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.quantity == 0 ? '' : '${widget.quantity}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ReceptionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ne réécrit le champ que si la valeur vient d'ailleurs (les boutons) :
    // le remplacer à chaque frappe déplacerait le curseur.
    final shown = int.tryParse(_controller.text.trim()) ?? 0;
    if (shown != widget.quantity) {
      _controller.text = widget.quantity == 0 ? '' : '${widget.quantity}';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  void _bump(int step) {
    final next = (widget.quantity + step).clamp(0, 1 << 31);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final lineTotal = widget.quantity * widget.product.unitCostFcfa;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.product.name, style: AppTypography.rowTitleStrong),
                const SizedBox(height: 1),
                Text(
                  [
                    if (widget.product.packaging?.isNotEmpty ?? false)
                      widget.product.packaging!,
                    Formatters.fcfa(widget.product.unitCostFcfa),
                    // Total de la ligne dès qu'une quantité est saisie : c'est
                    // ce qu'on rapproche du bon de livraison.
                    if (widget.quantity > 0) '= ${Formatters.fcfa(lineTotal)}',
                  ].join(' · '),
                  style: AppTypography.rowSubtitle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppIconButton(
            icon: Icons.remove_rounded,
            enabled: widget.quantity > 0,
            onTap: () => _bump(-1),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 58,
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: AppTypography.sora(16, FontWeight.w800),
              decoration: const InputDecoration(
                hintText: '0',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value.trim()) ?? 0;
                widget.onChanged(parsed < 0 ? 0 : parsed);
              },
            ),
          ),
          const SizedBox(width: 6),
          AppIconButton(
            icon: Icons.add_rounded,
            filled: true,
            onTap: () => _bump(1),
          ),
        ],
      ),
    );
  }
}
