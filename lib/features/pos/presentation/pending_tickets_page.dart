import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/ticket.dart';
import 'payment_page.dart';
import 'pos_providers.dart';

/// Tickets en attente de règlement — les ardoises ouvertes.
///
/// La prestation est faite, l'argent pas encore là. Tant qu'un ticket est ici
/// il ne compte ni dans l'encaissé, ni dans les commissions, ni dans le stock
/// sorti : seul le règlement déclenche tout cela.
class PendingTicketsPage extends ConsumerWidget {
  const PendingTicketsPage({super.key});

  static const routeName = '/pos/pending';

  Future<void> _settle(
    BuildContext context,
    WidgetRef ref,
    SalonTransaction ticket,
  ) async {
    ref.read(resumeTicketControllerProvider)(ticket);
    await Navigator.of(context).pushNamed(PaymentPage.routeName);
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    SalonTransaction ticket,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Abandonner ce ticket ?',
          style: AppTypography.sora(17, FontWeight.w700),
        ),
        content: Text(
          'Le ticket de ${Formatters.fcfa(ticket.totalAmountFcfa)} passera en '
          'annulé. Il ne comptera plus nulle part, mais restera dans le '
          'journal pour expliquer un écart.',
          style: AppTypography.manrope(
            13,
            FontWeight.w500,
            color: AppColors.textBody,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Garder'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Abandonner',
              style: AppTypography.manrope(
                14,
                FontWeight.w700,
                color: AppColors.expense,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(cancelPendingControllerProvider)(ticket);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ticket abandonné.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Abandon impossible : $error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingTicketsProvider);
    final tickets = pending.valueOrNull ?? const <SalonTransaction>[];

    return AppScreen(
      title: 'Tickets en attente',
      action: tickets.isEmpty ? null : _CountBadge(count: tickets.length),
      child: pending.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(pendingTicketsProvider),
        ),
        data: (tickets) {
          if (tickets.isEmpty) {
            return const AppEmptyState(
              title: 'Aucun ticket en attente',
              message:
                  'Les tickets mis de côté en caisse apparaissent ici, '
                  'jusqu\'à leur règlement.',
              icon: Icons.hourglass_empty_rounded,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final ticket in tickets) ...[
                _PendingCard(
                  ticket: ticket,
                  onSettle: () => _settle(context, ref, ticket),
                  onCancel: () => _cancel(context, ref, ticket),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Nombre d'ardoises ouvertes, à droite du titre.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: AppColors.tintAmber,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: AppTypography.sora(
          13,
          FontWeight.w800,
          color: AppColors.amberDeep,
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.ticket,
    required this.onSettle,
    required this.onCancel,
  });

  final SalonTransaction ticket;
  final VoidCallback onSettle;
  final VoidCallback onCancel;

  bool get _hasFiche =>
      ticket.clientName != null &&
      ticket.clientName!.trim().isNotEmpty &&
      ticket.clientName != 'Client de passage';

  String get _name => _hasFiche ? ticket.clientName! : 'Client de passage';

  /// Contenu du ticket. « Prestations » tant qu'il n'y a que des services :
  /// un shampooing vendu n'est pas une prestation.
  String get _contentLabel {
    final count = ticket.lines.length;
    final onlyServices = ticket.lines.every((line) => !line.isProduct);

    if (count == 0) return 'Ticket vide';
    if (onlyServices) return '$count prestation${count > 1 ? 's' : ''}';
    return '$count article${count > 1 ? 's' : ''}';
  }

  /// Depuis combien de temps l'ardoise est ouverte.
  ///
  /// En minutes tant que c'est frais : c'est l'unité utile quand la cliente
  /// est encore dans le salon. Au-delà, l'heure puis le jour, sinon « en
  /// attente 4 320 min » ne dirait plus rien.
  String get _waitLabel {
    final createdAt = ticket.createdAt?.toLocal();
    if (createdAt == null) return 'en attente';

    final elapsed = DateTime.now().difference(createdAt);
    if (elapsed.inMinutes < 1) return 'à l\'instant';
    if (elapsed.inMinutes < 60) return 'en attente ${elapsed.inMinutes} min';
    if (elapsed.inHours < 24) return 'en attente ${elapsed.inHours} h';

    final days = elapsed.inDays;
    return 'en attente $days jour${days > 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(name: _name, hasFiche: _hasFiche),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.rowTitleStrong,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_contentLabel · $_waitLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.manrope(
                        11.5,
                        FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.fcfa(ticket.totalAmountFcfa),
                style: AppTypography.sora(15, FontWeight.w800),
              ),
              // L'abandon reste en retrait : c'est le règlement qu'on vient
              // chercher ici. Mais sans lui, un ticket que la cliente ne
              // paiera jamais resterait dans la liste indéfiniment.
              AppIconButton(icon: Icons.more_horiz_rounded, onTap: onCancel),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Rappeler & encaisser',
            icon: Icons.refresh_rounded,
            height: 48,
            onPressed: onSettle,
          ),
        ],
      ),
    );
  }
}

/// Pastille d'initiales, ou silhouette pour une cliente sans fiche.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.hasFiche});

  final String name;
  final bool hasFiche;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: hasFiche ? AppColors.primary : AppColors.surfaceSubtle,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: hasFiche
          ? Text(
              Formatters.initials(name),
              style: AppTypography.sora(
                13,
                FontWeight.w700,
                color: Colors.white,
              ),
            )
          : const Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
    );
  }
}
