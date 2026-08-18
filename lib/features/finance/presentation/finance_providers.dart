import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../staff/presentation/staff_providers.dart';
import '../data/finance_repository.dart';
import '../domain/finance_summary.dart';
import '../domain/payout.dart';

import '../../../core/services/local_db_service.dart';

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localDbServiceProvider),
  ),
);

/// Périodes de l'écran Chiffre d'affaires, alignées sur le calendrier.
///
/// Fenêtres **calendaires** et non glissantes : « Mois » désigne août, du 1er
/// au 31, et non les trente derniers jours. C'est ce qu'attend une
/// comptabilité, et ce que le gérant compare d'un mois sur l'autre.
enum FinancePeriod {
  day('Jour'),
  week('Semaine'),
  month('Mois'),
  year('Année');

  const FinancePeriod(this.label);

  final String label;

  /// Fenêtre calendaire contenant [anchor].
  ({DateTime from, DateTime to}) rangeFor(DateTime anchor) {
    switch (this) {
      case day:
        final from = DateTime(anchor.year, anchor.month, anchor.day);
        return (from: from, to: from.add(const Duration(days: 1)));
      case week:
        // `weekday` vaut 1 le lundi : la semaine commence donc au lundi.
        final start = DateTime(
          anchor.year,
          anchor.month,
          anchor.day,
        ).subtract(Duration(days: anchor.weekday - 1));
        return (from: start, to: start.add(const Duration(days: 7)));
      case month:
        return (
          from: DateTime(anchor.year, anchor.month),
          to: DateTime(anchor.year, anchor.month + 1),
        );
      case year:
        return (from: DateTime(anchor.year), to: DateTime(anchor.year + 1));
    }
  }

  /// Déplace l'ancre de [steps] périodes : un jour, une semaine, un mois ou
  /// une année, selon l'échelle.
  DateTime shift(DateTime anchor, int steps) => switch (this) {
    day => anchor.add(Duration(days: steps)),
    week => anchor.add(Duration(days: 7 * steps)),
    // Le jour 1 évite qu'un 31 mars reculé d'un mois tombe en mars.
    month => DateTime(anchor.year, anchor.month + steps, 1),
    year => DateTime(anchor.year + steps, anchor.month, 1),
  };

  /// Titre de la fenêtre, tel qu'affiché au-dessus du montant.
  String titleFor(DateTime anchor) {
    final now = DateTime.now();
    switch (this) {
      case day:
        final isToday =
            anchor.year == now.year &&
            anchor.month == now.month &&
            anchor.day == now.day;
        return isToday ? "aujourd'hui" : Formatters.weekdayDayMonth(anchor);
      case week:
        final range = rangeFor(anchor);
        final isThisWeek = rangeFor(now).from == range.from;
        if (isThisWeek) return 'cette semaine';
        final last = range.to.subtract(const Duration(days: 1));
        return '${Formatters.dayMonth(range.from)} – '
            '${Formatters.dayMonth(last)}';
      case month:
        return '${Formatters.monthName(anchor)} ${anchor.year}';
      case year:
        return '${anchor.year}';
    }
  }

  /// Sous-périodes de l'histogramme, avec leur libellé.
  ///
  /// Elles ne découpent pas la fenêtre affichée mais la **replacent dans son
  /// contexte** : une journée se lit dans sa semaine, un mois dans son année.
  /// C'est ce qui permet de comparer.
  List<({DateTime from, DateTime to, String label})> chartBuckets(
    DateTime anchor,
  ) {
    switch (this) {
      case day:
      case week:
        final start = DateTime(
          anchor.year,
          anchor.month,
          anchor.day,
        ).subtract(Duration(days: anchor.weekday - 1));
        // La journée s'observe du lundi au vendredi — l'activité de semaine ;
        // la semaine complète va jusqu'au dimanche.
        final count = this == day ? 5 : 7;
        return [
          for (var i = 0; i < count; i++)
            (
              from: start.add(Duration(days: i)),
              to: start.add(Duration(days: i + 1)),
              label: Formatters.weekdayShort(start.add(Duration(days: i))),
            ),
        ];
      case month:
        return [
          for (var m = 1; m <= 12; m++)
            (
              from: DateTime(anchor.year, m),
              to: DateTime(anchor.year, m + 1),
              label: Formatters.monthInitial(DateTime(anchor.year, m)),
            ),
        ];
      case year:
        // Quatre exercices : de quoi lire une tendance sans écraser l'échelle.
        final first = anchor.year - 3;
        return [
          for (var y = first; y <= anchor.year; y++)
            (from: DateTime(y), to: DateTime(y + 1), label: '$y'),
        ];
    }
  }

  /// Indice de la tranche qui contient [anchor], pour la mettre en avant.
  int highlightIndexFor(DateTime anchor) {
    final buckets = chartBuckets(anchor);
    return buckets.indexWhere(
      (b) => !anchor.isBefore(b.from) && anchor.isBefore(b.to),
    );
  }

  /// Nomme la période de comparaison : « vs juillet » plutôt que « vs période
  /// précédente », qui n'apprend rien.
  String previousLabelFor(DateTime anchor) {
    final previous = shift(anchor, -1);
    return switch (this) {
      day => 'vs hier',
      week => 'vs semaine dernière',
      month => 'vs ${Formatters.monthName(previous)}',
      year => 'vs ${previous.year}',
    };
  }

  /// `true` si l'échelle se prête à un choix d'année.
  bool get hasYearPicker => this == month || this == year;
}

final financePeriodProvider = StateProvider<FinancePeriod>(
  (ref) => FinancePeriod.month,
);

/// Date de référence : la journée, la semaine, le mois ou l'année regardée.
final financeAnchorProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Années proposées dans le sélecteur, de la plus récente à la plus ancienne.
final financeYearsProvider = Provider<List<int>>((ref) {
  final current = DateTime.now().year;
  return [for (var y = current; y >= current - 3; y--) y];
});

/// Fenêtre effectivement interrogée : la période choisie, décalée du nombre de
/// crans demandé. Centralisée ici pour que la synthèse, les commissions, les
/// dépenses et les rapports parlent tous de la même tranche de temps.
final financeRangeProvider = Provider<({DateTime from, DateTime to})>((ref) {
  return ref
      .watch(financePeriodProvider)
      .rangeFor(ref.watch(financeAnchorProvider));
});

/// Synthèse du chiffre d'affaires sur la période sélectionnée.
final financeSummaryProvider = FutureProvider<FinanceSummary>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  final range = ref.watch(financeRangeProvider);

  if (salonId == null) {
    return FinanceSummary.empty(from: range.from, to: range.to);
  }

  // Comparaison calendaire : le mois précédent, pas « les trente jours
  // d'avant ». C'est ce que le badge annonce — « vs juillet ».
  final period = ref.watch(financePeriodProvider);
  final anchor = ref.watch(financeAnchorProvider);
  final previous = period.rangeFor(period.shift(anchor, -1));

  return ref
      .watch(financeRepositoryProvider)
      .fetchSummary(
        salonId: salonId,
        from: range.from,
        to: range.to,
        previousFrom: previous.from,
        previousTo: previous.to,
      );
});

/// Rapport par coiffeur sur la période sélectionnée.
final commissionsProvider = FutureProvider<List<StylistCommission>>((
  ref,
) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final range = ref.watch(financeRangeProvider);
  return ref
      .watch(financeRepositoryProvider)
      .fetchCommissions(salonId: salonId, from: range.from, to: range.to);
});

/// Rapport « Par coiffeur » complété de toute l'équipe.
///
/// `stylist_commissions` se construit à partir des ventes : un coiffeur qui
/// n'a rien encaissé sur la période n'y a aucune ligne, et disparaît donc du
/// rapport. Un nouvel arrivant semblait ne pas exister, et une commission
/// attribuée par erreur à quelqu'un d'autre restait invisible faute de point
/// de comparaison. On complète donc avec les membres affectables, à zéro.
final stylistReportProvider = Provider<List<StylistCommission>>((ref) {
  final earned = ref.watch(commissionsProvider).valueOrNull ?? const [];
  final team = ref.watch(stylistsProvider).valueOrNull ?? const [];

  final byId = {for (final row in earned) row.stylistId: row};

  final rows = [
    ...earned,
    for (final member in team)
      if (!byId.containsKey(member.id))
        StylistCommission(
          stylistId: member.id,
          stylistName: member.fullName,
          revenueFcfa: 0,
          commissionFcfa: 0,
          serviceCount: 0,
          commissionRate: member.commissionRate,
          speciality: member.specialties.isEmpty
              ? null
              : member.specialties.first,
        ),
  ];

  // Les plus productifs d'abord, les inactifs de la période en fin de liste.
  rows.sort((a, b) => b.revenueFcfa.compareTo(a.revenueFcfa));
  return rows;
});

/// Commissions de toute l'équipe sur le mois calendaire en cours.
///
/// Indépendante de `financePeriodProvider` : les écrans du personnel parlent
/// du mois, pas de la période choisie dans Finance. Chargée une fois pour
/// toute la liste, plutôt qu'un appel par membre.
final monthCommissionsProvider = FutureProvider<List<StylistCommission>>((
  ref,
) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final now = DateTime.now();
  return ref
      .watch(financeRepositoryProvider)
      .fetchCommissions(
        salonId: salonId,
        from: DateTime(now.year, now.month),
        to: DateTime(now.year, now.month + 1),
      );
});

/// Activité du mois par membre, indexée par identifiant de fiche.
final monthActivityByStylistProvider = Provider<Map<String, StylistCommission>>(
  (ref) {
    final rows = ref.watch(monthCommissionsProvider).valueOrNull ?? const [];
    return {for (final row in rows) row.stylistId: row};
  },
);

/// Commission du membre connecté sur le mois calendaire en cours.
///
/// Volontairement indépendante de `financePeriodProvider` : l'accueil du
/// coiffeur annonce « ma commission du mois », un repère de paie qui ne doit
/// pas changer parce qu'il a consulté ses commissions à la semaine ailleurs.
final myMonthCommissionProvider = FutureProvider<StylistCommission?>((
  ref,
) async {
  final salonId = ref.watch(currentSalonIdProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (salonId == null || profile == null) return null;

  final now = DateTime.now();
  final rows = await ref
      .watch(financeRepositoryProvider)
      .fetchCommissions(
        salonId: salonId,
        from: DateTime(now.year, now.month),
        to: DateTime(now.year, now.month + 1),
      );

  for (final row in rows) {
    if (row.stylistId == profile.id) return row;
  }
  return null;
});

/// Demandes de versement du membre connecté, la plus récente d'abord.
final myPayoutsProvider = FutureProvider<List<PayoutRequest>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (salonId == null || profile == null) return const [];

  return ref
      .watch(financeRepositoryProvider)
      .fetchPayouts(salonId: salonId, profileId: profile.id);
});

/// Total déjà versé sur le mois en cours.
///
/// Daté du règlement et non de la demande : une demande de fin juillet réglée
/// le 2 août pèse sur août, comme dans un livre de paie.
final paidThisMonthProvider = Provider<int>((ref) {
  final payouts = ref.watch(myPayoutsProvider).valueOrNull ?? const [];
  final now = DateTime.now();

  return payouts
      .where(
        (payout) =>
            payout.isSettled &&
            payout.paidAt != null &&
            payout.paidAt!.year == now.year &&
            payout.paidAt!.month == now.month,
      )
      .fold(0, (sum, payout) => sum + payout.amountFcfa);
});

/// Reste dû sur le mois : commission acquise moins ce qui a déjà été versé,
/// moins ce qui est déjà demandé et attend le gérant.
final payoutBalanceProvider =
    Provider<({int earned, int paid, int pending, int available})>((ref) {
      final earned =
          ref.watch(myMonthCommissionProvider).valueOrNull?.commissionFcfa ?? 0;
      final paid = ref.watch(paidThisMonthProvider);
      final pending = (ref.watch(myPayoutsProvider).valueOrNull ?? const [])
          .where((payout) => payout.status == PayoutStatus.pending)
          .fold(0, (sum, payout) => sum + payout.amountFcfa);

      return (
        earned: earned,
        paid: paid,
        pending: pending,
        // Jamais négatif : une avance dépassant la commission du mois ne doit pas
        // afficher un « à recevoir » en rouge côté employé.
        available: (earned - paid - pending).clamp(0, earned),
      );
    });

/// Toutes les demandes de versement du salon (vue gérant).
final allPayoutsProvider = FutureProvider<List<PayoutRequest>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(financeRepositoryProvider).fetchPayouts(salonId: salonId);
});

/// Demandes et versements d'un membre spécifique (vue gérant).
final stylistPayoutsProvider =
    FutureProvider.family<List<PayoutRequest>, String>((ref, profileId) async {
      final salonId = ref.watch(currentSalonIdProvider);
      if (salonId == null) return const [];
      return ref
          .watch(financeRepositoryProvider)
          .fetchPayouts(salonId: salonId, profileId: profileId);
    });

/// Solde et cumul des versements d'un coiffeur spécifique sur le mois.
final stylistPayoutBalanceProvider =
    Provider.family<
      ({int earned, int paid, int pending, int available}),
      ({String profileId, int earned})
    >((ref, arg) {
      final payouts =
          ref.watch(stylistPayoutsProvider(arg.profileId)).valueOrNull ??
          const [];
      final now = DateTime.now();

      final paid = payouts
          .where(
            (payout) =>
                payout.isSettled &&
                payout.paidAt != null &&
                payout.paidAt!.year == now.year &&
                payout.paidAt!.month == now.month,
          )
          .fold(0, (sum, payout) => sum + payout.amountFcfa);

      final pending = payouts
          .where((payout) => payout.status == PayoutStatus.pending)
          .fold(0, (sum, payout) => sum + payout.amountFcfa);

      return (
        earned: arg.earned,
        paid: paid,
        pending: pending,
        available: (arg.earned - paid - pending).clamp(0, arg.earned),
      );
    });

/// Dépose ou gère une demande de versement.
final payoutRequestControllerProvider =
    StateNotifierProvider<PayoutRequestController, AsyncValue<void>>(
      PayoutRequestController.new,
    );

class PayoutRequestController extends StateNotifier<AsyncValue<void>> {
  PayoutRequestController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<bool> submit({
    int? amountFcfa,
    String? profileId,
    String? note,
  }) async {
    state = const AsyncLoading();
    try {
      await _ref
          .read(financeRepositoryProvider)
          .requestPayout(
            amountFcfa: amountFcfa,
            profileId: profileId,
            note: note,
          );
      _invalidateAll();
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }

  Future<bool> settle({
    required String requestId,
    required PayoutMethod method,
    String? reference,
  }) async {
    state = const AsyncLoading();
    try {
      await _ref
          .read(financeRepositoryProvider)
          .settlePayout(
            requestId: requestId,
            method: method,
            reference: reference,
          );
      _invalidateAll();
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }

  Future<bool> reject({required String requestId, String? reason}) async {
    state = const AsyncLoading();
    try {
      await _ref
          .read(financeRepositoryProvider)
          .rejectPayout(requestId: requestId, reason: reason);
      _invalidateAll();
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }

  Future<bool> createDirect({
    required String profileId,
    required int amountFcfa,
    required PayoutMethod method,
    String? reference,
    String? note,
  }) async {
    final salonId = _ref.read(currentSalonIdProvider);
    if (salonId == null) return false;

    state = const AsyncLoading();
    try {
      await _ref
          .read(financeRepositoryProvider)
          .createDirectPayout(
            salonId: salonId,
            profileId: profileId,
            amountFcfa: amountFcfa,
            method: method,
            reference: reference,
            note: note,
          );
      _invalidateAll();
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }

  void _invalidateAll() {
    _ref.invalidate(myPayoutsProvider);
    _ref.invalidate(allPayoutsProvider);
  }
}

/// Rapport par service sur la période sélectionnée.
final servicePerformanceProvider = FutureProvider<List<ServicePerformance>>((
  ref,
) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final range = ref.watch(financeRangeProvider);
  return ref
      .watch(financeRepositoryProvider)
      .fetchServicePerformance(
        salonId: salonId,
        from: range.from,
        to: range.to,
      );
});

/// Dépenses de la période sélectionnée.
final expensesProvider = FutureProvider<List<Expense>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final range = ref.watch(financeRangeProvider);
  return ref
      .watch(financeRepositoryProvider)
      .fetchExpenses(salonId: salonId, from: range.from, to: range.to);
});

/// Total des charges de la période.
final expensesTotalProvider = Provider<int>((ref) {
  final expenses = ref.watch(expensesProvider).valueOrNull ?? const [];
  return expenses.fold(0, (sum, expense) => sum + expense.amountFcfa);
});

/// Commissions dues à l'équipe sur la période.
///
/// Calculées depuis le rapport par coiffeur plutôt que depuis
/// `FinanceSummary.commissionsFcfa`, qui est déclaré mais jamais renseigné :
/// aucun des deux chemins de `fetchSummary` ne l'alimente.
final periodCommissionsProvider = Provider<int>((ref) {
  final rows = ref.watch(commissionsProvider).valueOrNull ?? const [];
  return rows.fold<int>(0, (sum, row) => sum + row.commissionFcfa);
});

/// Résultat net de la période : CA encaissé, moins les commissions dues à
/// l'équipe, moins les charges.
///
/// Les commissions manquaient au calcul. Or c'est la première dépense d'un
/// salon : un « résultat net » qui les ignore surestime largement ce qui
/// reste réellement au gérant.
final netResultProvider = Provider<int>((ref) {
  final int revenue =
      ref.watch(financeSummaryProvider).valueOrNull?.revenueFcfa ?? 0;
  final int commissions = ref.watch(periodCommissionsProvider);
  final int expenses = ref.watch(expensesTotalProvider);

  return revenue - commissions - expenses;
});

/// Marge nette de la période, en pourcentage du chiffre d'affaires.
///
/// `null` sans chiffre d'affaires : une marge n'a pas de sens sur zéro, et
/// afficher « 0 % » laisserait croire à une activité sans rentabilité plutôt
/// qu'à une absence d'activité.
final netMarginProvider = Provider<int?>((ref) {
  final revenue =
      ref.watch(financeSummaryProvider).valueOrNull?.revenueFcfa ?? 0;
  if (revenue <= 0) return null;

  return (ref.watch(netResultProvider) / revenue * 100).round();
});

/// Colonnes de l'histogramme : chiffre d'affaires et résultat net par tranche.
///
/// Les tranches viennent de `chartBuckets` : elles replacent la fenêtre dans
/// son contexte — une journée dans sa semaine, un mois dans son année — plutôt
/// que de la découper. C'est ce qui permet de comparer.
///
/// Un seul provider pour les deux graphes : l'écran Finance montre le CA, le
/// Résultat net montre le net, mais les colonnes doivent être les mêmes.
final financeBucketsProvider =
    FutureProvider<
      List<({String label, int revenueFcfa, int netFcfa, bool isCurrent})>
    >((ref) async {
      final salonId = ref.watch(currentSalonIdProvider);
      if (salonId == null) return const [];

      final period = ref.watch(financePeriodProvider);
      final anchor = ref.watch(financeAnchorProvider);
      final buckets = period.chartBuckets(anchor);
      final current = period.highlightIndexFor(anchor);

      final repository = ref.watch(financeRepositoryProvider);
      final totals = await repository.fetchBucketTotals(
        salonId: salonId,
        buckets: [for (final b in buckets) (from: b.from, to: b.to)],
      );
      if (totals.length != buckets.length) return const [];

      // Les charges couvrent tout l'intervalle affiché, qui déborde souvent la
      // fenêtre du récapitulatif : elles sont donc lues à part.
      final expenses = await repository.fetchExpenses(
        salonId: salonId,
        from: buckets.first.from,
        to: buckets.last.to,
      );

      return [
        for (var i = 0; i < buckets.length; i++)
          (
            label: buckets[i].label,
            revenueFcfa: totals[i].revenueFcfa,
            netFcfa:
                totals[i].revenueFcfa -
                totals[i].commissionFcfa -
                expenses
                    .where(
                      (e) =>
                          !e.spentAt.isBefore(buckets[i].from) &&
                          e.spentAt.isBefore(buckets[i].to),
                    )
                    .fold<int>(0, (sum, e) => sum + e.amountFcfa),
            isCurrent: i == current,
          ),
      ];
    });

// --- Export comptable -----------------------------------------------------

enum ExportPeriod {
  month('Mois', 30),
  quarter('Trimestre', 92),
  year('Année', 365);

  const ExportPeriod(this.label, this.days);

  final String label;
  final int days;

  ({DateTime from, DateTime to}) get range {
    final now = DateTime.now();
    final end = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    return (from: end.subtract(Duration(days: days)), to: end);
  }
}

enum ExportFormat {
  xlsx('xlsx', 'Fichier Excel (.xlsx)', 'Détail ligne par ligne'),
  pdf('pdf', 'Document PDF', 'Synthèse pour le comptable');

  const ExportFormat(this.value, this.label, this.description);

  final String value;
  final String label;
  final String description;
}

final exportPeriodProvider = StateProvider<ExportPeriod>(
  (ref) => ExportPeriod.quarter,
);

final exportFormatProvider = StateProvider<ExportFormat>(
  (ref) => ExportFormat.xlsx,
);

/// Synthèse recettes / charges de la période d'export.
final exportSummaryProvider = FutureProvider<({int revenue, int expenses})>((
  ref,
) async {
  final salonId = ref.watch(currentSalonIdProvider);
  final range = ref.watch(exportPeriodProvider).range;
  if (salonId == null) return (revenue: 0, expenses: 0);

  final repository = ref.watch(financeRepositoryProvider);
  final summary = await repository.fetchSummary(
    salonId: salonId,
    from: range.from,
    to: range.to,
  );
  final expenses = await repository.fetchExpenses(
    salonId: salonId,
    from: range.from,
    to: range.to,
  );

  return (
    revenue: summary.revenueFcfa,
    expenses: expenses.fold<int>(0, (sum, e) => sum + e.amountFcfa),
  );
});
