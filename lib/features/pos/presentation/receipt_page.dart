import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../settings/domain/salon.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/invoice_pdf.dart';
import '../domain/ticket.dart';
import 'pos_providers.dart';

/// 6.3 — Facture émise à la validation du ticket.
///
/// Un document, pas un écran de confirmation : en-tête du salon, destinataire,
/// détail des lignes, total, et la mention de règlement avec sa référence.
/// C'est ce que le client emporte ou reçoit.
class ReceiptPage extends ConsumerWidget {
  const ReceiptPage({super.key});

  static const routeName = '/pos/receipt';

  /// Ouvre l'aperçu d'impression du système, imprimante réelle ou « PDF ».
  Future<void> _print(
    BuildContext context,
    WidgetRef ref,
    SalonTransaction transaction,
    Salon? salon,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Printing.layoutPdf(
        name: 'Facture ${transaction.invoiceNumber}',
        onLayout: (_) async => Uint8List.fromList(
          await InvoicePdf.build(transaction: transaction, salon: salon),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Impression impossible : $error')),
      );
    }
  }

  /// Passe le document à la feuille de partage du téléphone.
  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    SalonTransaction transaction,
    Salon? salon,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await InvoicePdf.build(
        transaction: transaction,
        salon: salon,
      );
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        // Nom du fichier reçu par le client : il doit être reconnaissable
        // dans une liste de téléchargements.
        filename: 'facture-${transaction.invoiceNumber}.pdf',
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Partage impossible : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = ref.watch(lastTransactionProvider);
    final salon = ref.watch(currentSalonProvider).valueOrNull;

    if (transaction == null) {
      return const AppScreen(
        title: 'Facture',
        child: AppEmptyState(
          title: 'Aucune facture',
          message: 'Encaissez une prestation pour générer une facture.',
          icon: Icons.receipt_long_outlined,
        ),
      );
    }

    return AppScreen(
      title: 'Facture',
      bodyPadding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
      action: AppIconButton(
        icon: Icons.print_outlined,
        onTap: () => _print(context, ref, transaction, salon),
      ),
      footer: Row(
        children: [
          AppIconButton(
            icon: Icons.file_download_outlined,
            onTap: () => _share(context, ref, transaction, salon),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: 'Envoyer au client',
              icon: Icons.send_rounded,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                // Le document part par le partage du téléphone (WhatsApp,
                // SMS, mail) ; l'appel serveur ne fait que tracer l'envoi.
                await _share(context, ref, transaction, salon);
                await ref
                    .read(posRepositoryProvider)
                    .sendReceipt(transactionId: transaction.id);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Facture transmise.')),
                );
              },
            ),
          ),
        ],
      ),
      child: _InvoiceCard(transaction: transaction, salon: salon),
    );
  }
}

/// La facture : un seul bloc blanc, découpé par des séparateurs.
class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.transaction, required this.salon});

  final SalonTransaction transaction;
  final Salon? salon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(transaction: transaction, salon: salon),
          const Divider(height: 1, color: AppColors.border),
          if (transaction.clientName != null) ...[
            _BilledTo(transaction: transaction),
            const Divider(height: 1, color: AppColors.border),
          ],
          _Lines(lines: transaction.lines),
          const Divider(height: 1, color: AppColors.border),
          _Totals(transaction: transaction),
          _PaymentBadge(transaction: transaction),
        ],
      ),
    );
  }
}

/// Émetteur à gauche, numéro et date à droite.
class _Header extends StatelessWidget {
  const _Header({required this.transaction, required this.salon});

  final SalonTransaction transaction;
  final Salon? salon;

  @override
  Widget build(BuildContext context) {
    // Téléphone et adresse sur une seule ligne, en sautant ce qui manque :
    // un salon sans adresse ne doit pas afficher « · » esseulé.
    final contact = [
      if (salon?.address.isNotEmpty ?? false) salon!.address,
      if (salon?.phone.isNotEmpty ?? false) salon!.phone,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SalonLogo(url: salon?.logoUrl),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Facture',
                    style: AppTypography.manrope(
                      11.5,
                      FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '#${transaction.invoiceNumber}',
                    style: AppTypography.sora(15, FontWeight.w800),
                  ),
                  if (transaction.createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      Formatters.dayMonthYear(transaction.createdAt!),
                      style: AppTypography.manrope(
                        11.5,
                        FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            salon?.name ?? 'Salon',
            style: AppTypography.sora(17, FontWeight.w800, letterSpacing: -0.4),
          ),
          if (contact.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              contact,
              style: AppTypography.manrope(
                12,
                FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Logo du salon en tête de facture.
///
/// Le vrai logo, téléversé depuis « Mon salon », plutôt qu'une icône générique :
/// c'est le document que le client emporte. Repli sur le glyphe de l'app tant
/// qu'aucun logo n'a été déposé, et en cas d'image illisible ou hors ligne.
class _SalonLogo extends StatelessWidget {
  const _SalonLogo({required this.url});

  final String? url;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final hasLogo = url != null && url!.isNotEmpty;

    return Container(
      width: _size,
      height: _size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hasLogo ? AppColors.surfaceSubtle : AppColors.primary,
        borderRadius: BorderRadius.circular(13),
        border: hasLogo ? Border.all(color: AppColors.border) : null,
      ),
      child: hasLogo
          ? Image.network(
              url!,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const AppGlyph(size: 22),
            )
          : const AppGlyph(size: 22, color: Colors.white),
    );
  }
}

/// Destinataire de la facture.
class _BilledTo extends StatelessWidget {
  const _BilledTo({required this.transaction});

  final SalonTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Facturé à',
            style: AppTypography.manrope(
              11.5,
              FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            transaction.clientName!,
            style: AppTypography.sora(15, FontWeight.w700),
          ),
          if (transaction.clientPhone?.isNotEmpty ?? false)
            Text(
              transaction.clientPhone!,
              style: AppTypography.manrope(
                12,
                FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Détail facturé, une ligne par article.
class _Lines extends StatelessWidget {
  const _Lines({required this.lines});

  final List<TicketLine> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lines[i].label,
                        style: AppTypography.sora(14, FontWeight.w700),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        // Marque du produit ou catégorie de la prestation,
                        // suivie de la quantité : « Kérastase · x2 ».
                        [
                          if (lines[i].category?.isNotEmpty ?? false)
                            lines[i].category!,
                          'x${lines[i].quantity}',
                        ].join(' · '),
                        style: AppTypography.manrope(
                          11.5,
                          FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  Formatters.fcfa(lines[i].totalFcfa),
                  style: AppTypography.sora(14.5, FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Sous-total, remise et total dû.
class _Totals extends StatelessWidget {
  const _Totals({required this.transaction});

  final SalonTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = transaction.discountFcfa > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        children: [
          // Sous-total et remise n'apparaissent que s'il y a une remise :
          // sinon ils répéteraient le total.
          if (hasDiscount) ...[
            _TotalRow(
              label: 'Sous-total',
              value: Formatters.fcfa(transaction.subtotalFcfa),
            ),
            const SizedBox(height: 6),
            _TotalRow(
              label: 'Remise',
              value: '− ${Formatters.fcfa(transaction.discountFcfa)}',
              color: AppColors.primary,
            ),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppTypography.sora(16, FontWeight.w800)),
              Text(
                Formatters.fcfa(transaction.totalAmountFcfa),
                style: AppTypography.sora(
                  20,
                  FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.manrope(
            12.5,
            FontWeight.w500,
            color: color ?? AppColors.textBody,
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

/// Mention de règlement : statut, moyen de paiement, référence.
class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.transaction});

  final SalonTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final refunded = transaction.isRefund;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Row(
        children: [
          AppBadge(
            label: refunded
                ? 'Remboursé'
                : 'Payé · ${transaction.paymentMethod.label}',
            color: refunded ? AppColors.expense : AppColors.primary,
            background: refunded ? AppColors.tintExpense : AppColors.tintGreen,
            dense: true,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Réf. ${transaction.reference.replaceFirst('#', '')}',
              style: AppTypography.manrope(
                11.5,
                FontWeight.w500,
                color: AppColors.textFaint,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
