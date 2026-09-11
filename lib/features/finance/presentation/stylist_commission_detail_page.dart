import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/finance_summary.dart';
import '../domain/payout.dart';
import 'finance_providers.dart';

/// 8.2b — Commissions d'un coiffeur (vue gérant) : versement, historique et validation.
class StylistCommissionDetailPage extends ConsumerWidget {
  const StylistCommissionDetailPage({super.key, required this.commission});

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
      ..sort(
        (a, b) =>
            (b.paidAt ?? b.requestedAt).compareTo(a.paidAt ?? a.requestedAt),
      );

    // Solde cumulé, et non la commission de la période affichée : c'est cette
    // borne-là que `request_payout` applique côté base.
    final balance = ref.watch(
      stylistPayoutBalanceProvider(commission.stylistId),
    );

    // Initiales ou prénom pour le titre
    final firstName = commission.stylistName.split(' ').first;

    return AppScreen(
      title: 'Commissions — $firstName',
      footer: AppButton(
        label: balance.available > 0
            ? 'Enregistrer un versement'
            : 'Toutes les commissions sont réglées',
        icon: balance.available > 0 ? LucideIcons.plus : LucideIcons.checkCheck,
        onPressed: balance.available > 0
            ? () => _openRegisterSheet(context, ref, balance.available)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Banner(
            // Le dû **cumulé**, comme le versé et le reste juste à côté :
            // afficher la commission du seul mois affiché à côté d'un versé
            // de tous les temps donnait « 450 F dû » sous « 6 750 F versés ».
            dueAmount: balance.earned,
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
                    icon: LucideIcons.banknote,
                  )
                : AppListCard(
                    children: [
                      for (final payout in settled) _PayoutRow(payout: payout),
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
    final result =
        await showModalBottomSheet<({PayoutMethod method, String? ref})>(
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

    if (ok) {
      ref.invalidate(stylistPayoutsProvider(commission.stylistId));
      ref.invalidate(stylistPayoutBalanceProvider(commission.stylistId));
      ref.invalidate(stylistDailyCommissionsProvider(commission.stylistId));
      ref.invalidate(allPayoutsProvider);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Versement validé avec succès.'
              : 'Erreur lors de la validation.',
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

    if (ok) {
      ref.invalidate(stylistPayoutsProvider(commission.stylistId));
      ref.invalidate(stylistPayoutBalanceProvider(commission.stylistId));
      ref.invalidate(allPayoutsProvider);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Demande refusée.' : 'Erreur lors du refus.'),
      ),
    );
  }

  Future<void> _openRegisterSheet(
    BuildContext context,
    WidgetRef ref,
    int availableAmount,
  ) async {
    final result =
        await showModalBottomSheet<
          ({int amount, PayoutMethod method, String? ref, String? note})
        >(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          builder: (context) => _RegisterPayoutSheet(
            stylistId: commission.stylistId,
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

    if (ok) {
      ref.invalidate(stylistPayoutsProvider(commission.stylistId));
      ref.invalidate(stylistPayoutBalanceProvider(commission.stylistId));
      ref.invalidate(stylistDailyCommissionsProvider(commission.stylistId));
      ref.invalidate(allPayoutsProvider);
    }

    if (!context.mounted) return;

    // La raison du refus vient de la base — droits insuffisants, montant
    // supérieur au dû — et c'est elle qui permet d'agir. « Impossible
    // d'enregistrer » seul laissait le gérant sans rien à corriger.
    final error = ref.read(payoutRequestControllerProvider).error;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Versement enregistré pour ${commission.stylistName}.'
              : 'Versement refusé : ${ErrorMessages.humanize(error)}',
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
            // Cumulé, et non « · août » : les trois montants de cette carte
            // couvrent tout l'historique du membre. Nommer un mois ici
            // laissait croire que le versé et le reste ne parlaient que de
            // celui-ci.
            "Commission due · depuis l'ouverture",
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
    final subtitle =
        'Déposée le ${Formatters.dayMonth(request.requestedAt)}'
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
                  LucideIcons.clock,
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
                child: AppButton(label: 'Verser', onPressed: onSettle),
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
    final title =
        '${Formatters.dayMonth(payout.paidAt ?? payout.requestedAt)}'
        '${method == null ? '' : ' · ${method.label}'}';
    final subtitle = payout.reference == null || payout.reference!.isEmpty
        ? 'Aucune référence'
        : payout.reference!.startsWith('Réf') ||
              payout.reference!.startsWith('Reçu')
        ? payout.reference!
        : 'Réf. ${payout.reference}';

    return AppListRow(
      label: title,
      subtitle: subtitle,
      strong: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      leading: const AppIconTile(
        icon: LucideIcons.check,
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
    _selectedMethod = widget.request.method ?? PayoutMethod.orangeMoney;
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
              icon: LucideIcons.check,
              onPressed: () => Navigator.pop(context, (
                method: _selectedMethod,
                ref: _refController.text.trim(),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet pour enregistrer un versement direct avec sélection de la journée.
class _RegisterPayoutSheet extends ConsumerStatefulWidget {
  const _RegisterPayoutSheet({
    required this.stylistId,
    required this.stylistName,
    required this.maxAmount,
  });

  final String stylistId;
  final String stylistName;
  final int maxAmount;

  @override
  ConsumerState<_RegisterPayoutSheet> createState() =>
      _RegisterPayoutSheetState();
}

class _RegisterPayoutSheetState extends ConsumerState<_RegisterPayoutSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _refController;
  late final TextEditingController _noteController;
  late final TextEditingController _searchController;
  PayoutMethod _method = PayoutMethod.orangeMoney;
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
    _amountController = TextEditingController(
      text: widget.maxAmount > 0 ? '${widget.maxAmount}' : '',
    );
    _refController = TextEditingController();
    _noteController = TextEditingController();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
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
      _updateAmountAndNote(allItems, settledKeys);
    });
  }

  void _toggleSelectAll(
    List<DailyCommissionItem> filteredItems,
    List<DailyCommissionItem> allItems,
    Set<String> settledKeys,
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
      _updateAmountAndNote(allItems, settledKeys);
    });
  }

  void _updateAmountAndNote(
    List<DailyCommissionItem> allItems,
    Set<String> settledKeys,
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
      final finalAmount = widget.maxAmount > 0 && sum > widget.maxAmount
          ? widget.maxAmount
          : sum;
      _amountController.text = '$finalAmount';
    } else if (_selectedDateKeys.isEmpty) {
      _amountController.text = widget.maxAmount > 0
          ? '${widget.maxAmount}'
          : '0';
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
    final dailyAsync = ref.watch(
      stylistDailyCommissionsProvider(widget.stylistId),
    );
    final payoutsAsync = ref.watch(stylistPayoutsProvider(widget.stylistId));
    final settledPayouts =
        payoutsAsync.valueOrNull?.where((p) => p.isSettled).toList() ??
        const <PayoutRequest>[];

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enregistrer un versement',
                          style: AppTypography.sora(18, FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Règlement direct pour ${widget.stylistName}',
                          style: AppTypography.manrope(
                            13,
                            FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.maxAmount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tintGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Dû : ${Formatters.fcfa(widget.maxAmount)}',
                        style: AppTypography.sora(
                          12,
                          FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              if (widget.maxAmount <= 0)
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
                          'Toutes les commissions antérieures ont déjà été réglées (Dû restant : 0 F).',
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

              // 1. Sélection de la journée de commission
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

              // Si une date personnalisée a été choisie
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
                        onTap: () => setState(() => _customSelectedDate = null),
                        child: const Icon(
                          LucideIcons.x,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

              // Liste des journées filtrées avec commission uniquement
              dailyAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: AppLoader(compact: true)),
                ),
                error: (e, s) => const SizedBox.shrink(),
                data: (items) {
                  // Filtrer strictement les journées où il y a une commission
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
                              'Aucune commission sur cette période. Utilisez « Autre date… » si besoin.',
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
                      availableBalance: widget.maxAmount,
                      settledPayouts: settledPayouts,
                      allDays: commissionDays,
                    )) {
                      settledKeys.add(_dateKey(it.date));
                    }
                  }
                  final unpaidDays = commissionDays
                      .where((it) => !settledKeys.contains(_dateKey(it.date)))
                      .toList();

                  // Recherche dans les journées avec commission
                  final query = _searchController.text.trim().toLowerCase();
                  final filteredDays = commissionDays.where((it) {
                    if (query.isEmpty) return true;
                    return it.label.toLowerCase().contains(query) ||
                        '${it.date.day}'.contains(query);
                  }).toList();

                  final totalSelected = _calculateSelectedTotal(commissionDays);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Bouton / En-tête de la liste déroulante
                      InkWell(
                        onTap: () =>
                            setState(() => _isDropdownOpen = !_isDropdownOpen),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    border: Border.all(color: AppColors.border),
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
                                              color: AppColors.textSecondary,
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
                                              color: AppColors.textSecondary,
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
                                          separatorBuilder: (context, index) =>
                                              const Divider(
                                                height: 1,
                                                thickness: 1,
                                                color: AppColors.border,
                                              ),
                                          itemBuilder: (context, i) {
                                            final item = filteredDays[i];
                                            final isSelected = _selectedDateKeys
                                                .contains(_dateKey(item.date));
                                            final isSettled = settledKeys
                                                .contains(_dateKey(item.date));
                                            return _DaySelectionRow(
                                              item: item,
                                              isSelected: isSelected,
                                              isSettled: isSettled,
                                              onTap: isSettled
                                                  ? null
                                                  : () => _onToggleDay(
                                                      item,
                                                      commissionDays,
                                                      settledKeys,
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
                                        ),
                                        child: Text(
                                          unpaidDays.every(
                                                (d) => _selectedDateKeys
                                                    .contains(_dateKey(d.date)),
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
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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

              const SizedBox(height: 16),

              // 2. Montant versé
              AppInput(
                controller: _amountController,
                label: 'Montant versé (FCFA)',
                keyboardType: TextInputType.number,
                suffix: const Text(
                  'F',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Moyen de paiement
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

              // 4. Référence & Note
              AppInput(
                controller: _refController,
                label: 'Référence / N° de reçu (optionnel)',
                hint: 'Ex: TXN-Q7F42K',
              ),
              const SizedBox(height: 14),
              AppInput(
                controller: _noteController,
                label: 'Note / Remarque (optionnel)',
                hint: 'Ex: Commission de la journée',
              ),
              const SizedBox(height: 20),

              // 5. Bouton Enregistrer
              AppButton(
                label: widget.maxAmount <= 0
                    ? 'Toutes les commissions sont réglées'
                    : 'Enregistrer le versement',
                icon: widget.maxAmount <= 0
                    ? LucideIcons.checkCheck
                    : LucideIcons.check,
                onPressed: widget.maxAmount <= 0
                    ? null
                    : () {
                        final amount =
                            int.tryParse(_amountController.text.trim()) ?? 0;
                        if (amount <= 0) return;
                        if (amount > widget.maxAmount) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Le montant ne peut pas dépasser le dû restant (${Formatters.fcfa(widget.maxAmount)}).',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context, (
                          amount: amount,
                          method: _method,
                          ref: _refController.text.trim().isEmpty
                              ? null
                              : _refController.text.trim(),
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

class _DaySelectionRow extends StatelessWidget {
  const _DaySelectionRow({
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.isSettled = false,
  });

  final DailyCommissionItem item;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isSettled;

  @override
  Widget build(BuildContext context) {
    final hasCommission = item.commissionFcfa > 0;

    return InkWell(
      onTap: isSettled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSettled
                    ? AppColors.tintGreen
                    : isSelected
                    ? AppColors.accent
                    : (hasCommission ? Colors.white : AppColors.surfaceMuted),
                borderRadius: BorderRadius.circular(6),
                border: isSelected || isSettled
                    ? null
                    : Border.all(
                        color: hasCommission
                            ? AppColors.borderStrong
                            : AppColors.border,
                        width: 1.5,
                      ),
              ),
              alignment: Alignment.center,
              child: isSettled
                  ? const Icon(
                      LucideIcons.check,
                      size: 13,
                      color: AppColors.primary,
                    )
                  : isSelected
                  ? const Icon(LucideIcons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.label,
                        style: AppTypography.manrope(
                          13,
                          hasCommission ? FontWeight.w700 : FontWeight.w500,
                          color: isSettled
                              ? AppColors.textSecondary
                              : hasCommission
                              ? AppColors.textPrimary
                              : AppColors.textFaint,
                        ),
                      ),
                      if (isSettled) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tintGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Réglé',
                            style: AppTypography.manrope(
                              10,
                              FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    [
                      if (item.isCurrentDay) 'En cours',
                      '${item.serviceCount} prestations',
                      'CA ${Formatters.fcfa(item.revenueFcfa)}',
                    ].join(' · '),
                    style: AppTypography.manrope(
                      11,
                      FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              Formatters.fcfa(item.commissionFcfa),
              style: AppTypography.sora(
                13,
                FontWeight.w700,
                color: isSettled
                    ? AppColors.textSecondary
                    : hasCommission
                    ? AppColors.primary
                    : AppColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
