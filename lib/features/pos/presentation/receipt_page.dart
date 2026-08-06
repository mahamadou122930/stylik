import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../settings/presentation/settings_providers.dart';
import '../domain/ticket.dart';
import 'pos_providers.dart';

/// 6.3 — Ticket / facture : reçu affiché après encaissement.
class ReceiptPage extends ConsumerWidget {
  const ReceiptPage({super.key});

  static const routeName = '/pos/receipt';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = ref.watch(lastTransactionProvider);
    final salon = ref.watch(currentSalonProvider).valueOrNull;

    if (transaction == null) {
      return const AppScreen(
        title: 'Ticket',
        child: AppEmptyState(
          title: 'Aucun ticket',
          message: 'Encaissez une prestation pour générer un reçu.',
          icon: Icons.receipt_long_outlined,
        ),
      );
    }

    return AppScreen(
      title: '',
      showBack: false,
      bodyPadding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
      footer: Row(
        children: [
          Expanded(
            child: AppButton.outline(
              label: 'Imprimer',
              icon: Icons.print_outlined,
              onPressed: () {
                // TODO(pos): impression sur imprimante thermique.
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: 'Envoyer',
              icon: Icons.ios_share_rounded,
              onPressed: () async {
                await ref
                    .read(posRepositoryProvider)
                    .sendReceipt(transactionId: transaction.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reçu envoyé au client')),
                );
              },
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 18),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.tintGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 34,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Paiement encaissé',
                  style: AppTypography.sora(
                    22,
                    FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  transaction.paymentMethod.fullLabel,
                  style: AppTypography.manrope(
                    13,
                    FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AppCard(
            radius: 18,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            salon?.name ?? 'Salon',
                            style: AppTypography.sora(16, FontWeight.w800),
                          ),
                          if (salon?.address.isNotEmpty ?? false)
                            Text(
                              salon!.address,
                              style: AppTypography.rowSubtitle,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          transaction.reference,
                          style: AppTypography.sora(12, FontWeight.w700),
                        ),
                        if (transaction.createdAt != null)
                          Text(
                            '${Formatters.dayMonth(transaction.createdAt!)} · '
                            '${Formatters.time(transaction.createdAt!)}',
                            style: AppTypography.manrope(
                              11,
                              FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const DashedDivider(),
                const SizedBox(height: 14),
                for (final line in transaction.lines) ...[
                  _ReceiptLine(
                    label: line.quantity > 1
                        ? '${line.label} × ${line.quantity}'
                        : line.label,
                    value: Formatters.fcfa(line.totalFcfa),
                  ),
                  const SizedBox(height: 9),
                ],
                if (transaction.discountFcfa > 0)
                  _ReceiptLine(
                    label: 'Remise',
                    value: '− ${Formatters.fcfa(transaction.discountFcfa)}',
                    highlighted: true,
                  ),
                const SizedBox(height: 5),
                const DashedDivider(),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total payé',
                      style: AppTypography.sora(16, FontWeight.w700),
                    ),
                    Text(
                      Formatters.fcfa(transaction.totalAmountFcfa),
                      style: AppTypography.sora(
                        20,
                        FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Nouvelle vente',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: AppTypography.manrope(
              13,
              FontWeight.w500,
              color: color ?? AppColors.textBody,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          value,
          style: AppTypography.sora(
            13,
            FontWeight.w600,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Type de ligne du reçu, réutilisé par l'écran de remboursement.
typedef ReceiptLines = List<TicketLine>;
