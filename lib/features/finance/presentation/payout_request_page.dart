import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/payout.dart';
import 'finance_providers.dart';

enum _PayoutTargetMethod {
  wave('Wave', LucideIcons.smartphone),
  orangeMoney('Orange Money', LucideIcons.smartphone),
  especes('Espèces', LucideIcons.banknote);

  const _PayoutTargetMethod(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _PayoutDayInfo {
  const _PayoutDayInfo({
    required this.item,
    required this.remainingFcfa,
    required this.settledFcfa,
    this.isCarriedOver = false,
  });

  final DailyCommissionItem item;
  final int remainingFcfa;
  final int settledFcfa;

  /// Ligne de repli : du solde reste dû, mais aucune journée de la fenêtre
  /// n'y correspond — une commission plus ancienne, ou plusieurs demandes le
  /// même jour.
  ///
  /// Son montant est réel ; son nombre de prestations et son chiffre
  /// d'affaires ne le sont pas. Le drapeau évite de les afficher comme s'ils
  /// venaient de vraies ventes.
  final bool isCarriedOver;

  bool get hasRemaining => remainingFcfa > 0;
  bool get hasSettled => settledFcfa > 0;
}

/// C3 — Demande de versement : sélection des commissions journalières et du mode de règlement.
class PayoutRequestPage extends ConsumerStatefulWidget {
  const PayoutRequestPage({super.key});

  static const routeName = '/finance/request-payout';

  @override
  ConsumerState<PayoutRequestPage> createState() => _PayoutRequestPageState();
}

class _PayoutRequestPageState extends ConsumerState<PayoutRequestPage> {
  final Set<String> _selectedDateKeys = {};
  _PayoutTargetMethod _selectedMethod = _PayoutTargetMethod.wave;
  bool _initialized = false;
  bool _tabChosen = false;
  bool _isSubmitting = false;
  int? _customAmount;
  int _currentTab = 0; // 0: À réclamer, 1: Déjà réglées
  String _searchQuery = '';

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Répartit les versements déjà faits sur les journées, de la plus ancienne
  /// à la plus récente.
  ///
  /// [totalSettledOrPending] porte **tous** les versements du membre, depuis
  /// l'ouverture. Or [items] ne couvre que les derniers jours. Dépenser le
  /// total sur cette seule fenêtre marquait comme réglées des journées
  /// récentes qui ne l'étaient pas : les versements anciens étaient imputés
  /// deux fois — une fois sur les commissions d'alors, déjà hors fenêtre, et
  /// une seconde sur celles d'aujourd'hui.
  ///
  /// D'où [earnedBeforeWindow] : la part du dû gagnée avant la fenêtre. Elle
  /// absorbe d'abord les versements, et seul le reliquat se répartit sur les
  /// journées affichées.
  List<_PayoutDayInfo> _computeDayInfos({
    required List<DailyCommissionItem> items,
    required int totalSettledOrPending,
    required int earnedBeforeWindow,
  }) {
    // Trier du plus ancien au plus récent (FIFO)
    final sorted = List<DailyCommissionItem>.from(items)
      ..sort((a, b) => a.date.compareTo(b.date));

    final windowTotal = sorted.fold<int>(0, (s, i) => s + i.commissionFcfa);
    final result = <_PayoutDayInfo>[];
    var budget = (totalSettledOrPending - earnedBeforeWindow).clamp(
      0,
      windowTotal,
    );

    for (final item in sorted) {
      if (item.commissionFcfa <= 0) continue;

      if (budget >= item.commissionFcfa) {
        result.add(
          _PayoutDayInfo(
            item: item,
            remainingFcfa: 0,
            settledFcfa: item.commissionFcfa,
          ),
        );
        budget -= item.commissionFcfa;
      } else if (budget > 0) {
        final settledForDay = budget;
        final remainingForDay = item.commissionFcfa - budget;
        result.add(
          _PayoutDayInfo(
            item: item,
            remainingFcfa: remainingForDay,
            settledFcfa: settledForDay,
          ),
        );
        budget = 0;
      } else {
        result.add(
          _PayoutDayInfo(
            item: item,
            remainingFcfa: item.commissionFcfa,
            settledFcfa: 0,
          ),
        );
      }
    }

    return result;
  }

  /// Coche les journées réclamables, une seule fois.
  ///
  /// Le verrou n'est posé **que** s'il y avait quelque chose à cocher. Le
  /// solde arrive une image après la liste — `payoutBalanceProvider` lit des
  /// sources encore en vol — et verrouiller sur une première liste vide
  /// laissait la ligne décochée et le bouton grisé, avec un montant pourtant
  /// disponible affiché juste au-dessus.
  void _initSelection(List<_PayoutDayInfo> availableDays) {
    if (_initialized || availableDays.isEmpty) return;
    _initialized = true;

    for (final d in availableDays) {
      _selectedDateKeys.add(_dateKey(d.item.date));
    }
  }

  int _calculateTotal(List<_PayoutDayInfo> availableDays) {
    var sum = 0;
    for (final d in availableDays) {
      if (_selectedDateKeys.contains(_dateKey(d.item.date))) {
        sum += d.remainingFcfa;
      }
    }
    return sum;
  }

  Future<void> _openAdjustAmountSheet({
    required BuildContext context,
    required int currentAmount,
    required int maxAvailable,
    required int autoAmount,
  }) async {
    final result = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AdjustPayoutAmountSheet(
        initialAmount: currentAmount,
        maxAvailable: maxAvailable,
        autoAmount: autoAmount,
      ),
    );

    if (result != null) {
      setState(() {
        if (result == autoAmount) {
          _customAmount = null;
        } else {
          _customAmount = result;
        }
      });
    }
  }

  Future<void> _submitRequest(
    int totalAmount,
    List<_PayoutDayInfo> availableDays,
  ) async {
    if (totalAmount <= 0) return;

    setState(() => _isSubmitting = true);

    final selectedLabels = availableDays
        .where((d) => _selectedDateKeys.contains(_dateKey(d.item.date)))
        .map((d) => d.item.label)
        .join(', ');
    final isCustom = _customAmount != null;
    final note = isCustom
        ? 'Avance (${Formatters.fcfa(totalAmount)}) · $selectedLabels · ${_selectedMethod.label}'
        : (selectedLabels.isNotEmpty
              ? 'Demande $selectedLabels · ${_selectedMethod.label}'
              : 'Paiement par ${_selectedMethod.label}');

    final ok = await ref
        .read(payoutRequestControllerProvider.notifier)
        .submit(amountFcfa: totalAmount, note: note);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      ref.invalidate(myDailyCommissionsProvider);
      ref.invalidate(myPayoutsProvider);
      ref.invalidate(payoutBalanceProvider);
      ref.invalidate(allPayoutsProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Demande de versement de ${Formatters.fcfa(totalAmount)} envoyée au gérant.',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.of(context).pop();
    } else {
      final error = ref.read(payoutRequestControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demande refusée : ${ErrorMessages.humanize(error)}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dailyItemsAsync = ref.watch(myDailyCommissionsProvider);
    final myPayouts =
        ref.watch(myPayoutsProvider).valueOrNull ?? const <PayoutRequest>[];
    final balance = ref.watch(payoutBalanceProvider);

    return dailyItemsAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: AppLoader()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: AppErrorState(message: '$err')),
      ),
      data: (items) {
        final totalSettledOrPending = myPayouts
            .where((p) => p.isSettled || p.status == PayoutStatus.pending)
            .fold<int>(0, (sum, p) => sum + p.amountFcfa);

        // Part du dû gagnée avant la fenêtre affichée : `balance.earned` est
        // cumulatif depuis l'ouverture, les journées ne couvrent que les
        // derniers jours. C'est elle qui absorbe les versements anciens.
        final windowEarned = items.fold<int>(
          0,
          (sum, i) => sum + i.commissionFcfa,
        );
        final earnedBeforeWindow = (balance.earned - windowEarned).clamp(
          0,
          balance.earned,
        );

        final dayInfos = _computeDayInfos(
          items: items,
          totalSettledOrPending: totalSettledOrPending,
          earnedBeforeWindow: earnedBeforeWindow,
        );

        final availableDays = dayInfos.where((d) => d.hasRemaining).toList();
        final settledDays = dayInfos.where((d) => d.hasSettled).toList();

        // Si du solde est disponible mais qu'aucune journée ne correspond dans la fenêtre
        // (ex: solde reporté ou demande multiple le même jour), on garantit que le montant
        // reste réclamable et sélectionné immédiatement sans blocage.
        if (balance.available > 0 && availableDays.isEmpty) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          availableDays.add(
            _PayoutDayInfo(
              item: DailyCommissionItem(
                date: today,
                label: 'Solde reporté',
                // Aucune vente connue derrière ce montant : ces deux champs
                // resteront masqués, le drapeau ci-dessous s'en charge.
                serviceCount: 0,
                revenueFcfa: 0,
                commissionFcfa: balance.available,
                isCurrentDay: false,
              ),
              remainingFcfa: balance.available,
              settledFcfa: 0,
              isCarriedOver: true,
            ),
          );
        }

        _initSelection(availableDays);

        // Le choix de l'onglet se décide à part, et une seule fois : lié au
        // verrou de sélection, il se rejouait à chaque image tant que rien
        // n'était réclamable — et ramenait l'utilisateur sur « Déjà réglées »
        // dès qu'il essayait d'en sortir.
        if (!_tabChosen &&
            (availableDays.isNotEmpty || settledDays.isNotEmpty)) {
          _tabChosen = true;
          if (availableDays.isEmpty) _currentTab = 1;
        }

        final selectedAmount = _calculateTotal(availableDays);
        final autoTotal = selectedAmount > balance.available
            ? balance.available
            : selectedAmount;
        final isCustom = _customAmount != null;
        // `clamp(1, 0)` lève une `ArgumentError` : la borne basse dépasse la
        // borne haute dès que le solde tombe à zéro. Le cas arrive vraiment —
        // une demande refusée laisse le montant saisi en place et reconstruit
        // l'écran, et le solde peut avoir été vidé entre-temps par le gérant.
        // Un écran rouge sur une demande de versement est le pire moment.
        final totalAmount = isCustom
            ? (balance.available <= 0
                  ? 0
                  : _customAmount!.clamp(1, balance.available))
            : autoTotal;
        final isCapped = !isCustom && selectedAmount > balance.available;
        final settledTotal = settledDays.fold<int>(
          0,
          (sum, d) => sum + d.settledFcfa,
        );

        final q = Formatters.searchable(_searchQuery.trim());
        final filteredAvailable = q.isEmpty
            ? availableDays
            : availableDays.where((d) {
                return Formatters.searchable(d.item.label).contains(q) ||
                    Formatters.searchable(
                      Formatters.dayMonth(d.item.date),
                    ).contains(q);
              }).toList();

        final filteredSettled = q.isEmpty
            ? settledDays
            : settledDays.where((d) {
                return Formatters.searchable(d.item.label).contains(q) ||
                    Formatters.searchable(
                      Formatters.dayMonth(d.item.date),
                    ).contains(q);
              }).toList();

        return AppScreen(
          title: 'Demande de versement',
          footer: _currentTab == 0
              ? AppButton(
                  label: isCustom
                      ? 'Demander l\'avance (${Formatters.fcfa(totalAmount)})'
                      : 'Envoyer la demande',
                  icon: LucideIcons.send,
                  isLoading: _isSubmitting,
                  onPressed: totalAmount > 0
                      ? () => _submitRequest(totalAmount, availableDays)
                      : null,
                )
              : AppButton(
                  label: availableDays.isNotEmpty
                      ? 'Faire une demande'
                      : 'Retour',
                  icon: availableDays.isNotEmpty
                      ? LucideIcons.send
                      : LucideIcons.arrowLeft,
                  onPressed: availableDays.isNotEmpty
                      ? () => setState(() => _currentTab = 0)
                      : () => Navigator.pop(context),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero Card sombre #17231C
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF17231C),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A17231C),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    Text(
                      _currentTab == 0
                          ? (isCustom
                                ? 'Avance demandée'
                                : 'Sélectionné à verser')
                          : 'Commissions déjà réglées',
                      style: AppTypography.manrope(
                        12,
                        FontWeight.w600,
                        color: const Color(0x99FFFFFF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.fcfa(
                        _currentTab == 0 ? totalAmount : settledTotal,
                      ),
                      style: AppTypography.sora(
                        32,
                        FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_currentTab == 0) ...[
                      Text(
                        balance.available > 0
                            ? '${Formatters.fcfa(balance.available)} disponibles au total'
                            : 'Toutes vos commissions ont été réglées',
                        style: AppTypography.manrope(
                          12,
                          FontWeight.w600,
                          color: balance.available > 0
                              ? const Color(0xCCFFFFFF)
                              : AppColors.primary,
                        ),
                      ),
                      if (balance.available > 0) ...[
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () => _openAdjustAmountSheet(
                            context: context,
                            currentAmount: totalAmount,
                            maxAvailable: balance.available,
                            autoAmount: autoTotal,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isCustom
                                  ? AppColors.amber.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isCustom
                                    ? AppColors.amber.withValues(alpha: 0.7)
                                    : Colors.white.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isCustom
                                      ? LucideIcons.badgeCheck
                                      : LucideIcons.pencil,
                                  size: 13,
                                  color: isCustom
                                      ? AppColors.amber
                                      : Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isCustom
                                      ? 'Avance personnalisée · Modifier'
                                      : 'Ajuster le montant (avance)',
                                  style: AppTypography.manrope(
                                    11.5,
                                    FontWeight.w700,
                                    color: isCustom
                                        ? AppColors.amber
                                        : Colors.white,
                                  ),
                                ),
                                if (isCustom) ...[
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () =>
                                        setState(() => _customAmount = null),
                                    child: const Icon(
                                      LucideIcons.x,
                                      size: 14,
                                      color: AppColors.amber,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (isCustom && balance.available > totalAmount) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Reste de ${Formatters.fcfa(balance.available - totalAmount)} disponible ce soir à la descente',
                            textAlign: TextAlign.center,
                            style: AppTypography.manrope(
                              11,
                              FontWeight.w600,
                              color: const Color(0xB3FFFFFF),
                            ),
                          ),
                        ],
                      ],
                      if (isCapped) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Plafonné au solde disponible (${Formatters.fcfa(balance.available)})',
                          textAlign: TextAlign.center,
                          style: AppTypography.manrope(
                            11.5,
                            FontWeight.w600,
                            color: AppColors.amber,
                          ),
                        ),
                      ],
                    ] else ...[
                      Text(
                        '${settledDays.length} journée(s) réglée(s)',
                        style: AppTypography.manrope(
                          12,
                          FontWeight.w600,
                          color: const Color(0xCCFFFFFF),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Onglets : À réclamer / Déjà réglées
              AppSegmented(
                boxed: true,
                items: [
                  'À réclamer (${availableDays.length})',
                  'Déjà réglées (${settledDays.length})',
                ],
                selectedIndex: _currentTab,
                onChanged: (index) => setState(() => _currentTab = index),
              ),
              const SizedBox(height: 14),

              // Champ de recherche si plusieurs journées
              if ((_currentTab == 0 && availableDays.length > 4) ||
                  (_currentTab == 1 && settledDays.length > 4)) ...[
                AppInput(
                  hint: 'Rechercher une journée...',
                  prefixIcon: LucideIcons.search,
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 12),
              ],

              // 3. Contenu de l'onglet actif
              if (_currentTab == 0) ...[
                // Onglet À réclamer
                if (availableDays.isEmpty) ...[
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 28,
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          LucideIcons.circleCheck,
                          size: 40,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Toutes vos commissions sont réglées',
                          style: AppTypography.sora(15, FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Aucun montant en attente de demande de versement.',
                          textAlign: TextAlign.center,
                          style: AppTypography.manrope(
                            12.5,
                            FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (settledDays.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          AppButton(
                            label:
                                'Voir les commissions réglées (${settledDays.length})',
                            variant: AppButtonVariant.outline,
                            onPressed: () => setState(() => _currentTab = 1),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Text(
                        'Commissions disponibles · par jour',
                        style: AppTypography.sora(
                          12.5,
                          FontWeight.w600,
                          color: AppColors.textBody,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _customAmount = null;
                            final allSelected = filteredAvailable.every(
                              (d) => _selectedDateKeys.contains(
                                _dateKey(d.item.date),
                              ),
                            );
                            if (allSelected) {
                              for (final d in filteredAvailable) {
                                _selectedDateKeys.remove(_dateKey(d.item.date));
                              }
                            } else {
                              for (final d in filteredAvailable) {
                                _selectedDateKeys.add(_dateKey(d.item.date));
                              }
                            }
                          });
                        },
                        child: Text(
                          filteredAvailable.every(
                                (d) => _selectedDateKeys.contains(
                                  _dateKey(d.item.date),
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A141E14),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < filteredAvailable.length; i++) ...[
                          _DayCommissionRow(
                            item: filteredAvailable[i].item,
                            amountFcfa: filteredAvailable[i].remainingFcfa,
                            settledAmountFcfa:
                                filteredAvailable[i].settledFcfa > 0
                                ? filteredAvailable[i].settledFcfa
                                : null,
                            isCarriedOver: filteredAvailable[i].isCarriedOver,
                            isSelected: _selectedDateKeys.contains(
                              _dateKey(filteredAvailable[i].item.date),
                            ),
                            onToggle: () {
                              final key = _dateKey(
                                filteredAvailable[i].item.date,
                              );
                              setState(() {
                                _customAmount = null;
                                if (_selectedDateKeys.contains(key)) {
                                  _selectedDateKeys.remove(key);
                                } else {
                                  _selectedDateKeys.add(key);
                                }
                              });
                            },
                          ),
                          if (i < filteredAvailable.length - 1)
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: AppColors.border,
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section Recevoir par
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 8),
                    child: Text(
                      'Recevoir par',
                      style: AppTypography.sora(
                        12.5,
                        FontWeight.w600,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final method in _PayoutTargetMethod.values) ...[
                        Expanded(
                          child: _MethodCard(
                            method: method,
                            isSelected: _selectedMethod == method,
                            onTap: () =>
                                setState(() => _selectedMethod = method),
                          ),
                        ),
                        if (method != _PayoutTargetMethod.values.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Encart d'information
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.tintGreenSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.tintGreenBorder),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          LucideIcons.info,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'La demande est envoyée au gérant, qui la valide et enregistre le versement.',
                            style: AppTypography.manrope(
                              12.5,
                              FontWeight.w500,
                              color: AppColors.textBody,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                // Onglet Déjà réglées
                if (filteredSettled.isEmpty) ...[
                  const AppEmptyState(
                    icon: LucideIcons.history,
                    title: 'Aucun versement',
                    message: 'Aucun versement enregistré pour l\'instant.',
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 8),
                    child: Text(
                      'Commissions déjà versées · historique',
                      style: AppTypography.sora(
                        12.5,
                        FontWeight.w600,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A141E14),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < filteredSettled.length; i++) ...[
                          _DayCommissionRow(
                            item: filteredSettled[i].item,
                            amountFcfa: filteredSettled[i].settledFcfa,
                            isSettled: true,
                          ),
                          if (i < filteredSettled.length - 1)
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: AppColors.border,
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.tintGreenSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.tintGreenBorder),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          LucideIcons.circleCheck,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ces journées ont déjà été versées par le gérant ou ont été incluses dans un règlement antérieur.',
                            style: AppTypography.manrope(
                              12.5,
                              FontWeight.w500,
                              color: AppColors.textBody,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _DayCommissionRow extends StatelessWidget {
  const _DayCommissionRow({
    required this.item,
    required this.amountFcfa,
    this.isSelected = false,
    this.isSettled = false,
    this.isCarriedOver = false,
    this.settledAmountFcfa,
    this.onToggle,
  });

  final DailyCommissionItem item;
  final int amountFcfa;
  final bool isSelected;
  final bool isSettled;
  final bool isCarriedOver;
  final int? settledAmountFcfa;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final isCurrent = item.isCurrentDay;

    return InkWell(
      onTap: isSettled ? null : onToggle,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            if (isSettled) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tintGreen,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.check,
                      size: 12,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Réglé',
                      style: AppTypography.manrope(
                        11,
                        FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? null
                      : Border.all(color: AppColors.borderStrong, width: 1.5),
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? const Icon(
                        LucideIcons.check,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: AppTypography.manrope(
                      13.5,
                      FontWeight.w700,
                      color: isSettled
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCarriedOver
                        // Le détail par prestation n'existe pas ici : dire d'où
                        // vient le montant vaut mieux qu'inventer « 1
                        // prestation · CA 45 000 F ».
                        ? 'Commissions antérieures à la période affichée'
                        : [
                            if (isCurrent) 'En cours',
                            '${item.serviceCount} prestation${item.serviceCount > 1 ? 's' : ''}',
                            if (settledAmountFcfa != null &&
                                settledAmountFcfa! > 0)
                              '${Formatters.fcfa(settledAmountFcfa!)} déjà versés'
                            else
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
              Formatters.fcfa(amountFcfa),
              style: AppTypography.sora(
                13.5,
                FontWeight.w700,
                color: isSettled
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  final _PayoutTargetMethod method;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tintGreen : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              method.icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 5),
            Text(
              method.label,
              style: AppTypography.sora(
                11.5,
                FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustPayoutAmountSheet extends StatefulWidget {
  const _AdjustPayoutAmountSheet({
    required this.initialAmount,
    required this.maxAvailable,
    required this.autoAmount,
  });

  final int initialAmount;
  final int maxAvailable;
  final int autoAmount;

  @override
  State<_AdjustPayoutAmountSheet> createState() =>
      _AdjustPayoutAmountSheetState();
}

class _AdjustPayoutAmountSheetState extends State<_AdjustPayoutAmountSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAmount.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setAmount(int val) {
    setState(() {
      _controller.text = val.toString();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentVal = int.tryParse(_controller.text.trim()) ?? 0;
    final remainingAfter = widget.maxAvailable - currentVal;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Poignée de glissement
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // En-tête
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ajuster le montant',
                        style: AppTypography.sora(17, FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Avance de journée ou montant personnalisé',
                        style: AppTypography.manrope(
                          12,
                          FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  color: AppColors.textSecondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Note explicative
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.tintGreen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.info,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vous pouvez demander une avance dans l\'après-midi (ex: 5 000 F). Le solde restant restera disponible pour votre demande à la descente ce soir.',
                      style: AppTypography.manrope(
                        11.5,
                        FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Saisie du montant
            AppInput(
              controller: _controller,
              label: 'Montant souhaité (FCFA)',
              hint: 'Ex: 5000',
              autofocus: true,
              keyboardType: TextInputType.number,
              suffix: const Text(
                'F',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onChanged: (_) {
                setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),

            // Raccourcis rapides
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PresetChip(
                  label: 'Tout (${Formatters.fcfa(widget.maxAvailable)})',
                  onTap: () => _setAmount(widget.maxAvailable),
                ),
                if (widget.maxAvailable >= 4000)
                  _PresetChip(
                    label:
                        '50% (${Formatters.fcfa((widget.maxAvailable * 0.5).round())})',
                    onTap: () =>
                        _setAmount((widget.maxAvailable * 0.5).round()),
                  ),
                if (widget.maxAvailable >= 10000)
                  _PresetChip(
                    label:
                        '25% (${Formatters.fcfa((widget.maxAvailable * 0.25).round())})',
                    onTap: () =>
                        _setAmount((widget.maxAvailable * 0.25).round()),
                  ),
                if (widget.autoAmount != widget.maxAvailable &&
                    widget.autoAmount > 0)
                  _PresetChip(
                    label: 'Sélection (${Formatters.fcfa(widget.autoAmount)})',
                    onTap: () => _setAmount(widget.autoAmount),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Calcul du reste pour le soir
            if (currentVal > 0 && currentVal <= widget.maxAvailable) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      remainingAfter > 0
                          ? LucideIcons.moon
                          : LucideIcons.checkCheck,
                      size: 14,
                      color: remainingAfter > 0
                          ? AppColors.amber
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        remainingAfter > 0
                            ? 'Reste à percevoir à la descente : ${Formatters.fcfa(remainingAfter)}'
                            : 'Totalité du solde perçue',
                        style: AppTypography.manrope(
                          12,
                          FontWeight.w600,
                          color: remainingAfter > 0
                              ? AppColors.textPrimary
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (_error != null) ...[
              Text(
                _error!,
                style: AppTypography.manrope(
                  12,
                  FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Bouton de validation
            AppButton(
              label: 'Valider ce montant',
              icon: LucideIcons.check,
              onPressed: () {
                final val = int.tryParse(_controller.text.trim()) ?? 0;
                if (val <= 0) {
                  setState(
                    () => _error = 'Veuillez saisir un montant supérieur à 0.',
                  );
                  return;
                }
                if (val > widget.maxAvailable) {
                  setState(
                    () => _error =
                        'Le montant ne peut pas dépasser le solde disponible (${Formatters.fcfa(widget.maxAvailable)}).',
                  );
                  return;
                }
                Navigator.pop(context, val);
              },
            ),
            if (widget.initialAmount != widget.autoAmount) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, widget.autoAmount),
                child: Text(
                  'Réinitialiser au montant automatique (${Formatters.fcfa(widget.autoAmount)})',
                  style: AppTypography.manrope(
                    12,
                    FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.manrope(
            11,
            FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
