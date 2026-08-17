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

/// Périodes de l'écran Chiffre d'affaires (jour / semaine / mois).
enum FinancePeriod {
  day('Jour', 1, 6),
  week('Semaine', 7, 7),
  month('Mois', 30, 4),
  year('Année', 365, 12);

  const FinancePeriod(this.label, this.days, this.bucketCount);

  final String label;
  final int days;

  /// Nombre de colonnes de l'histogramme.
  final int bucketCount;

  ({DateTime from, DateTime to}) get range => rangeAt(0);

  /// Fenêtre décalée de [offset] période(s) : `-1` désigne la précédente.
  ///
  /// Le pas est la durée de la période elle-même — reculer d'un cran sur
  /// « Jour » donne la veille, sur « Mois » les trente jours d'avant.
  ({DateTime from, DateTime to}) rangeAt(int offset) {
    final now = DateTime.now();
    final endOfToday =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final end = endOfToday.add(Duration(days: days * offset));
    return (from: end.subtract(Duration(days: days)), to: end);
  }

  /// Libellé d'une colonne d'histogramme, d'après la date où elle commence.
  ///
  /// Les libellés renvoyés par la base sont génériques — « S1 », « S2 »… — et
  /// ne veulent rien dire sur une journée ou une année. On les redérive de la
  /// date réelle, à l'échelle affichée.
  String bucketLabel(DateTime start) => switch (this) {
        day => '${start.hour}h',
        week => Formatters.weekdayShort(start),
        month => Formatters.dayMonth(start),
        year => Formatters.monthShort(start),
      };

  /// Libellé de la fenêtre décalée, tel qu'affiché entre les deux flèches.
  String labelAt(int offset) {
    final range = rangeAt(offset);
    if (offset == 0) {
      return switch (this) {
        day => 'Aujourd\'hui',
        week => 'Cette semaine',
        month => 'Ce mois-ci',
        year => 'Cette année',
      };
    }
    if (this == day) {
      return offset == -1
          ? 'Hier'
          : Formatters.weekdayDayMonth(range.from);
    }
    // La borne haute est exclusive : afficher `to` donnerait un jour de trop.
    final last = range.to.subtract(const Duration(days: 1));
    return '${Formatters.dayMonth(range.from)} – ${Formatters.dayMonth(last)}';
  }
}

final financePeriodProvider =
    StateProvider<FinancePeriod>((ref) => FinancePeriod.month);

/// Décalage de la fenêtre affichée : `0` = période en cours, `-1` = précédente.
///
/// Jamais positif — il n'y a pas de chiffre d'affaires à venir.
final financePeriodOffsetProvider = StateProvider<int>((ref) => 0);

/// Fenêtre effectivement interrogée : la période choisie, décalée du nombre de
/// crans demandé. Centralisée ici pour que la synthèse, les commissions, les
/// dépenses et les rapports parlent tous de la même tranche de temps.
final financeRangeProvider = Provider<({DateTime from, DateTime to})>((ref) {
  return ref
      .watch(financePeriodProvider)
      .rangeAt(ref.watch(financePeriodOffsetProvider));
});

/// Synthèse du chiffre d'affaires sur la période sélectionnée.
final financeSummaryProvider = FutureProvider<FinanceSummary>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  final period = ref.watch(financePeriodProvider);
  final range = ref.watch(financeRangeProvider);

  if (salonId == null) {
    return FinanceSummary.empty(from: range.from, to: range.to);
  }

  return ref.watch(financeRepositoryProvider).fetchSummary(
        salonId: salonId,
        from: range.from,
        to: range.to,
        bucketCount: period.bucketCount,
      );
});

/// Rapport par coiffeur sur la période sélectionnée.
final commissionsProvider =
    FutureProvider<List<StylistCommission>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final range = ref.watch(financeRangeProvider);
  return ref.watch(financeRepositoryProvider).fetchCommissions(
        salonId: salonId,
        from: range.from,
        to: range.to,
      );
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
          speciality:
              member.specialties.isEmpty ? null : member.specialties.first,
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
final monthCommissionsProvider =
    FutureProvider<List<StylistCommission>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final now = DateTime.now();
  return ref.watch(financeRepositoryProvider).fetchCommissions(
        salonId: salonId,
        from: DateTime(now.year, now.month),
        to: DateTime(now.year, now.month + 1),
      );
});

/// Activité du mois par membre, indexée par identifiant de fiche.
final monthActivityByStylistProvider =
    Provider<Map<String, StylistCommission>>((ref) {
  final rows = ref.watch(monthCommissionsProvider).valueOrNull ?? const [];
  return {for (final row in rows) row.stylistId: row};
});

/// Commission du membre connecté sur le mois calendaire en cours.
///
/// Volontairement indépendante de `financePeriodProvider` : l'accueil du
/// coiffeur annonce « ma commission du mois », un repère de paie qui ne doit
/// pas changer parce qu'il a consulté ses commissions à la semaine ailleurs.
final myMonthCommissionProvider =
    FutureProvider<StylistCommission?>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (salonId == null || profile == null) return null;

  final now = DateTime.now();
  final rows = await ref.watch(financeRepositoryProvider).fetchCommissions(
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

  return ref.watch(financeRepositoryProvider).fetchPayouts(
        salonId: salonId,
        profileId: profile.id,
      );
});

/// Total déjà versé sur le mois en cours.
///
/// Daté du règlement et non de la demande : une demande de fin juillet réglée
/// le 2 août pèse sur août, comme dans un livre de paie.
final paidThisMonthProvider = Provider<int>((ref) {
  final payouts = ref.watch(myPayoutsProvider).valueOrNull ?? const [];
  final now = DateTime.now();

  return payouts
      .where((payout) =>
          payout.isSettled &&
          payout.paidAt != null &&
          payout.paidAt!.year == now.year &&
          payout.paidAt!.month == now.month)
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
  return ref.watch(financeRepositoryProvider).fetchPayouts(
        salonId: salonId,
        profileId: profileId,
      );
});

/// Solde et cumul des versements d'un coiffeur spécifique sur le mois.
final stylistPayoutBalanceProvider = Provider.family<
    ({int earned, int paid, int pending, int available}),
    ({String profileId, int earned})>((ref, arg) {
  final payouts =
      ref.watch(stylistPayoutsProvider(arg.profileId)).valueOrNull ?? const [];
  final now = DateTime.now();

  final paid = payouts
      .where((payout) =>
          payout.isSettled &&
          payout.paidAt != null &&
          payout.paidAt!.year == now.year &&
          payout.paidAt!.month == now.month)
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
      await _ref.read(financeRepositoryProvider).requestPayout(
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
      await _ref.read(financeRepositoryProvider).settlePayout(
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

  Future<bool> reject({
    required String requestId,
    String? reason,
  }) async {
    state = const AsyncLoading();
    try {
      await _ref.read(financeRepositoryProvider).rejectPayout(
            requestId: requestId,
            reason: reason,
          );
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
      await _ref.read(financeRepositoryProvider).createDirectPayout(
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
final servicePerformanceProvider =
    FutureProvider<List<ServicePerformance>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final range = ref.watch(financeRangeProvider);
  return ref.watch(financeRepositoryProvider).fetchServicePerformance(
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
  return ref.watch(financeRepositoryProvider).fetchExpenses(
        salonId: salonId,
        from: range.from,
        to: range.to,
      );
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

/// Libellés des colonnes de l'histogramme, datés plutôt que génériques.
final bucketLabelsProvider = Provider<List<String>>((ref) {
  final summary = ref.watch(financeSummaryProvider).valueOrNull;
  if (summary == null || summary.buckets.isEmpty) return const [];

  final period = ref.watch(financePeriodProvider);
  final range = ref.watch(financeRangeProvider);
  final count = summary.buckets.length;
  final span = range.to.difference(range.from);

  return [
    for (var i = 0; i < count; i++)
      period.bucketLabel(range.from.add(span * (i / count))),
  ];
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

/// Résultat net par sous-période, pour l'histogramme de l'écran dédié.
///
/// Le découpage reprend exactement celui de `fetchSummary` — la fenêtre
/// partagée en parts égales — sans quoi les colonnes du graphe ne
/// correspondraient pas aux montants du récapitulatif.
///
/// Les commissions sont interrogées tranche par tranche : elles dépendent du
/// taux de chaque coiffeur, donc les répartir au prorata du chiffre
/// d'affaires donnerait un résultat faux dès que deux taux diffèrent.
final netBucketsProvider =
    FutureProvider<List<({String label, int netFcfa})>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  final summary = ref.watch(financeSummaryProvider).valueOrNull;
  if (salonId == null || summary == null || summary.buckets.isEmpty) {
    return const [];
  }

  final range = ref.watch(financeRangeProvider);
  final expenses = ref.watch(expensesProvider).valueOrNull ?? const [];
  final count = summary.buckets.length;
  final span = range.to.difference(range.from);

  ({DateTime from, DateTime to}) sliceAt(int index) {
    final start = range.from.add(span * (index / count));
    final end = range.from.add(span * ((index + 1) / count));
    return (from: start, to: end);
  }

  final repository = ref.watch(financeRepositoryProvider);
  final commissionsPerSlice = await Future.wait([
    for (var i = 0; i < count; i++)
      repository
          .fetchCommissions(
            salonId: salonId,
            from: sliceAt(i).from,
            to: sliceAt(i).to,
          )
          .then((rows) => rows.fold<int>(0, (s, r) => s + r.commissionFcfa))
          // Une tranche en erreur ne doit pas vider tout le graphe.
          .catchError((_) => 0),
  ]);

  final period = ref.watch(financePeriodProvider);

  return [
    for (var i = 0; i < count; i++)
      (
        label: period.bucketLabel(sliceAt(i).from),
        netFcfa: summary.buckets[i].revenueFcfa -
            commissionsPerSlice[i] -
            expenses
                .where((e) =>
                    !e.spentAt.isBefore(sliceAt(i).from) &&
                    e.spentAt.isBefore(sliceAt(i).to))
                .fold<int>(0, (s, e) => s + e.amountFcfa),
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
    final end = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
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

final exportPeriodProvider =
    StateProvider<ExportPeriod>((ref) => ExportPeriod.quarter);

final exportFormatProvider =
    StateProvider<ExportFormat>((ref) => ExportFormat.xlsx);

/// Synthèse recettes / charges de la période d'export.
final exportSummaryProvider =
    FutureProvider<({int revenue, int expenses})>((ref) async {
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
