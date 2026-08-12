import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/profile.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../clients/domain/client.dart';
import '../../clients/presentation/clients_providers.dart';
import '../../loyalty/domain/loyalty_campaign.dart';
import '../../staff/presentation/staff_providers.dart';
import '../domain/ticket.dart';
import 'payment_page.dart';
import 'pos_add_to_ticket_page.dart';
import 'pos_providers.dart';
import 'transactions_page.dart';

/// 6.1 — Caisse : prestations, produits vendus et total en direct.
class PosPage extends ConsumerWidget {
  const PosPage({super.key});

  static const routeName = '/pos';

  Future<void> _pickClient(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<Client?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ClientPickerSheet(),
    );

    if (selected != null) {
      if (selected.id.isEmpty) {
        ref.read(ticketProvider.notifier).attachClient(
              clientId: '',
              clientName: 'Client de passage',
            );
      } else {
        final tier = LoyaltyTier.forPoints(selected.loyaltyPoints);
        ref.read(ticketProvider.notifier).attachClient(
              clientId: selected.id,
              clientName: selected.fullName,
              timeLabel: '${selected.loyaltyPoints} pts · Palier ${tier.label}',
            );
      }
    }
  }

  void _showAddPickerSheet(BuildContext context, WidgetRef ref) {
    Navigator.of(context).pushNamed(PosAddToTicketPage.routeName);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticket = ref.watch(ticketProvider);
    final clientName = ticket.clientName ?? 'Client de passage';
    final hasClientFiche = ticket.clientName != null && ticket.clientName!.isNotEmpty && ticket.clientName != 'Client de passage';

    return AppScreen(
      title: 'Encaissement',
      showBack: false,
      action: AppIconButton(
        icon: Icons.receipt_long_rounded,
        onTap: () =>
            Navigator.of(context).pushNamed(TransactionsPage.routeName),
      ),
      footer: AppButton(
        label: 'Valider le paiement',
        trailingLabel: Formatters.fcfa(ticket.totalFcfa),
        height: 56,
        onPressed: ticket.isEmpty
            ? null
            : () => Navigator.of(context).pushNamed(PaymentPage.routeName),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Carte Client (Design Prototype)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    hasClientFiche ? Formatters.initials(clientName) : '?',
                    style: AppTypography.sora(
                      16,
                      FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: AppTypography.manrope(14.5, FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasClientFiche
                            ? (ticket.timeLabel ?? 'Fiche client rattachée')
                            : 'Sans fiche · sans points',
                        style: AppTypography.manrope(
                          12,
                          FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _pickClient(context, ref),
                  child: Text(
                    'Changer',
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
          const SizedBox(height: 16),

          // 2. En-tête de section "Ticket" avec Badge d'articles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ticket',
                style: AppTypography.sora(18, FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${ticket.lines.length} ${ticket.lines.length > 1 ? 'articles' : 'article'}',
                  style: AppTypography.manrope(
                    12,
                    FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3. Carte regroupant la liste des articles du ticket
          if (ticket.isEmpty)
            AppEmptyState(
              title: 'Ticket vide',
              message: 'Ajoutez les prestations réalisées puis encaissez.',
              icon: Icons.point_of_sale_rounded,
              actionLabel: 'Ajouter au ticket',
              onAction: () => _showAddPickerSheet(context, ref),
            )
          else ...[
            AppCard(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ticket.lines.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, index) {
                  return _TicketLineRow(line: ticket.lines[index]);
                },
              ),
            ),
            const SizedBox(height: 14),

            // 4. Bouton d'action en pointillés
            _DashedAction(
              label: 'Ajouter une prestation ou un produit',
              onTap: () => _showAddPickerSheet(context, ref),
            ),
            const SizedBox(height: 16),

            // 5. Total et Remise
            AppCard(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  _TotalRow(
                    label: 'Sous-total',
                    value: Formatters.fcfa(ticket.subtotalFcfa),
                  ),
                  if (ticket.discountFcfa > 0) ...[
                    const Divider(height: 1, color: AppColors.border),
                    _TotalRow(
                      label: ticket.discountLabel ?? 'Remise fidélité (5 %)',
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
  const _TicketLineRow({required this.line});

  final TicketLine line;

  Future<void> _changeStylist(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<Profile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _StylistPickerSheet(),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.quantity > 1
                      ? '${line.label} × ${line.quantity}'
                      : line.label,
                  style: AppTypography.sora(15, FontWeight.w600),
                ),
                const SizedBox(height: 6),
                if (!line.isProduct)
                  GestureDetector(
                    onTap: () => _changeStylist(context, ref),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF8F1),
                        border: Border.all(color: AppColors.tintGreenBorder),
                        borderRadius: BorderRadius.circular(16),
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
                              12,
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
                  )
                else if (line.category != null)
                  Text(
                    line.category!,
                    style: AppTypography.manrope(
                      12,
                      FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Formatters.fcfa(line.totalFcfa),
            style: AppTypography.sora(15, FontWeight.w700),
          ),
          const SizedBox(width: 10),
          // Bouton Supprimer carré rouge du prototype
          GestureDetector(
            onTap: () =>
                ref.read(ticketProvider.notifier).removeLine(line.refId),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
        ],
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
              FontWeight.w700,
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
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
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

/// Sheet interactive de sélection et recherche d'un client.
class _ClientPickerSheet extends ConsumerStatefulWidget {
  const _ClientPickerSheet();

  @override
  ConsumerState<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends ConsumerState<_ClientPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsListProvider);

    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.78,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Sélectionner le client',
              style: AppTypography.sora(18, FontWeight.w700),
            ),
            const SizedBox(height: 12),
            AppInput(
              controller: _searchController,
              hint: 'Rechercher un client (nom, téléphone)...',
              prefixIcon: Icons.search_rounded,
              suffix: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const AppIconTile(
                icon: Icons.person_outline_rounded,
                color: AppColors.textSecondary,
                background: AppColors.surfaceSubtle,
              ),
              title: Text(
                'Client de passage',
                style: AppTypography.sora(15, FontWeight.w600),
              ),
              subtitle: Text(
                'Sans fiche · sans points',
                style: AppTypography.manrope(12, FontWeight.w500),
              ),
              onTap: () => Navigator.pop(
                context,
                const Client(id: '', salonId: '', fullName: 'Client de passage', phone: ''),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: clientsAsync.when(
                loading: () => const AppLoader(compact: true),
                error: (err, _) => AppErrorState(message: '$err', compact: true),
                data: (clients) {
                  final filtered = clients.where((c) {
                    if (_query.isEmpty) return true;
                    return c.fullName.toLowerCase().contains(_query) ||
                        c.phone.contains(_query);
                  }).toList();

                  if (filtered.isEmpty) {
                    return AppEmptyState(
                      compact: true,
                      title: 'Aucun client trouvé',
                      message: _query.isNotEmpty
                          ? 'Aucun résultat pour "$_query".'
                          : 'Aucun client enregistré.',
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      final tier = LoyaltyTier.forPoints(c.loyaltyPoints);
                      final tierColor = switch (tier) {
                        LoyaltyTier.bronze => const Color(0xFF64748B),
                        LoyaltyTier.silver => const Color(0xFF0284C7),
                        LoyaltyTier.gold => const Color(0xFFD97706),
                        LoyaltyTier.platinum => const Color(0xFF7C3AED),
                      };
                      final tierBg = switch (tier) {
                        LoyaltyTier.bronze => const Color(0xFFF1F5F9),
                        LoyaltyTier.silver => const Color(0xFFE0F2FE),
                        LoyaltyTier.gold => const Color(0xFFFEF3C7),
                        LoyaltyTier.platinum => const Color(0xFFF3E8FF),
                      };

                      return ListTile(
                        leading: AppAvatar(
                          initials: Formatters.initials(c.fullName),
                          size: 38,
                          background: AppColors.primary,
                          color: Colors.white,
                        ),
                        title: Text(c.fullName, style: AppTypography.sora(14.5, FontWeight.w600)),
                        subtitle: Text(
                          '${c.phone.isNotEmpty ? c.phone : "Sans téléphone"} · ${c.loyaltyPoints} pts · ${c.visitCount} visite${c.visitCount > 1 ? 's' : ''}',
                          style: AppTypography.manrope(12, FontWeight.w500, color: AppColors.textSecondary),
                        ),
                        trailing: AppBadge(
                          label: tier.label,
                          color: tierColor,
                          background: tierBg,
                        ),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet interactive de sélection et recherche d'un coiffeur / membre d'équipe.
class _StylistPickerSheet extends ConsumerStatefulWidget {
  const _StylistPickerSheet();

  @override
  ConsumerState<_StylistPickerSheet> createState() => _StylistPickerSheetState();
}

class _StylistPickerSheetState extends ConsumerState<_StylistPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stylistsAsync = ref.watch(stylistsProvider);

    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Attribuer au coiffeur',
              style: AppTypography.sora(18, FontWeight.w700),
            ),
            const SizedBox(height: 12),
            AppInput(
              controller: _searchController,
              hint: 'Rechercher un coiffeur (nom, rôle)...',
              prefixIcon: Icons.search_rounded,
              suffix: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: stylistsAsync.when(
                loading: () => const AppLoader(compact: true),
                error: (err, _) => AppErrorState(message: '$err', compact: true),
                data: (stylists) {
                  final filtered = stylists.where((s) {
                    if (_query.isEmpty) return true;
                    return s.fullName.toLowerCase().contains(_query) ||
                        s.role.label.toLowerCase().contains(_query);
                  }).toList();

                  if (filtered.isEmpty) {
                    return AppEmptyState(
                      compact: true,
                      title: 'Aucun coiffeur trouvé',
                      message: _query.isNotEmpty
                          ? 'Aucun résultat pour "$_query".'
                          : 'Aucun coiffeur trouvé.',
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final stylist = filtered[index];
                      return ListTile(
                        leading: AppAvatar(
                          initials: Formatters.initials(stylist.fullName),
                          size: 40,
                          background: AppColors.primary,
                          color: Colors.white,
                        ),
                        title: Text(stylist.fullName, style: AppTypography.sora(14.5, FontWeight.w600)),
                        subtitle: Text(stylist.role.label, style: AppTypography.manrope(12, FontWeight.w500)),
                        onTap: () => Navigator.pop(context, stylist),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


