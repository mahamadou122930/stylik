import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/profile.dart';
import '../../staff/presentation/staff_providers.dart';
import '../domain/payout.dart';
import 'finance_providers.dart';

/// 8.2c — Demandes de versement (vue gérant) : validation globale et historique.
class PayoutRequestsPage extends ConsumerWidget {
  const PayoutRequestsPage({super.key});

  static const routeName = '/finance/payout-requests';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payoutsAsync = ref.watch(allPayoutsProvider);
    final commissionsAsync = ref.watch(commissionsProvider);

    final requests = payoutsAsync.valueOrNull ?? const <PayoutRequest>[];
    final pendingList = requests
        .where((r) => r.status == PayoutStatus.pending)
        .toList();
    final processedList =
        requests.where((r) => r.status != PayoutStatus.pending).toList()..sort(
          (a, b) =>
              (b.paidAt ?? b.requestedAt).compareTo(a.paidAt ?? a.requestedAt),
        );

    // Calculs de synthèse des top cartes
    final totalPendingAmount = pendingList.fold(
      0,
      (sum, r) => sum + r.amountFcfa,
    );

    final now = DateTime.now();
    final settledThisMonth = requests
        .where(
          (r) =>
              r.isSettled &&
              r.paidAt != null &&
              r.paidAt!.year == now.year &&
              r.paidAt!.month == now.month,
        )
        .toList();

    final totalPaidThisMonth = settledThisMonth.fold(
      0,
      (sum, r) => sum + r.amountFcfa,
    );

    final dueByStylist = <String, int>{};
    if (commissionsAsync.valueOrNull != null) {
      for (final c in commissionsAsync.value!) {
        dueByStylist[c.stylistId] = c.commissionFcfa;
      }
    }

    return AppScreen(
      title: 'Demandes de versement',
      action: AppIconButton(
        icon: Icons.add_rounded,
        onTap: () => _openNewRequestSheet(context, ref),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard.amber(
                  label: 'En attente',
                  amount: Formatters.fcfa(totalPendingAmount),
                  subtitle:
                      '${pendingList.length} demande${pendingList.length > 1 ? 's' : ''}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard.white(
                  label: 'Versé ce mois',
                  amount: _formatCompactFcfa(totalPaidThisMonth),
                  subtitle:
                      '${settledThisMonth.length} versement${settledThisMonth.length > 1 ? 's' : ''}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (pendingList.isNotEmpty) ...[
            const AppSectionTitle('À traiter'),
            for (final request in pendingList) ...[
              _PendingActionCard(
                request: request,
                dueAmount:
                    dueByStylist[request.profileId] ?? request.amountFcfa,
                onApprove: () => _openSettleSheet(context, ref, request),
                onReject: () => _rejectRequest(context, ref, request),
              ),
              const SizedBox(height: 12),
            ],
          ],
          const AppSectionTitle('Traitées récemment'),
          payoutsAsync.when(
            loading: () => const AppLoader(compact: true),
            error: (error, _) => AppErrorState(
              message: '$error',
              compact: true,
              onRetry: () => ref.invalidate(allPayoutsProvider),
            ),
            data: (_) => processedList.isEmpty
                ? const AppEmptyState(
                    compact: true,
                    title: 'Aucune demande traitée',
                    message:
                        'Les demandes validées ou refusées s\'afficheront ici.',
                    icon: Icons.history_rounded,
                  )
                : AppListCard(
                    children: [
                      for (final payout in processedList.take(10))
                        _ProcessedRow(request: payout),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _formatCompactFcfa(int amount) {
    if (amount >= 1000000) {
      final millions = (amount / 1000000)
          .toStringAsFixed(1)
          .replaceAll('.', ',');
      return '$millions M F';
    }
    return Formatters.fcfa(amount);
  }

  Future<void> _openNewRequestSheet(BuildContext context, WidgetRef ref) async {
    final team = ref.read(teamProvider).valueOrNull ?? const <Profile>[];

    final result =
        await showModalBottomSheet<
          ({Profile stylist, int amount, String? note})
        >(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          builder: (context) => _CreateProxyRequestSheet(team: team),
        );

    if (result == null) return;

    final ok = await ref
        .read(payoutRequestControllerProvider.notifier)
        .submit(
          profileId: result.stylist.id,
          amountFcfa: result.amount,
          note: result.note,
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Demande de versement créée pour ${result.stylist.fullName}.'
              : 'Erreur lors de la création de la demande.',
        ),
      ),
    );
  }

  Future<void> _openSettleSheet(
    BuildContext context,
    WidgetRef ref,
    PayoutRequest request,
  ) async {
    final result =
        await showModalBottomSheet<({PayoutMethod method, String? ref})>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          builder: (context) => _SettleSheet(request: request),
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
          ok ? 'Demande validée et réglée.' : 'Erreur lors de la validation.',
        ),
      ),
    );
  }

  Future<void> _rejectRequest(
    BuildContext context,
    WidgetRef ref,
    PayoutRequest request,
  ) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refuser la demande ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Motif du refus pour ${request.profileName ?? "le coiffeur"} (optionnel) :',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Ex: solde insuffisant',
              ),
            ),
          ],
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
    final reason = reasonController.text.trim();

    final ok = await ref
        .read(payoutRequestControllerProvider.notifier)
        .reject(
          requestId: request.id,
          reason: reason.isEmpty ? 'solde insuffisant' : reason,
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Demande refusée.' : 'Erreur lors du refus.'),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard.amber({
    required this.label,
    required this.amount,
    required this.subtitle,
  }) : isAmber = true;

  const _MetricCard.white({
    required this.label,
    required this.amount,
    required this.subtitle,
  }) : isAmber = false;

  final String label;
  final String amount;
  final String subtitle;
  final bool isAmber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAmber ? AppColors.tintAmber : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAmber
              ? AppColors.amber.withValues(alpha: 0.25)
              : AppColors.border,
        ),
        boxShadow: isAmber ? null : AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.manrope(
              12.5,
              FontWeight.w600,
              color: isAmber ? AppColors.amberDeep : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: AppTypography.sora(
                21,
                FontWeight.w800,
                color: isAmber ? AppColors.amberDeep : AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
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
    );
  }
}

class _PendingActionCard extends StatelessWidget {
  const _PendingActionCard({
    required this.request,
    required this.dueAmount,
    required this.onApprove,
    required this.onReject,
  });

  final PayoutRequest request;
  final int dueAmount;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final name = request.profileName ?? 'Coiffeur';
    final methodLabel = request.method?.label ?? 'Méthode non spécifiée';
    final subtitle =
        'Demande le ${Formatters.dayMonth(request.requestedAt)} · $methodLabel';

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tintBlue,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  Formatters.initials(name),
                  style: AppTypography.sora(
                    15,
                    FontWeight.w700,
                    color: AppColors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTypography.sora(15, FontWeight.w800)),
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Commission due · ${Formatters.monthName(DateTime.now())}',
                  style: AppTypography.manrope(
                    12.5,
                    FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  Formatters.fcfa(dueAmount),
                  style: AppTypography.sora(14, FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Valider & payer',
                  icon: Icons.check_rounded,
                  onPressed: onApprove,
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: onReject,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(
                      color: AppColors.expense.withValues(alpha: 0.4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.expense,
                    size: 20,
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

class _ProcessedRow extends StatelessWidget {
  const _ProcessedRow({required this.request});

  final PayoutRequest request;

  @override
  Widget build(BuildContext context) {
    final isPaid = request.isSettled;
    final name = request.profileName ?? 'Coiffeur';
    final date = isPaid
        ? (request.paidAt ?? request.requestedAt)
        : request.requestedAt;

    final subtitle = isPaid
        ? 'Versé le ${Formatters.dayMonth(date)}${request.method != null ? ' · ${request.method!.label}' : ''}'
        : 'Refusée le ${Formatters.dayMonth(date)}${request.note != null ? ' · ${request.note}' : ''}';

    return AppListRow(
      label: name,
      subtitle: subtitle,
      strong: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      leading: AppIconTile(
        icon: isPaid ? Icons.check_rounded : Icons.close_rounded,
        color: isPaid ? AppColors.primary : AppColors.expense,
        background: isPaid ? AppColors.tintGreen : AppColors.tintExpense,
        size: 38,
        radius: 11,
      ),
      trailing: Text(
        Formatters.fcfa(request.amountFcfa),
        style: AppTypography.sora(
          14.5,
          FontWeight.w800,
          color: isPaid ? AppColors.textPrimary : AppColors.textFaint,
        ),
      ),
    );
  }
}

class _SettleSheet extends StatefulWidget {
  const _SettleSheet({required this.request});

  final PayoutRequest request;

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  late PayoutMethod _method;
  late final TextEditingController _refController;

  @override
  void initState() {
    super.initState();
    _method = widget.request.method ?? PayoutMethod.orangeMoney;
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
              'Valider & payer',
              style: AppTypography.sora(18, FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Règlement de ${Formatters.fcfa(widget.request.amountFcfa)} pour ${widget.request.profileName ?? "le coiffeur"}',
              style: AppTypography.manrope(
                13,
                FontWeight.w500,
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
                    selected: _method == method,
                    onSelected: (val) {
                      if (val) setState(() => _method = method);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppInput(
              controller: _refController,
              label: 'Référence / N° de transaction (optionnel)',
              hint: 'Ex: TXN-Q7F42K ou Reçu n° 0142',
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Valider & régler',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.pop(context, (
                method: _method,
                ref: _refController.text.trim(),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet pour déposer une demande au nom d'un coiffeur (réception / gérant).
class _CreateProxyRequestSheet extends StatefulWidget {
  const _CreateProxyRequestSheet({required this.team});

  final List<Profile> team;

  @override
  State<_CreateProxyRequestSheet> createState() =>
      _CreateProxyRequestSheetState();
}

class _CreateProxyRequestSheetState extends State<_CreateProxyRequestSheet> {
  Profile? _selectedStylist;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    if (widget.team.isNotEmpty) {
      _selectedStylist = widget.team.first;
    }
    _amountController = TextEditingController();
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
              'Demande pour un coiffeur',
              style: AppTypography.sora(18, FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Créer une demande de versement au nom d\'un employé',
              style: AppTypography.manrope(
                12.5,
                FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Coiffeur / Employé',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Profile>(
              initialValue: _selectedStylist,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              items: [
                for (final p in widget.team)
                  DropdownMenuItem(value: p, child: Text(p.fullName)),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedStylist = val);
              },
            ),
            const SizedBox(height: 14),
            AppInput.amount(
              controller: _amountController,
              label: 'Montant souhaité (FCFA)',
              hint: '0',
            ),
            const SizedBox(height: 14),
            AppInput(
              controller: _noteController,
              label: 'Note / Remarque (optionnel)',
              hint: 'Demande orale faite à la réception',
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Déposer la demande',
              icon: Icons.send_rounded,
              onPressed: () {
                if (_selectedStylist == null) return;
                final amount = int.tryParse(_amountController.text.trim()) ?? 0;
                if (amount <= 0) return;
                Navigator.pop(context, (
                  stylist: _selectedStylist!,
                  amount: amount,
                  note: _noteController.text.trim().isEmpty
                      ? null
                      : _noteController.text.trim(),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}
