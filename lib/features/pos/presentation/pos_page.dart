import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../catalog/domain/salon_service.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../domain/ticket.dart';
import 'payment_page.dart';
import 'pos_providers.dart';
import 'transactions_page.dart';

/// 6.1 — Caisse : prestations, produits vendus et total en direct.
class PosPage extends ConsumerWidget {
  const PosPage({super.key});

  static const routeName = '/pos';

  Future<void> _pickService(BuildContext context, WidgetRef ref) async {
    final services = ref.read(servicesProvider).valueOrNull ?? const [];
    final selected = await showModalBottomSheet<SalonService>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PickerSheet<SalonService>(
        title: 'Ajouter une prestation',
        items: services,
        labelBuilder: (service) => service.name,
        subtitleBuilder: (service) => service.category,
        priceBuilder: (service) => service.priceFcfa,
      ),
    );
    if (selected != null) ref.read(ticketProvider.notifier).addService(selected);
  }

  Future<void> _pickProduct(BuildContext context, WidgetRef ref) async {
    final products = ref.read(productsProvider).valueOrNull ?? const [];
    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PickerSheet<Product>(
        title: 'Ajouter un produit',
        items: products.where((product) => !product.isOutOfStock).toList(),
        labelBuilder: (product) => product.name,
        subtitleBuilder: (product) => product.brand,
        priceBuilder: (product) => product.unitSalePriceFcfa,
      ),
    );
    if (selected != null) ref.read(ticketProvider.notifier).addProduct(selected);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticket = ref.watch(ticketProvider);

    return AppScreen(
      title: 'Encaissement',
      showBack: false,
      action: AppIconButton(
        icon: Icons.receipt_long_rounded,
        onTap: () =>
            Navigator.of(context).pushNamed(TransactionsPage.routeName),
      ),
      footer: AppButton(
        label: 'Choisir le paiement',
        trailingLabel: Formatters.fcfa(ticket.totalFcfa),
        height: 56,
        onPressed: ticket.isEmpty
            ? null
            : () => Navigator.of(context).pushNamed(PaymentPage.routeName),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ticket.clientName != null)
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AppAvatar(
                    initials: Formatters.initials(ticket.clientName!),
                    size: 40,
                    background: AppColors.primary,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.clientName!,
                          style: AppTypography.manrope(14.5, FontWeight.w700),
                        ),
                        if (ticket.stylistName != null)
                          Text(
                            'Coiffeur · ${ticket.stylistName}',
                            style: AppTypography.manrope(
                              12,
                              FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (ticket.timeLabel != null)
                    AppBadge(
                      label: ticket.timeLabel!,
                      color: AppColors.primary,
                      background: AppColors.tintGreen,
                      dense: true,
                    ),
                ],
              ),
            ),
          if (ticket.isEmpty)
            AppEmptyState(
              title: 'Ticket vide',
              message: 'Ajoutez les prestations réalisées puis encaissez.',
              icon: Icons.point_of_sale_rounded,
              actionLabel: 'Ajouter une prestation',
              onAction: () => _pickService(context, ref),
            )
          else ...[
            const AppSectionTitle('Prestations'),
            if (ticket.serviceLines.isEmpty)
              _DashedAction(
                label: 'Ajouter une prestation',
                onTap: () => _pickService(context, ref),
              )
            else
              AppListCard(
                children: [
                  for (final line in ticket.serviceLines)
                    _TicketLineRow(line: line),
                ],
              ),
            const AppSectionTitle(
              'Produits vendus',
              padding: EdgeInsets.fromLTRB(2, 16, 2, 10),
            ),
            if (ticket.productLines.isNotEmpty) ...[
              AppListCard(
                children: [
                  for (final line in ticket.productLines)
                    _TicketLineRow(line: line, isProduct: true),
                ],
              ),
              const SizedBox(height: 10),
            ],
            _DashedAction(
              label: 'Ajouter un produit',
              onTap: () => _pickProduct(context, ref),
            ),
            const SizedBox(height: 16),
            AppCard(
              radius: 18,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Column(
                children: [
                  _TotalRow(
                    label: 'Sous-total',
                    value: Formatters.fcfa(ticket.subtotalFcfa),
                  ),
                  if (ticket.discountFcfa > 0) ...[
                    const Divider(height: 1, color: AppColors.border),
                    _TotalRow(
                      label: ticket.discountLabel ?? 'Remise',
                      value: '− ${Formatters.fcfa(ticket.discountFcfa)}',
                      highlighted: true,
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

class _TicketLineRow extends ConsumerWidget {
  const _TicketLineRow({required this.line, this.isProduct = false});

  final TicketLine line;
  final bool isProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(line.refId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 4),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.expense, size: 20),
      ),
      onDismissed: (_) =>
          ref.read(ticketProvider.notifier).removeLine(line.refId),
      child: AppListRow(
        label: line.quantity > 1
            ? '${line.label} × ${line.quantity}'
            : line.label,
        subtitle: line.category,
        strong: true,
        padding: const EdgeInsets.symmetric(vertical: 12),
        leading: isProduct
            ? Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_drink_outlined,
                  size: 17,
                  color: AppColors.primary,
                ),
              )
            : null,
        trailing: Text(
          Formatters.fcfa(line.totalFcfa),
          style: AppTypography.sora(14, FontWeight.w700),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppColors.primary : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.manrope(
              14,
              FontWeight.w500,
              color: color ?? AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTypography.sora(
              14,
              FontWeight.w600,
              color: color ?? AppColors.textBody,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton en pointillés « Ajouter un produit / une prestation ».
class _DashedAction extends StatelessWidget {
  const _DashedAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: const DashedBorderPainter(radius: 14),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 17, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.sora(
                  14,
                  FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Feuille de sélection d'une prestation ou d'un produit.
class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.labelBuilder,
    required this.subtitleBuilder,
    required this.priceBuilder,
  });

  final String title;
  final List<T> items;
  final String Function(T) labelBuilder;
  final String Function(T) subtitleBuilder;
  final int Function(T) priceBuilder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Text(
                title,
                style: AppTypography.sora(17, FontWeight.w700),
              ),
            ),
            if (items.isEmpty)
              const AppEmptyState(
                compact: true,
                title: 'Rien à ajouter',
                message: 'Le catalogue est vide pour le moment.',
              )
            else
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) => AppListRow(
                    label: labelBuilder(items[index]),
                    subtitle: subtitleBuilder(items[index]),
                    strong: true,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    onTap: () => Navigator.pop(context, items[index]),
                    trailing: Text(
                      Formatters.fcfa(priceBuilder(items[index])),
                      style: AppTypography.sora(14, FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
