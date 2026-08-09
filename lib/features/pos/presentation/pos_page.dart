import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/profile.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/domain/salon_service.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../inventory/presentation/product_form_page.dart';
import '../../staff/presentation/staff_providers.dart';
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
    if (selected != null) {
      final currentProfile = ref.read(currentProfileProvider).valueOrNull;
      final stylists = ref.read(stylistsProvider).valueOrNull ?? const [];
      final defaultStylist =
          currentProfile ?? (stylists.isNotEmpty ? stylists.first : null);

      ref.read(ticketProvider.notifier).addService(
            selected,
            stylistId: defaultStylist?.id,
            stylistName: defaultStylist?.fullName,
          );
    }
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
        addNewLabel: '+ Nouveau produit',
        onAddNew: () async {
          final res = await Navigator.of(context)
              .pushNamed(ProductFormPage.routeName);
          if (res == true) {
            ref.invalidate(productsProvider);
          }
        },
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

  Future<void> _changeStylist(BuildContext context, WidgetRef ref) async {
    final stylists = ref.read(stylistsProvider).valueOrNull ?? const [];
    if (stylists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun coiffeur trouvé dans l\'équipe.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Profile>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PickerSheet<Profile>(
        title: 'Attribuer au coiffeur',
        items: stylists,
        labelBuilder: (stylist) => stylist.fullName,
        subtitleBuilder: (stylist) => stylist.role.label,
        priceBuilder: (_) => 0,
        showPrice: false,
      ),
    );

    if (selected != null) {
      ref.read(ticketProvider.notifier).updateLineStylist(
            line.refId,
            stylistId: selected.id,
            stylistName: selected.fullName,
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProfile = ref.watch(currentProfileProvider).valueOrNull;
    final displayName = line.stylistName ??
        currentProfile?.fullName ??
        'Choisir coiffeur';

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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        child: Row(
          children: [
            if (isProduct)
              Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.local_drink_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.quantity > 1
                        ? '${line.label} × ${line.quantity}'
                        : line.label,
                    style: AppTypography.manrope(14.5, FontWeight.w700),
                  ),
                  if (!isProduct) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _changeStylist(context, ref),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(4, 2.5, 8, 2.5),
                        decoration: BoxDecoration(
                          color: AppColors.tintGreenSoft,
                          border: Border.all(color: AppColors.tintGreenBorder),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                Formatters.initials(displayName),
                                style: AppTypography.sora(
                                  9,
                                  FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              displayName,
                              style: AppTypography.manrope(
                                11.5,
                                FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (line.category != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      line.category!,
                      style: AppTypography.manrope(
                        12,
                        FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Formatters.fcfa(line.totalFcfa),
              style: AppTypography.sora(14, FontWeight.w700),
            ),
          ],
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

/// Feuille de sélection d'une prestation, d'un produit ou d'un coiffeur.
class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.labelBuilder,
    required this.subtitleBuilder,
    required this.priceBuilder,
    this.showPrice = true,
    this.onAddNew,
    this.addNewLabel,
  });

  final String title;
  final List<T> items;
  final String Function(T) labelBuilder;
  final String Function(T) subtitleBuilder;
  final int Function(T) priceBuilder;
  final bool showPrice;
  final VoidCallback? onAddNew;
  final String? addNewLabel;

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
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: AppTypography.sora(17, FontWeight.w700),
                  ),
                  if (onAddNew != null)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        onAddNew!();
                      },
                      child: Text(
                        addNewLabel ?? '+ Créer',
                        style: AppTypography.manrope(
                          13,
                          FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: AppEmptyState(
                  compact: true,
                  title: 'Rien à afficher',
                  message: 'Aucun élément disponible.',
                  actionLabel: onAddNew != null ? addNewLabel : null,
                  onAction: onAddNew != null
                      ? () {
                          Navigator.pop(context);
                          onAddNew!();
                        }
                      : null,
                ),
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
                    trailing: showPrice
                        ? Text(
                            Formatters.fcfa(priceBuilder(items[index])),
                            style: AppTypography.sora(14, FontWeight.w700),
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
