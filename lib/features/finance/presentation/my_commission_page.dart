import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/payout.dart';
import 'finance_providers.dart';

/// C2 — Mes commissions : ce qui est acquis, ce qui a été versé, ce qui reste.
///
/// Pendant de `StylistReportPage`, qui montre toute l'équipe et reste réservé
/// au gérant. Ici chacun ne voit que sa propre rémunération, restriction posée
/// aussi en base : `stylist_commissions` ne renvoie que la ligne de l'appelant
/// sans droit sur la finance, et `payout_requests` est filtrée par RLS.
class MyCommissionPage extends ConsumerWidget {
  const MyCommissionPage({super.key});

  static const routeName = '/finance/my-commission';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commission = ref.watch(myMonthCommissionProvider);
    final payouts = ref.watch(myPayoutsProvider);
    final balance = ref.watch(payoutBalanceProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    final requests = payouts.valueOrNull ?? const <PayoutRequest>[];
    final settled = requests.where((request) => request.isSettled).toList()
      ..sort((a, b) => b.paidAt!.compareTo(a.paidAt!));
    final pendingCount =
        requests.where((r) => r.status == PayoutStatus.pending).length;

    return AppScreen(
      title: 'Mes commissions',
      footer: AppButton(
        label: 'Demander un versement',
        icon: Icons.payments_outlined,
        // Rien à demander tant que rien n'est acquis, ou qu'une demande est
        // déjà chez le gérant.
        onPressed: balance.available <= 0
            ? null
            : () => _openRequestSheet(context, ref, balance.available),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Banner(
            available: balance.available,
            revenue: commission.valueOrNull?.revenueFcfa ?? 0,
            paid: balance.paid,
            isLoading: commission.isLoading,
          ),
          AppSectionTitle(
            'Mes demandes',
            trailing: pendingCount == 0
                ? null
                : AppBadge(
                    label: '$pendingCount en attente',
                    color: AppColors.amberDeep,
                    background: AppColors.tintAmber,
                    dense: true,
                  ),
          ),
          payouts.when(
            loading: () => const AppLoader(compact: true),
            error: (error, _) => AppErrorState(
              message: '$error',
              compact: true,
              onRetry: () => ref.invalidate(myPayoutsProvider),
            ),
            data: (_) => requests.isEmpty
                ? const AppEmptyState(
                    compact: true,
                    title: 'Aucune demande',
                    message: 'Vos demandes de versement apparaîtront ici.',
                    icon: Icons.payments_outlined,
                  )
                : AppListCard(
                    children: [
                      for (final request in requests.take(6))
                        _RequestRow(request: request),
                    ],
                  ),
          ),
          if (settled.isNotEmpty) ...[
            const AppSectionTitle('Versements reçus'),
            AppListCard(
              children: [
                for (final payout in settled.take(6))
                  _PayoutRow(payout: payout),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Le montant à recevoir est calculé sur les tickets encaissés du '
            'mois, déduction faite des versements déjà réglés. Il peut évoluer '
            'jusqu\'à la clôture.',
            style: AppTypography.manrope(
              12,
              FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          if (profile != null && profile.commissionRate > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Taux appliqué : '
              '${profile.commissionRate.toStringAsFixed(profile.commissionRate % 1 == 0 ? 0 : 1)} %',
              style: AppTypography.manrope(
                12,
                FontWeight.w600,
                color: AppColors.textBody,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openRequestSheet(
    BuildContext context,
    WidgetRef ref,
    int availableAmount,
  ) async {
    final result = await showModalBottomSheet<({int amount, String? note})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => _RequestPayoutSheet(amount: availableAmount),
    );

    if (result == null) return;

    final ok = await ref
        .read(payoutRequestControllerProvider.notifier)
        .submit(
          amountFcfa: result.amount,
          note: result.note,
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Demande envoyée à votre gérant.'
              : 'Envoi impossible : '
                  '${ref.read(payoutRequestControllerProvider).error}',
        ),
      ),
    );
  }
}

class _RequestPayoutSheet extends StatefulWidget {
  const _RequestPayoutSheet({required this.amount});

  final int amount;

  @override
  State<_RequestPayoutSheet> createState() => _RequestPayoutSheetState();
}

class _RequestPayoutSheetState extends State<_RequestPayoutSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '${widget.amount}');
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Demander un versement',
              style: AppTypography.sora(18, FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Saisissez le montant souhaité (disponible : ${Formatters.fcfa(widget.amount)}).',
              style: AppTypography.manrope(
                12.5,
                FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            AppInput.amount(
              controller: _amountController,
              label: 'Montant demandé (FCFA)',
              hint: '0',
            ),
            const SizedBox(height: 14),
            AppInput(
              controller: _noteController,
              label: 'Message / Note (optionnel)',
              hint: 'Par Orange Money si possible',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Envoyer la demande',
              icon: Icons.send_rounded,
              onPressed: () {
                final inputAmount = int.tryParse(_amountController.text.trim()) ?? 0;
                final validAmount = inputAmount.clamp(1, widget.amount);
                final note = _noteController.text.trim();
                Navigator.of(context).pop((
                  amount: validAmount,
                  note: note.isEmpty ? null : note,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau vert : à recevoir, CA généré, déjà versé.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.available,
    required this.revenue,
    required this.paid,
    required this.isLoading,
  });

  final int available;
  final int revenue;
  final int paid;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.primary,
      borderColor: AppColors.primary,
      shadow: false,
      radius: 18,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'À recevoir · ${Formatters.monthName(DateTime.now())}',
            style: AppTypography.manrope(
              12.5,
              FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isLoading ? '—' : Formatters.fcfa(available),
              maxLines: 1,
              style: AppTypography.sora(
                30,
                FontWeight.w800,
                letterSpacing: -0.8,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _BannerTile(
                    label: 'CA généré',
                    value: isLoading ? '—' : Formatters.fcfa(revenue),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BannerTile(
                    label: 'Déjà versé',
                    value: Formatters.fcfa(paid),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Encart translucide posé sur le bandeau vert.
class _BannerTile extends StatelessWidget {
  const _BannerTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.manrope(
              11,
              FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.sora(
                15,
                FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne « Mes demandes » : pastille de statut, date, état, montant.
class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request});

  final PayoutRequest request;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (request.status) {
      PayoutStatus.paid => request.paidAt == null
          ? 'Versée'
          : 'Versée le ${Formatters.dayMonth(request.paidAt!)}',
      PayoutStatus.pending => request.method == null
          ? 'En attente gérant'
          : '${request.method!.label} · en attente gérant',
      PayoutStatus.rejected => 'Refusée',
    };

    return AppListRow(
      label: 'Demande · ${Formatters.dayMonth(request.requestedAt)}',
      subtitle: subtitle,
      strong: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      leading: AppIconTile(
        icon: request.status.icon,
        color: request.status.color,
        background: request.status.color.withValues(alpha: 0.12),
      ),
      trailing: Text(
        Formatters.fcfa(request.amountFcfa),
        style: AppTypography.sora(14.5, FontWeight.w800),
      ),
    );
  }
}

/// Ligne « Versements reçus » : moyen de paiement et référence.
class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.payout});

  final PayoutRequest payout;

  @override
  Widget build(BuildContext context) {
    final method = payout.method;

    return AppListRow(
      label: '${Formatters.dayMonth(payout.paidAt!)}'
          '${method == null ? '' : ' · ${method.label}'}',
      subtitle: payout.reference == null
          ? 'Aucune référence'
          : 'Réf. ${payout.reference}',
      strong: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      leading: AppIconTile(
        icon: method?.icon ?? Icons.payments_outlined,
        color: AppColors.primary,
        background: AppColors.tintGreen,
      ),
      trailing: Text(
        Formatters.fcfa(payout.amountFcfa),
        style: AppTypography.sora(14.5, FontWeight.w800),
      ),
    );
  }
}
