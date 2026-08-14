import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/finance_summary.dart';
import '../domain/payout.dart';
import 'finance_providers.dart';

/// 8.2b — Commissions d'un coiffeur (vue gérant) : versement, historique et validation.
class StylistCommissionDetailPage extends ConsumerWidget {
  const StylistCommissionDetailPage({
    super.key,
    required this.commission,
  });

  static const routeName = '/finance/stylist-commission-detail';

  final StylistCommission commission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payouts = ref.watch(stylistPayoutsProvider(commission.stylistId));
    final requests = payouts.valueOrNull ?? const <PayoutRequest>[];

    final pending = requests
        .where((r) => r.status == PayoutStatus.pending)
        .toList();
    final settled = requests.where((r) => r.isSettled).toList()
      ..sort((a, b) => (b.paidAt ?? b.requestedAt).compareTo(a.paidAt ?? a.requestedAt));

    final balance = ref.watch(
      stylistPayoutBalanceProvider((
        profileId: commission.stylistId,
        earned: commission.commissionFcfa,
      )),
    );

    // Initiales ou prénom pour le titre
    final firstName = commission.stylistName.split(' ').first;

    return AppScreen(
      title: 'Commissions — $firstName',
      footer: AppButton(
        label: 'Enregistrer un versement',
        icon: Icons.add_rounded,
        onPressed: () => _openRegisterSheet(context, ref, balance.available),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Banner(
            dueAmount: commission.commissionFcfa,
            paidAmount: balance.paid,
            remainingAmount: balance.available,
          ),
          if (pending.isNotEmpty) ...[
            AppSectionTitle(
              'Demande en cours',
              trailing: AppBadge(
                label: '${pending.length}',
                color: AppColors.amberDeep,
                background: AppColors.tintAmber,
                dense: true,
              ),
            ),
            for (final request in pending) ...[
              _PendingRequestCard(
                request: request,
                onSettle: () => _openSettleSheet(context, ref, request),
                onReject: () => _rejectRequest(context, ref, request),
              ),
              const SizedBox(height: 12),
            ],
          ],
          const AppSectionTitle('Versements effectués'),
          payouts.when(
            loading: () => const AppLoader(compact: true),
            error: (error, _) => AppErrorState(
              message: '$error',
              compact: true,
              onRetry: () =>
                  ref.invalidate(stylistPayoutsProvider(commission.stylistId)),
            ),
            data: (_) => settled.isEmpty
                ? const AppEmptyState(
                    compact: true,
                    title: 'Aucun versement',
                    message: 'Les réglages de commission apparaîtront ici.',
                    icon: Icons.payments_outlined,
                  )
                : AppListCard(
                    children: [
                      for (final payout in settled)
                        _PayoutRow(payout: payout),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettleSheet(
    BuildContext context,
    WidgetRef ref,
    PayoutRequest request,
  ) async {
    final result = await showModalBottomSheet<({PayoutMethod method, String? ref})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _SettlePayoutSheet(request: request),
    );

    if (result == null) return;

    final ok = await ref
        .read(payoutRequestControllerProvider.notifier)
        .settle(
          requestId: request.id,
          method: result.method,
          reference: result.ref,
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Versement validé avec succès.' : 'Erreur lors de la validation.',
        ),
      ),
    );
  }

  Future<void> _rejectRequest(
    BuildContext context,
    WidgetRef ref,
    PayoutRequest request,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refuser la demande ?'),
        content: Text(
          'Voulez-vous refuser la demande de ${Formatters.fcfa(request.amountFcfa)} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await ref
        .read(payoutRequestControllerProvider.notifier)
        .reject(requestId: request.id);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Demande refusée.' : 'Erreur lors du refus.',
        ),
      ),
    );
  }

  Future<void> _openRegisterSheet(
    BuildContext context,
    WidgetRef ref,
    int availableAmount,
  ) async {
    final result = await showModalBottomSheet<
        ({int amount, PayoutMethod method, String? ref, String? note})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _RegisterPayoutSheet(
        stylistName: commission.stylistName,
        maxAmount: availableAmount,
      ),
    );

    if (result == null) return;

    final ok = await ref
        .read(payoutRequestControllerProvider.notifier)
        .createDirect(
          profileId: commission.stylistId,
          amountFcfa: result.amount,
          method: result.method,
          reference: result.ref,
          note: result.note,
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Versement enregistré pour ${commission.stylistName}.'
              : 'Impossible d\'enregistrer le versement.',
        ),
      ),
    );
  }
}

/// Carte verte du haut (Commission due, Déjà versé, Reste à verser).
class _Banner extends StatelessWidget {
  const _Banner({
    required this.dueAmount,
    required this.paidAmount,
    required this.remainingAmount,
  });

  final int dueAmount;
  final int paidAmount;
  final int remainingAmount;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

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
            'Commission due · ${Formatters.monthName(now)}',
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
              Formatters.fcfa(dueAmount),
              style: AppTypography.sora(
                30,
                FontWeight.w800,
                letterSpacing: -0.8,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SubBannerTile(
                  label: 'Déjà versé',
                  value: Formatters.fcfa(paidAmount),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SubBannerTile(
                  label: 'Reste à verser',
                  value: Formatters.fcfa(remainingAmount),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubBannerTile extends StatelessWidget {
  const _SubBannerTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

/// Carte "Demande en cours" avec boutons Verser / Refuser.
class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({
    required this.request,
    required this.onSettle,
    required this.onReject,
  });

  final PayoutRequest request;
  final VoidCallback onSettle;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final methodLabel = request.method?.label;
    final subtitle = 'Déposée le ${Formatters.dayMonth(request.requestedAt)}'
        '${methodLabel != null ? ' · $methodLabel' : ''}';

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.tintAmber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: AppColors.amberDeep,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Demande de versement',
                      style: AppTypography.sora(14.5, FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.manrope(
                        12,
                        FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                Formatters.fcfa(request.amountFcfa),
                style: AppTypography.sora(16, FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Verser',
                  onPressed: onSettle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.expense,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: Text(
                    'Refuser',
                    style: AppTypography.sora(
                      14,
                      FontWeight.w700,
                      color: AppColors.expense,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.payout});

  final PayoutRequest payout;

  @override
  Widget build(BuildContext context) {
    final method = payout.method;
    final title = '${Formatters.dayMonth(payout.paidAt ?? payout.requestedAt)}'
        '${method == null ? '' : ' · ${method.label}'}';
    final subtitle = payout.reference == null || payout.reference!.isEmpty
        ? 'Aucune référence'
        : payout.reference!.startsWith('Réf') || payout.reference!.startsWith('Reçu')
            ? payout.reference!
            : 'Réf. ${payout.reference}';

    return AppListRow(
      label: title,
      subtitle: subtitle,
      strong: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      leading: const AppIconTile(
        icon: Icons.check_rounded,
        color: AppColors.primary,
        background: AppColors.tintGreen,
        size: 38,
        radius: 11,
      ),
      trailing: Text(
        Formatters.fcfa(payout.amountFcfa),
        style: AppTypography.sora(14.5, FontWeight.w800),
      ),
    );
  }
}

/// Sheet pour régler une demande en attente.
class _SettlePayoutSheet extends StatefulWidget {
  const _SettlePayoutSheet({required this.request});

  final PayoutRequest request;

  @override
  State<_SettlePayoutSheet> createState() => _SettlePayoutSheetState();
}

class _SettlePayoutSheetState extends State<_SettlePayoutSheet> {
  late PayoutMethod _selectedMethod;
  late final TextEditingController _refController;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.request.method ?? PayoutMethod.wave;
    _refController = TextEditingController();
  }

  @override
  void dispose() {
    _refController.dispose();
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
              'Valider le versement',
              style: AppTypography.sora(18, FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Montant à régler : ${Formatters.fcfa(widget.request.amountFcfa)}',
              style: AppTypography.manrope(
                13,
                FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Moyen de paiement',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final method in PayoutMethod.values)
                  ChoiceChip(
                    label: Text(method.label),
                    selected: _selectedMethod == method,
                    onSelected: (val) {
                      if (val) setState(() => _selectedMethod = method);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppInput(
              controller: _refController,
              label: 'Référence / N° de reçu (optionnel)',
              hint: 'Ex: TXN-Q7F42K ou Reçu n° 0142',
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Valider & régler',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.pop(
                context,
                (method: _selectedMethod, ref: _refController.text.trim()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet pour enregistrer un versement direct.
class _RegisterPayoutSheet extends StatefulWidget {
  const _RegisterPayoutSheet({
    required this.stylistName,
    required this.maxAmount,
  });

  final String stylistName;
  final int maxAmount;

  @override
  State<_RegisterPayoutSheet> createState() => _RegisterPayoutSheetState();
}

class _RegisterPayoutSheetState extends State<_RegisterPayoutSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _refController;
  late final TextEditingController _noteController;
  PayoutMethod _method = PayoutMethod.wave;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.maxAmount > 0 ? '${widget.maxAmount}' : '',
    );
    _refController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
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
              'Enregistrer un versement',
              style: AppTypography.sora(18, FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Règlement direct pour ${widget.stylistName}',
              style: AppTypography.manrope(
                13,
                FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            AppInput.amount(
              controller: _amountController,
              label: 'Montant versé (FCFA)',
              hint: '0',
            ),
            const SizedBox(height: 14),
            const Text(
              'Moyen de paiement',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final method in PayoutMethod.values)
                  ChoiceChip(
                    label: Text(method.label),
                    selected: _method == method,
                    onSelected: (val) {
                      if (val) setState(() => _method = method);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            AppInput(
              controller: _refController,
              label: 'Référence / N° de reçu (optionnel)',
              hint: 'Ex: TXN-Q7F42K',
            ),
            const SizedBox(height: 14),
            AppInput(
              controller: _noteController,
              label: 'Note / Remarque (optionnel)',
              hint: 'Avance sur commission',
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Enregistrer',
              icon: Icons.check_rounded,
              onPressed: () {
                final amount = int.tryParse(_amountController.text.trim()) ?? 0;
                if (amount <= 0) return;
                Navigator.pop(context, (
                  amount: amount,
                  method: _method,
                  ref: _refController.text.trim(),
                  note: _noteController.text.trim(),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}
