import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/payment_method.dart';
import '../domain/ticket.dart';
import 'pos_providers.dart';
import 'refund_page.dart';

/// 6.4 — Historique des transactions : journal de caisse du jour.
class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  static const routeName = '/pos/transactions';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(todayTransactionsProvider);
    final total = ref.watch(todayCashTotalProvider);
    final count = transactions.valueOrNull?.length ?? 0;

    return AppScreen(
      title: 'Transactions',
      largeTitle: true,
      action: AppIconButton(
        icon: Icons.filter_list_rounded,
        onTap: () {
          // TODO(pos): filtres (moyen de paiement, caissier, statut).
        },
      ),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: AppGradientCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          bubbleColor: Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total caisse · aujourd\'hui',
                      style: AppTypography.manrope(
                        12,
                        FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.fcfa(total),
                      style: AppTypography.sora(
                        24,
                        FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: AppTypography.sora(
                      15,
                      FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'ventes',
                    style: AppTypography.manrope(
                      11,
                      FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      child: transactions.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(todayTransactionsProvider),
        ),
        data: (items) => items.isEmpty
            ? const AppEmptyState(
                title: 'Aucune transaction',
                message: 'Le journal de caisse du jour est vide.',
                icon: Icons.receipt_long_outlined,
              )
            : AppListCard(
                children: [
                  for (final transaction in items)
                    _TransactionRow(
                      transaction: transaction,
                      onTap: () => Navigator.of(context).pushNamed(
                        RefundPage.routeName,
                        arguments: transaction,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction, this.onTap});

  final SalonTransaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isRefund = transaction.isRefund;
    final method = transaction.paymentMethod;

    final (color, background) = isRefund
        ? (AppColors.dangerDeep, AppColors.tintExpense)
        : method.family == PaymentFamily.card
            ? (AppColors.blue, AppColors.tintBlue)
            : (AppColors.primary, AppColors.tintGreen);

    final subtitle = [
      if (transaction.createdAt != null)
        Formatters.time(transaction.createdAt!),
      isRefund ? 'Remboursement' : method.label,
    ].join(' · ');

    return AppListRow(
      label: transaction.clientName ?? 'Client de passage',
      subtitle: subtitle,
      strong: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12),
      leading: AppIconTile(
        icon: isRefund ? Icons.remove_rounded : method.icon,
        color: color,
        background: background,
        size: 36,
        radius: 11,
      ),
      trailing: Text(
        '${isRefund ? '− ' : '+'}${Formatters.fcfa(transaction.totalAmountFcfa)}',
        style: AppTypography.sora(
          14,
          FontWeight.w700,
          color: isRefund ? AppColors.dangerDeep : AppColors.primary,
        ),
      ),
    );
  }
}
