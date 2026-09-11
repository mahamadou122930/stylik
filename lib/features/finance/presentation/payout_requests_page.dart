import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
        icon: LucideIcons.plus,
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
                    icon: LucideIcons.history,
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

    if (ok) {
      ref.invalidate(allPayoutsProvider);
      ref.invalidate(stylistPayoutsProvider);
      ref.invalidate(stylistPayoutBalanceProvider);
      ref.invalidate(commissionsProvider);
    }

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

    if (ok) {
      ref.invalidate(allPayoutsProvider);
      ref.invalidate(stylistPayoutsProvider);
      ref.invalidate(stylistPayoutBalanceProvider);
      ref.invalidate(paidByStylistProvider);
      ref.invalidate(financeSummaryProvider);
    }

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

    if (ok) {
      ref.invalidate(allPayoutsProvider);
      ref.invalidate(stylistPayoutsProvider);
      ref.invalidate(stylistPayoutBalanceProvider);
    }

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
                  icon: LucideIcons.check,
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
                    LucideIcons.x,
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
        icon: isPaid ? LucideIcons.check : LucideIcons.x,
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
              icon: LucideIcons.check,
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
class _CreateProxyRequestSheet extends ConsumerStatefulWidget {
  const _CreateProxyRequestSheet({required this.team});

  final List<Profile> team;

  @override
  ConsumerState<_CreateProxyRequestSheet> createState() =>
      _CreateProxyRequestSheetState();
}

class _CreateProxyRequestSheetState
    extends ConsumerState<_CreateProxyRequestSheet> {
  Profile? _selectedStylist;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late final TextEditingController _searchController;
  final Set<String> _selectedDateKeys = {};
  DateTime? _customSelectedDate;
  bool _isDropdownOpen = false;

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int _calculateSelectedTotal(List<DailyCommissionItem> items) {
    var sum = 0;
    for (final it in items) {
      if (_selectedDateKeys.contains(_dateKey(it.date))) {
        sum += it.commissionFcfa;
      }
    }
    return sum;
  }

  @override
  void initState() {
    super.initState();
    if (widget.team.isNotEmpty) {
      _selectedStylist = widget.team.first;
    }
    _amountController = TextEditingController();
    _noteController = TextEditingController();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _isDaySettled({
    required DailyCommissionItem item,
    required int availableBalance,
    required List<PayoutRequest> settledPayouts,
    required List<DailyCommissionItem> allDays,
  }) {
    if (availableBalance <= 0) return true;

    final dayLabel = item.label.toLowerCase();
    final dayShort = Formatters.dayMonth(item.date).toLowerCase();
    for (final p in settledPayouts) {
      final note = (p.note ?? '').toLowerCase();
      if (note.contains(dayLabel) || note.contains(dayShort)) {
        return true;
      }
    }

    final sortedDays = List<DailyCommissionItem>.from(allDays)
      ..sort((a, b) => a.date.compareTo(b.date));
    final totalPaid = settledPayouts.fold<int>(
      0,
      (sum, p) => sum + p.amountFcfa,
    );
    var cumulatedDue = 0;
    for (final d in sortedDays) {
      cumulatedDue += d.commissionFcfa;
      if (d.date == item.date) {
        return totalPaid >= cumulatedDue;
      }
    }

    return false;
  }

  void _onToggleDay(
    DailyCommissionItem item,
    List<DailyCommissionItem> allItems,
    Set<String> settledKeys,
    int available,
  ) {
    final key = _dateKey(item.date);
    if (settledKeys.contains(key)) return;

    setState(() {
      if (_selectedDateKeys.contains(key)) {
        _selectedDateKeys.remove(key);
      } else {
        _selectedDateKeys.add(key);
      }
      _customSelectedDate = null;
      _updateAmountAndNote(allItems, settledKeys, available);
    });
  }

  void _toggleSelectAll(
    List<DailyCommissionItem> filteredItems,
    List<DailyCommissionItem> allItems,
    Set<String> settledKeys,
    int available,
  ) {
    setState(() {
      final selectable = filteredItems
          .where((d) => !settledKeys.contains(_dateKey(d.date)))
          .toList();
      if (selectable.isEmpty) return;

      final allSelectableSelected = selectable.every(
        (d) => _selectedDateKeys.contains(_dateKey(d.date)),
      );

      if (allSelectableSelected) {
        for (final d in selectable) {
          _selectedDateKeys.remove(_dateKey(d.date));
        }
      } else {
        for (final d in selectable) {
          _selectedDateKeys.add(_dateKey(d.date));
        }
      }
      _customSelectedDate = null;
      _updateAmountAndNote(allItems, settledKeys, available);
    });
  }

  void _updateAmountAndNote(
    List<DailyCommissionItem> allItems,
    Set<String> settledKeys,
    int available,
  ) {
    var sum = 0;
    final labels = <String>[];
    for (final item in allItems) {
      if (_selectedDateKeys.contains(_dateKey(item.date)) &&
          !settledKeys.contains(_dateKey(item.date))) {
        sum += item.commissionFcfa;
        labels.add(item.label);
      }
    }

    if (sum > 0) {
      final finalAmount = available > 0 && sum > available ? available : sum;
      _amountController.text = '$finalAmount';
    } else if (_selectedDateKeys.isEmpty) {
      _amountController.text = available > 0 ? '$available' : '0';
    }

    if (labels.length == 1) {
      _noteController.text = 'Commission du ${labels.first}';
    } else if (labels.length > 1) {
      _noteController.text =
          'Commissions (${labels.length} jrs) : ${labels.join(', ')}';
    } else {
      _noteController.text = '';
    }
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customSelectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() {
        _customSelectedDate = picked;
        _selectedDateKeys.clear();
        _noteController.text =
            'Commission du ${Formatters.weekdayDayMonth(picked)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dailyAsync = _selectedStylist == null
        ? null
        : ref.watch(stylistDailyCommissionsProvider(_selectedStylist!.id));
    final balance = _selectedStylist == null
        ? null
        : ref.watch(stylistPayoutBalanceProvider(_selectedStylist!.id));
    final payoutsAsync = _selectedStylist == null
        ? null
        : ref.watch(stylistPayoutsProvider(_selectedStylist!.id));
    final settledPayouts =
        payoutsAsync?.valueOrNull?.where((p) => p.isSettled).toList() ??
        const <PayoutRequest>[];
    final available = balance?.available ?? 0;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Padding(
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
                  if (val != null) {
                    setState(() {
                      _selectedStylist = val;
                      _selectedDateKeys.clear();
                      _customSelectedDate = null;
                      _amountController.clear();
                      _noteController.clear();
                      _searchController.clear();
                    });
                  }
                },
              ),
              const SizedBox(height: 14),

              if (_selectedStylist != null && available <= 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tintGreenSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.tintGreenBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.checkCheck,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Toutes les commissions de cet employé ont déjà été réglées (Dû restant : 0 F).',
                          style: AppTypography.manrope(
                            12.5,
                            FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Sélection de la journée
              if (_selectedStylist != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'JOURNÉES AVEC COMMISSION',
                      style: AppTypography.manrope(
                        11.5,
                        FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    InkWell(
                      onTap: _pickCustomDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.calendar,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Autre date…',
                              style: AppTypography.manrope(
                                12,
                                FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_customSelectedDate != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.tintGreenSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.tintGreenBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.calendarCheck,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Journée choisie : ${Formatters.weekdayDayMonth(_customSelectedDate!)}',
                            style: AppTypography.manrope(
                              13,
                              FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _customSelectedDate = null),
                          child: const Icon(
                            LucideIcons.x,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (dailyAsync != null)
                  dailyAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: AppLoader(compact: true)),
                    ),
                    error: (e, s) => const SizedBox.shrink(),
                    data: (items) {
                      final commissionDays = items
                          .where((it) => it.commissionFcfa > 0)
                          .toList();

                      if (commissionDays.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.info,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Aucune commission en attente sur cette période.',
                                  style: AppTypography.manrope(
                                    12,
                                    FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Identifier les journées déjà réglées
                      final settledKeys = <String>{};
                      for (final it in commissionDays) {
                        if (_isDaySettled(
                          item: it,
                          availableBalance: available,
                          settledPayouts: settledPayouts,
                          allDays: commissionDays,
                        )) {
                          settledKeys.add(_dateKey(it.date));
                        }
                      }
                      final unpaidDays = commissionDays
                          .where(
                            (it) => !settledKeys.contains(_dateKey(it.date)),
                          )
                          .toList();

                      final query = _searchController.text.trim().toLowerCase();
                      final filteredDays = commissionDays.where((it) {
                        if (query.isEmpty) return true;
                        return it.label.toLowerCase().contains(query) ||
                            '${it.date.day}'.contains(query);
                      }).toList();

                      final totalSelected = _calculateSelectedTotal(
                        commissionDays,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Bouton / En-tête de la liste déroulante
                          InkWell(
                            onTap: () => setState(
                              () => _isDropdownOpen = !_isDropdownOpen,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedDateKeys.isNotEmpty
                                    ? AppColors.tintGreenSoft
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedDateKeys.isNotEmpty
                                      ? AppColors.tintGreenBorder
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedDateKeys.isNotEmpty
                                        ? LucideIcons.calendarCheck
                                        : unpaidDays.isEmpty
                                        ? LucideIcons.checkCheck
                                        : LucideIcons.calendar,
                                    size: 18,
                                    color:
                                        _selectedDateKeys.isNotEmpty ||
                                            unpaidDays.isEmpty
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedDateKeys.isEmpty
                                              ? (unpaidDays.isEmpty
                                                    ? 'Toutes les journées sont déjà réglées'
                                                    : 'Choisir les journées (${unpaidDays.length} disponible${unpaidDays.length > 1 ? 's' : ''})')
                                              : '${_selectedDateKeys.length} journée${_selectedDateKeys.length > 1 ? 's' : ''} cochée${_selectedDateKeys.length > 1 ? 's' : ''}',
                                          style: AppTypography.manrope(
                                            13.5,
                                            FontWeight.w600,
                                            color:
                                                _selectedDateKeys.isNotEmpty ||
                                                    unpaidDays.isEmpty
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        if (_selectedDateKeys.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Total sélectionné : ${Formatters.fcfa(totalSelected)}',
                                            style: AppTypography.manrope(
                                              11.5,
                                              FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ] else if (unpaidDays.isEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Solde restant dû : 0 F',
                                            style: AppTypography.manrope(
                                              11.5,
                                              FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    _isDropdownOpen
                                        ? LucideIcons.chevronUp
                                        : LucideIcons.chevronDown,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Menu déroulant déplié
                          if (_isDropdownOpen) ...[
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Champ de recherche compact
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      10,
                                      10,
                                      8,
                                    ),
                                    child: Container(
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            LucideIcons.search,
                                            size: 14,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: TextField(
                                              controller: _searchController,
                                              onChanged: (_) => setState(() {}),
                                              decoration: const InputDecoration(
                                                hintText:
                                                    'Filtrer (ex: sam, 15, sept)…',
                                                hintStyle: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ),
                                          if (_searchController.text.isNotEmpty)
                                            GestureDetector(
                                              onTap: () => setState(
                                                () => _searchController.clear(),
                                              ),
                                              child: const Icon(
                                                LucideIcons.x,
                                                size: 14,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: AppColors.border,
                                  ),

                                  // Liste défilable avec hauteur contenue
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 180,
                                    ),
                                    child: filteredDays.isEmpty
                                        ? Padding(
                                            padding: const EdgeInsets.all(14),
                                            child: Center(
                                              child: Text(
                                                'Aucune journée trouvée',
                                                style: AppTypography.manrope(
                                                  12,
                                                  FontWeight.w500,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Scrollbar(
                                            thumbVisibility: true,
                                            child: ListView.separated(
                                              shrinkWrap: true,
                                              padding: EdgeInsets.zero,
                                              itemCount: filteredDays.length,
                                              separatorBuilder:
                                                  (context, index) =>
                                                      const Divider(
                                                        height: 1,
                                                        thickness: 1,
                                                        color: AppColors.border,
                                                      ),
                                              itemBuilder: (context, i) {
                                                final item = filteredDays[i];
                                                final isSelected =
                                                    _selectedDateKeys.contains(
                                                      _dateKey(item.date),
                                                    );
                                                final isSettled = settledKeys
                                                    .contains(
                                                      _dateKey(item.date),
                                                    );

                                                return InkWell(
                                                  onTap: isSettled
                                                      ? null
                                                      : () => _onToggleDay(
                                                          item,
                                                          commissionDays,
                                                          settledKeys,
                                                          available,
                                                        ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 10,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 22,
                                                          height: 22,
                                                          decoration: BoxDecoration(
                                                            color: isSettled
                                                                ? AppColors
                                                                      .tintGreen
                                                                : isSelected
                                                                ? AppColors
                                                                      .accent
                                                                : Colors.white,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  6,
                                                                ),
                                                            border:
                                                                isSelected ||
                                                                    isSettled
                                                                ? null
                                                                : Border.all(
                                                                    color: AppColors
                                                                        .borderStrong,
                                                                    width: 1.5,
                                                                  ),
                                                          ),
                                                          alignment:
                                                              Alignment.center,
                                                          child: isSettled
                                                              ? const Icon(
                                                                  LucideIcons
                                                                      .check,
                                                                  size: 13,
                                                                  color: AppColors
                                                                      .primary,
                                                                )
                                                              : isSelected
                                                              ? const Icon(
                                                                  LucideIcons
                                                                      .check,
                                                                  size: 13,
                                                                  color: Colors
                                                                      .white,
                                                                )
                                                              : null,
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  Text(
                                                                    item.label,
                                                                    style: AppTypography.manrope(
                                                                      13,
                                                                      FontWeight
                                                                          .w700,
                                                                      color:
                                                                          isSettled
                                                                          ? AppColors.textSecondary
                                                                          : AppColors.textPrimary,
                                                                    ),
                                                                  ),
                                                                  if (isSettled) ...[
                                                                    const SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            1.5,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: AppColors
                                                                            .tintGreen,
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              6,
                                                                            ),
                                                                      ),
                                                                      child: Text(
                                                                        'Réglé',
                                                                        style: AppTypography.manrope(
                                                                          10,
                                                                          FontWeight
                                                                              .w700,
                                                                          color:
                                                                              AppColors.primary,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                height: 1,
                                                              ),
                                                              Text(
                                                                [
                                                                  if (item
                                                                      .isCurrentDay)
                                                                    'En cours',
                                                                  '${item.serviceCount} prestations',
                                                                  'CA ${Formatters.fcfa(item.revenueFcfa)}',
                                                                ].join(' · '),
                                                                style: AppTypography.manrope(
                                                                  11,
                                                                  FontWeight
                                                                      .w500,
                                                                  color: AppColors
                                                                      .textSecondary,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Text(
                                                          Formatters.fcfa(
                                                            item.commissionFcfa,
                                                          ),
                                                          style: AppTypography.sora(
                                                            13,
                                                            FontWeight.w700,
                                                            color: isSettled
                                                                ? AppColors
                                                                      .textSecondary
                                                                : AppColors
                                                                      .primary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                  ),
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: AppColors.border,
                                  ),

                                  // Pied avec Tout cocher et bouton Fermer
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (unpaidDays.isNotEmpty)
                                          GestureDetector(
                                            onTap: () => _toggleSelectAll(
                                              filteredDays,
                                              commissionDays,
                                              settledKeys,
                                              available,
                                            ),
                                            child: Text(
                                              unpaidDays.every(
                                                    (d) => _selectedDateKeys
                                                        .contains(
                                                          _dateKey(d.date),
                                                        ),
                                                  )
                                                  ? 'Tout décocher'
                                                  : 'Tout cocher',
                                              style: AppTypography.manrope(
                                                12,
                                                FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          )
                                        else
                                          Text(
                                            'Toutes les journées sont réglées',
                                            style: AppTypography.manrope(
                                              11.5,
                                              FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        InkWell(
                                          onTap: () => setState(
                                            () => _isDropdownOpen = false,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: AppColors.border,
                                              ),
                                            ),
                                            child: Text(
                                              'Fermer',
                                              style: AppTypography.manrope(
                                                11.5,
                                                FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 14),
              ],

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
                label: available <= 0
                    ? 'Toutes les commissions sont réglées'
                    : 'Déposer la demande',
                icon: available <= 0
                    ? LucideIcons.checkCheck
                    : LucideIcons.send,
                onPressed: available <= 0
                    ? null
                    : () {
                        if (_selectedStylist == null) return;
                        final amount =
                            int.tryParse(_amountController.text.trim()) ?? 0;
                        if (amount <= 0) return;
                        if (amount > available) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Le montant ne peut pas dépasser le dû restant (${Formatters.fcfa(available)}).',
                              ),
                            ),
                          );
                          return;
                        }
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
      ),
    );
  }
}
