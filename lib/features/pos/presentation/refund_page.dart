import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/ticket.dart';
import 'pos_providers.dart';

/// 6.5 — Remboursement / annulation : total ou partiel, avec motif.
class RefundPage extends ConsumerStatefulWidget {
  const RefundPage({super.key, required this.transaction});

  static const routeName = '/pos/refund';

  final SalonTransaction transaction;

  @override
  ConsumerState<RefundPage> createState() => _RefundPageState();
}

class _RefundPageState extends ConsumerState<RefundPage> {
  bool _isPartial = false;
  RefundReason _reason = RefundReason.unsatisfied;
  late int _amountFcfa = widget.transaction.totalAmountFcfa;
  bool _isProcessing = false;

  Future<void> _confirm() async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(posRepositoryProvider).refund(
            transactionId: widget.transaction.id,
            amountFcfa: _amountFcfa,
            reason: _reason,
          );
      ref.invalidate(todayTransactionsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Remboursement de ${Formatters.fcfa(_amountFcfa)} '
              'enregistré'),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Remboursement impossible : $error')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;

    return AppScreen(
      title: 'Remboursement',
      footer: AppButton(
        label: 'Confirmer le remboursement',
        variant: AppButtonVariant.dangerSolid,
        trailingLabel: Formatters.fcfa(_amountFcfa),
        isLoading: _isProcessing,
        onPressed: _amountFcfa <= 0 ? null : _confirm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                AppAvatar(
                  initials:
                      Formatters.initials(transaction.clientName ?? 'Client'),
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
                        transaction.clientName ?? 'Client de passage',
                        style: AppTypography.rowTitleStrong,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Ticket ${transaction.reference}'
                        '${transaction.createdAt == null ? '' : ' · ${Formatters.time(transaction.createdAt!)}'}',
                        style: AppTypography.rowSubtitle,
                      ),
                    ],
                  ),
                ),
                Text(
                  Formatters.fcfa(transaction.totalAmountFcfa),
                  style: AppTypography.sora(14, FontWeight.w700),
                ),
              ],
            ),
          ),
          const AppSectionTitle('Type'),
          AppSegmented(
            padding: const EdgeInsets.only(bottom: 18),
            items: const ['Remboursement total', 'Partiel'],
            selectedIndex: _isPartial ? 1 : 0,
            onChanged: (index) => setState(() {
              _isPartial = index == 1;
              if (!_isPartial) _amountFcfa = transaction.totalAmountFcfa;
            }),
          ),
          if (_isPartial) ...[
            AppInput.amount(
              label: 'Montant à rembourser',
              initialValue: '$_amountFcfa',
              onChanged: (value) => setState(
                () => _amountFcfa = (int.tryParse(value) ?? 0)
                    .clamp(0, transaction.totalAmountFcfa),
              ),
            ),
            const SizedBox(height: 18),
          ],
          const AppSectionTitle(
            'Motif',
            padding: EdgeInsets.fromLTRB(2, 0, 2, 10),
          ),
          for (final reason in RefundReason.values) ...[
            _ReasonOption(
              reason: reason,
              selected: _reason == reason,
              onTap: () => setState(() => _reason = reason),
            ),
            const SizedBox(height: 9),
          ],
          const SizedBox(height: 7),
          AppCallout(
            icon: Icons.info_outline_rounded,
            color: AppColors.dangerDeep,
            background: AppColors.tintExpense,
            borderColor: AppColors.dangerBorder,
            message: 'Le remboursement sera renvoyé vers le moyen de paiement '
                'd\'origine (${transaction.paymentMethod.label}).',
          ),
        ],
      ),
    );
  }
}

class _ReasonOption extends StatelessWidget {
  const _ReasonOption({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final RefundReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      radius: 14,
      shadow: false,
      color: selected ? AppColors.tintGreenSoft : AppColors.surface,
      borderColor: selected ? AppColors.accent : AppColors.border,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.accent : Colors.transparent,
              border: selected
                  ? null
                  : Border.all(color: AppColors.borderStrong, width: 2),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              reason.label,
              style: AppTypography.manrope(
                14,
                FontWeight.w600,
                color: selected ? AppColors.textPrimary : AppColors.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
