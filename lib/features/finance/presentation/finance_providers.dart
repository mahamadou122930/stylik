import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../home/presentation/home_providers.dart';
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
        // Jusqu'à quatre exercices, sans jamais remonter avant le premier :
        // des colonnes forcément vides fausseraient la lecture.
        final first = [
          anchor.year - 3,
          financeFirstYear,
        ].reduce((a, b) => a > b ? a : b);
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

/// Premier exercice du salon.
///
/// Les sélecteurs d'année et l'histogramme s'arrêtaient trois ans en arrière,
/// quelle que soit l'ancienneté du salon : on proposait donc 2023 et 2024, qui
/// ne peuvent contenir que des zéros. Une colonne vide n'est pas une
/// information, elle écrase l'échelle des autres et fait douter du calcul.
///
/// Constante plutôt que dérivée de la date de création du salon : la table
/// `salons` ne l'expose pas dans le modèle. Le jour où elle le fera, c'est
/// cette valeur qu'il faudra remplacer.
const int financeFirstYear = 2026;

/// Années proposées dans le sélecteur, de la plus récente à la plus ancienne.
final financeYearsProvider = Provider<List<int>>((ref) {
  final current = DateTime.now().year;
  // L'année en cours reste proposée même si l'horloge de l'appareil précède le
  // premier exercice : mieux vaut une année que zéro.
  final first = current < financeFirstYear ? current : financeFirstYear;
  return [for (var y = current; y >= first; y--) y];
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

/// Commissions cumulées de toute l'équipe, depuis le premier exercice.
///
/// Le solde réclamable n'est pas mensuel : une commission de juillet jamais
/// réglée reste due en août. Bornée au mois courant, la fenêtre la faisait
/// disparaître le 1er du mois — et laissait à l'inverse rattraper deux fois le
/// même dû à cheval sur un changement de mois.
final cumulativeCommissionsProvider = FutureProvider<List<StylistCommission>>((
  ref,
) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final now = DateTime.now();
  return ref
      .watch(financeRepositoryProvider)
      .fetchCommissions(
        salonId: salonId,
        from: DateTime(financeFirstYear),
        // Fin du mois courant : les ventes du jour comptent.
        to: DateTime(now.year, now.month + 1),
      );
});

/// Commission cumulée d'un membre, tous mois confondus.
final cumulativeCommissionForProvider = Provider.family<int, String>((
  ref,
  profileId,
) {
  final rows = ref.watch(cumulativeCommissionsProvider).valueOrNull ?? const [];
  for (final row in rows) {
    if (row.stylistId == profileId) return row.commissionFcfa;
  }
  return 0;
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

/// Reste dû sur le mois : commission acquise moins ce qui a déjà été versé,
/// moins ce qui est déjà demandé et attend le gérant.
final payoutBalanceProvider =
    Provider<({int earned, int paid, int pending, int available})>((ref) {
      final profile = ref.watch(currentProfileProvider).valueOrNull;
      // Cumulatif des deux côtés : tout ce qui a été gagné, moins tout ce qui
      // a été versé. Comparer une commission du mois à des versements du mois
      // effaçait le dû des mois précédents.
      final earned = profile == null
          ? 0
          : ref.watch(cumulativeCommissionForProvider(profile.id));

      final payouts = ref.watch(myPayoutsProvider).valueOrNull ?? const [];
      final paid = payouts
          .where((payout) => payout.isSettled)
          .fold(0, (sum, payout) => sum + payout.amountFcfa);
      final pending = payouts
          .where((payout) => payout.status == PayoutStatus.pending)
          .fold(0, (sum, payout) => sum + payout.amountFcfa);

      return (
        earned: earned,
        paid: paid,
        pending: pending,
        // Jamais négatif : une avance ne doit pas afficher un « à recevoir »
        // en rouge côté employé.
        available: (earned - paid - pending).clamp(0, earned),
      );
    });

/// Toutes les demandes de versement du salon (vue gérant).
final allPayoutsProvider = FutureProvider<List<PayoutRequest>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(financeRepositoryProvider).fetchPayouts(salonId: salonId);
});

/// Montant déjà versé à chaque coiffeur **sur la période affichée**.
///
/// Calé sur `financeRangeProvider`, comme le chiffre d'affaires et la
/// commission de la même carte : les trois colonnes doivent parler du même
/// mois. Un total « versé » depuis toujours, à côté d'une commission d'août,
/// laisserait croire à un solde alors qu'il compare deux périodes.
///
/// Seules les demandes réglées comptent : une demande en attente n'a rien mis
/// dans la poche du coiffeur.
final paidByStylistProvider = Provider<Map<String, int>>((ref) {
  final payouts = ref.watch(allPayoutsProvider).valueOrNull ?? const [];
  final range = ref.watch(financeRangeProvider);

  final totals = <String, int>{};
  for (final payout in payouts) {
    final paidAt = payout.paidAt;
    if (!payout.isSettled || paidAt == null) continue;
    if (paidAt.isBefore(range.from) || !paidAt.isBefore(range.to)) continue;

    totals[payout.profileId] =
        (totals[payout.profileId] ?? 0) + payout.amountFcfa;
  }
  return totals;
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

/// Solde cumulé d'un coiffeur : ce qui lui reste réellement dû.
final stylistPayoutBalanceProvider =
    Provider.family<
      ({int earned, int paid, int pending, int available}),
      String
    >((ref, profileId) {
      final payouts =
          ref.watch(stylistPayoutsProvider(profileId)).valueOrNull ?? const [];

      // Cumulatif, comme la borne appliquée par `request_payout` : un
      // versement de juillet doit continuer d'amputer le dû en août, sinon le
      // même travail serait payé deux fois. Le solde ne se déduit donc pas de
      // la commission d'une période — c'est pourquoi la famille ne prend plus
      // que l'identifiant du membre.
      final earned = ref.watch(cumulativeCommissionForProvider(profileId));

      final paid = payouts
          .where((payout) => payout.isSettled)
          .fold(0, (sum, payout) => sum + payout.amountFcfa);

      final pending = payouts
          .where((payout) => payout.status == PayoutStatus.pending)
          .fold(0, (sum, payout) => sum + payout.amountFcfa);

      return (
        earned: earned,
        paid: paid,
        pending: pending,
        available: (earned - paid - pending).clamp(0, earned),
      );
    });

/// Élément journalier de commission pour l'écran de demande de versement C3.
class DailyCommissionItem {
  const DailyCommissionItem({
    required this.date,
    required this.label,
    required this.serviceCount,
    required this.revenueFcfa,
    required this.commissionFcfa,
    required this.isCurrentDay,
  });

  final DateTime date;
  final String label;
  final int serviceCount;
  final int revenueFcfa;
  final int commissionFcfa;
  final bool isCurrentDay;
}

/// Nombre de journées listées sur l'écran de demande de versement (30 jours pour couvrir le mois).
const int payoutHistoryDays = 30;

/// Commissions journalières réelles d'un coiffeur donné (vue coiffeur ou gérant).
final stylistDailyCommissionsProvider =
    FutureProvider.family<List<DailyCommissionItem>, String>((
      ref,
      profileId,
    ) async {
      final salonId = ref.watch(currentSalonIdProvider);
      if (salonId == null) return const [];

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // De la plus ancienne à aujourd'hui, pour que la liste se lise dans le sens
      // du temps.
      final buckets = [
        for (var i = payoutHistoryDays - 1; i >= 0; i--)
          (
            from: today.subtract(Duration(days: i)),
            to: today.subtract(Duration(days: i - 1)),
          ),
      ];

      final totals = await ref
          .watch(financeRepositoryProvider)
          .fetchStylistBuckets(
            salonId: salonId,
            profileId: profileId,
            buckets: buckets,
          );

      return [
        for (var i = 0; i < buckets.length; i++)
          DailyCommissionItem(
            date: buckets[i].from,
            label: Formatters.weekdayDayMonth(buckets[i].from),
            serviceCount: totals[i].serviceCount,
            revenueFcfa: totals[i].revenueFcfa,
            commissionFcfa: totals[i].commissionFcfa,
            isCurrentDay: buckets[i].from == today,
          ),
      ];
    });

/// Commissions journalières réelles du membre connecté.
final myDailyCommissionsProvider = FutureProvider<List<DailyCommissionItem>>((
  ref,
) async {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile == null) return const [];
  return ref.watch(stylistDailyCommissionsProvider(profile.id).future);
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
      _invalidateAll(profileId);
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
      _invalidateAll(profileId);
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }

  void _invalidateAll([String? profileId]) {
    _ref.invalidate(myPayoutsProvider);
    _ref.invalidate(allPayoutsProvider);
    _ref.invalidate(paidByStylistProvider);
    _ref.invalidate(financeSummaryProvider);
    _ref.invalidate(commissionsProvider);
    _ref.invalidate(cumulativeCommissionsProvider);
    _ref.invalidate(stylistPayoutsProvider);
    _ref.invalidate(stylistPayoutBalanceProvider);
    _ref.invalidate(stylistDailyCommissionsProvider);
    _ref.invalidate(myDailyCommissionsProvider);
    if (profileId != null) {
      _ref.invalidate(stylistPayoutsProvider(profileId));
      _ref.invalidate(stylistPayoutBalanceProvider(profileId));
      _ref.invalidate(stylistDailyCommissionsProvider(profileId));
    }
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
  // L'encaissé, pas le facturé : un ticket laissé en attente n'a rien mis dans
  // le tiroir, et le compter ferait annoncer au gérant un résultat qu'il n'a
  // pas touché. C'est aussi ce que l'écran promet déjà en toutes lettres.
  final int collected =
      ref.watch(financeSummaryProvider).valueOrNull?.collectedFcfa ?? 0;
  final int commissions = ref.watch(periodCommissionsProvider);
  final int expenses = ref.watch(expensesTotalProvider);

  return collected - commissions - expenses;
});

/// Marge nette de la période, en pourcentage du chiffre d'affaires.
///
/// `null` sans chiffre d'affaires : une marge n'a pas de sens sur zéro, et
/// afficher « 0 % » laisserait croire à une activité sans rentabilité plutôt
/// qu'à une absence d'activité.
final netMarginProvider = Provider<int?>((ref) {
  // Même base que le net lui-même, sinon la marge ne serait pas le rapport de
  // ce qui est affiché juste au-dessus.
  final collected =
      ref.watch(financeSummaryProvider).valueOrNull?.collectedFcfa ?? 0;
  if (collected <= 0) return null;

  return (ref.watch(netResultProvider) / collected * 100).round();
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

/// Tout ce qui se calcule à partir des transactions.
///
/// Ces providers ne sont pas `autoDispose` : une fois lus, ils gardent leur
/// valeur jusqu'à invalidation explicite. Après une vente, l'encaissement
/// invalidait bien le journal de caisse, mais ni les commissions, ni le
/// chiffre d'affaires, ni les rapports — qui restaient donc figés sur leur
/// dernier calcul. Redémarrer l'application était le seul moyen de les
/// rafraîchir.
///
/// Une liste plutôt qu'une suite d'appels : elle est inspectable depuis les
/// tests, et le prochain provider dérivé des ventes n'a qu'un endroit où
/// s'ajouter.
final List<ProviderOrFamily> salesDerivedProviders = [
  // Finance : synthèse, commissions, rapports, graphes.
  financeSummaryProvider,
  commissionsProvider,
  monthCommissionsProvider,
  myMonthCommissionProvider,
  cumulativeCommissionsProvider,
  myDailyCommissionsProvider,
  servicePerformanceProvider,
  financeBucketsProvider,
  exportSummaryProvider,

  // Accueil : les barres de la semaine et leur comparaison.
  twoWeekTransactionsProvider,

  // Fiche du personnel : le chiffre du mois d'un membre.
  staffStatsProvider,
];

/// Force le recalcul de tout ce qui dépend des ventes.
///
/// Appelée après un encaissement, un remboursement, une mise en attente ou une
/// annulation : ces quatre gestes déplacent exactement les mêmes chiffres.
void invalidateSalesDerived(Ref ref) {
  for (final provider in salesDerivedProviders) {
    ref.invalidate(provider);
  }
}
