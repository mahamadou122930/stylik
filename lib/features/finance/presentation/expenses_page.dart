import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/finance_summary.dart';
import 'expense_form_page.dart';
import 'finance_providers.dart';
import 'net_result_page.dart';

/// 8.4 — Dépenses / charges : sorties du salon et résultat net.
class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});

  static const routeName = '/finance/expenses';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider);
    final total = ref.watch(expensesTotalProvider);
    final net = ref.watch(netResultProvider);

    return AppScreen(
      title: 'Dépenses',
      action: AppIconButton(
        icon: Icons.add_rounded,
        filled: true,
        onTap: () => Navigator.of(context).pushNamed(ExpenseFormPage.routeName),
      ),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Row(
          children: [
            Expanded(
              child: AppStatTile(
                label: 'Charges de la période',
                value: Formatters.fcfa(total),
                valueColor: AppColors.expense,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppStatTile(
                label: 'Résultat net',
                value: Formatters.fcfa(net),
                tinted: true,
                valueColor: net < 0 ? AppColors.expense : AppColors.primary,
                // Le détail — CA, commissions, charges — et les quatre
                // échelles de temps sont sur l'écran dédié.
                onTap: () =>
                    Navigator.of(context).pushNamed(NetResultPage.routeName),
              ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionTitle(
            'Charges récentes',
            padding: EdgeInsets.fromLTRB(2, 2, 2, 10),
          ),
          expenses.when(
            loading: () => const AppLoader(compact: true),
            error: (error, _) => AppErrorState(
              message: '$error',
              onRetry: () => ref.invalidate(expensesProvider),
            ),
            data: (items) => items.isEmpty
                ? const AppEmptyState(
                    title: 'Aucune charge',
                    message:
                        'Enregistrez loyer, réappro. et salaires pour '
                        'suivre le résultat net.',
                    icon: Icons.receipt_long_outlined,
                  )
                : AppListCard(
                    children: [
                      for (final expense in items)
                        _ExpenseRow(expense: expense),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = switch (expense.category) {
      ExpenseCategory.rent => (
        Icons.home_work_rounded,
        AppColors.blue,
        AppColors.tintBlue,
      ),
      ExpenseCategory.supplies => (
        Icons.inventory_2_rounded,
        AppColors.amber,
        AppColors.tintAmber,
      ),
      ExpenseCategory.utilities => (
        Icons.bolt_rounded,
        AppColors.violet,
        AppColors.tintViolet,
      ),
      ExpenseCategory.payroll => (
        Icons.person_rounded,
        AppColors.primary,
        AppColors.tintGreen,
      ),
      ExpenseCategory.marketing => (
        Icons.campaign_rounded,
        AppColors.violet,
        AppColors.tintViolet,
      ),
      ExpenseCategory.other => (
        Icons.more_horiz_rounded,
        AppColors.textBody,
        AppColors.surfaceMuted,
      ),
    };

    final subtitle = [
      Formatters.dayMonth(expense.spentAt),
      if (expense.supplier?.isNotEmpty ?? false)
        expense.supplier!
      else if (expense.isRecurring)
        'mensuel',
    ].join(' · ');

    return AppListRow(
      label: expense.label,
      subtitle: subtitle,
      strong: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      leading: AppIconTile(
        icon: icon,
        color: color,
        background: background,
        size: 36,
        radius: 11,
      ),
      trailing: Text(
        '− ${Formatters.fcfa(expense.amountFcfa)}',
        style: AppTypography.sora(
          14,
          FontWeight.w700,
          color: AppColors.expense,
        ),
      ),
    );
  }
}
