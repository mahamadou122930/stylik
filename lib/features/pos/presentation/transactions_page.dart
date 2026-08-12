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
class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  static const routeName = '/pos/transactions';

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  TransactionStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final transactionsState = ref.watch(todayTransactionsProvider);
    final total = ref.watch(todayCashTotalProvider);

    final allItems = transactionsState.valueOrNull ?? <SalonTransaction>[];
    final items = _statusFilter == null
        ? allItems
        : allItems.where((t) => t.status == _statusFilter).toList();
    final count = items.length;

    return AppScreen(
      title: 'Transactions',
      largeTitle: true,
      header: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: _statusFilter == null,
                  onSelected: (sel) {
                    if (sel) setState(() => _statusFilter = null);
                  },
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _statusFilter == null ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Payé'),
                  selected: _statusFilter == TransactionStatus.paid,
                  onSelected: (sel) {
                    setState(() => _statusFilter = sel ? TransactionStatus.paid : null);
                  },
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _statusFilter == TransactionStatus.paid ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Remboursé'),
                  selected: _statusFilter == TransactionStatus.refunded,
                  onSelected: (sel) {
                    setState(() => _statusFilter = sel ? TransactionStatus.refunded : null);
                  },
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _statusFilter == TransactionStatus.refunded ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Annulé'),
                  selected: _statusFilter == TransactionStatus.cancelled,
                  onSelected: (sel) {
                    setState(() => _statusFilter = sel ? TransactionStatus.cancelled : null);
                  },
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _statusFilter == TransactionStatus.cancelled ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
      child: transactionsState.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(todayTransactionsProvider),
        ),
        data: (_) => items.isEmpty
            ? const AppEmptyState(
                title: 'Aucune transaction',
                message: 'Aucune transaction ne correspond à ce filtre.',
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
