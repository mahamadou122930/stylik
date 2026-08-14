import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agenda/domain/appointment.dart';
import '../../agenda/presentation/agenda_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../pos/domain/ticket.dart';
import '../../pos/presentation/pos_providers.dart';
import '../../settings/domain/salon.dart';
import '../../settings/presentation/settings_providers.dart';
import '../../staff/presentation/staff_providers.dart';

/// Premier jour (lundi) de la semaine contenant [day], à minuit.
DateTime startOfWeek(DateTime day) {
  final midnight = DateTime(day.year, day.month, day.day);
  return midnight.subtract(Duration(days: midnight.weekday - DateTime.monday));
}

/// Tickets des deux dernières semaines (celle en cours et la précédente).
///
/// Une seule requête sert les trois lectures de l'accueil : les barres de la
/// semaine, son total, et la comparaison au même jour la semaine passée.
final twoWeekTransactionsProvider =
    FutureProvider<List<SalonTransaction>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final thisWeek = startOfWeek(DateTime.now());
  return ref.watch(posRepositoryProvider).fetchRange(
        salonId: salonId,
        from: thisWeek.subtract(const Duration(days: 7)),
        to: thisWeek.add(const Duration(days: 7)),
      );
});

/// Encaissement d'un jour donné, remboursements déduits.
int _totalOn(List<SalonTransaction> transactions, DateTime day) {
  return transactions
      .where((transaction) {
        final at = transaction.createdAt?.toLocal();
        return at != null &&
            at.year == day.year &&
            at.month == day.month &&
            at.day == day.day;
      })
      .fold(0, (sum, transaction) => sum + transaction.signedAmountFcfa);
}

/// Les sept jours de la semaine en cours, du lundi au dimanche.
final weekRevenueProvider = Provider<List<({DateTime day, int totalFcfa})>>(
  (ref) {
    final transactions =
        ref.watch(twoWeekTransactionsProvider).valueOrNull ?? const [];
    final monday = startOfWeek(DateTime.now());

    return [
      for (var i = 0; i < 7; i++)
        (
          day: monday.add(Duration(days: i)),
          totalFcfa: _totalOn(transactions, monday.add(Duration(days: i))),
        ),
    ];
  },
);

/// Variation du CA du jour par rapport au même jour de la semaine passée.
///
/// `null` quand la semaine passée n'a rien encaissé ce jour-là : afficher
/// « +100 % » face à un zéro ne dirait rien au gérant.
final revenueTrendProvider = Provider<double?>((ref) {
  final transactions =
      ref.watch(twoWeekTransactionsProvider).valueOrNull ?? const [];
  final today = DateTime.now();
  final previous = _totalOn(transactions, today.subtract(const Duration(days: 7)));
  if (previous <= 0) return null;

  return (ref.watch(todayCashTotalProvider) - previous) / previous;
});

/// Panier moyen du jour : encaissement divisé par le nombre de ventes.
///
/// Les remboursements sont exclus du diviseur — ce ne sont pas des ventes —
/// mais restent déduits du montant, sinon le panier moyen serait surévalué
/// un jour de remboursement.
final averageTicketProvider = Provider<({int valueFcfa, int saleCount})>((ref) {
  final transactions =
      ref.watch(todayTransactionsProvider).valueOrNull ?? const [];
  final sales = transactions.where((t) => !t.isRefund).length;
  if (sales == 0) return (valueFcfa: 0, saleCount: 0);

  return (
    valueFcfa: (ref.watch(todayCashTotalProvider) / sales).round(),
    saleCount: sales,
  );
});

/// Taux de remplissage du jour et créneaux encore libres.
///
/// La capacité est le temps d'ouverture multiplié par le nombre de coiffeurs :
/// deux coiffeurs sur une journée de 10 h offrent 20 h de rendez-vous. Les
/// créneaux libres sont comptés par tranches de 30 minutes, l'unité de
/// réservation la plus courte du catalogue.
final occupancyProvider =
    Provider<({double? rate, int freeSlots})>((ref) {
  final salon = ref.watch(currentSalonProvider).valueOrNull;
  final stylists = ref.watch(stylistsProvider).valueOrNull ?? const [];
  final appointments =
      ref.watch(dayAppointmentsProvider).valueOrNull ?? const <Appointment>[];

  final openMinutes = _openMinutesToday(salon);
  final capacity = openMinutes * stylists.length;
  if (capacity <= 0) return (rate: null, freeSlots: 0);

  final booked = appointments
      .where((appointment) => appointment.status.isActive)
      .fold<int>(0, (sum, a) => sum + a.duration.inMinutes);

  final free = (capacity - booked).clamp(0, capacity);
  return (
    rate: (booked / capacity).clamp(0.0, 1.0),
    freeSlots: free ~/ 30,
  );
});

/// Prestations terminées aujourd'hui dont le paiement n'a pas été encaissé.
///
/// C'est l'angle mort du comptoir : le client est parti, la prestation est
/// marquée « Terminé », mais aucun ticket n'a été clôturé. Le rapprochement se
/// fait sur `appointment_id`, seul lien entre le rendez-vous et sa recette.
final unpaidCompletedProvider = Provider<List<Appointment>>((ref) {
  final appointments =
      ref.watch(dayAppointmentsProvider).valueOrNull ?? const <Appointment>[];
  final transactions =
      ref.watch(todayTransactionsProvider).valueOrNull ?? const [];

  final settled = <String>{
    for (final transaction in transactions)
      if (!transaction.isRefund && transaction.appointmentId != null)
        transaction.appointmentId!,
  };

  return appointments
      .where((appointment) =>
          appointment.status == AppointmentStatus.completed &&
          !settled.contains(appointment.id))
      .toList();
});

/// Rendez-vous du jour encore à venir, dans l'ordre chronologique.
final upcomingTodayProvider = Provider<List<Appointment>>((ref) {
  final now = DateTime.now();
  final appointments =
      ref.watch(dayAppointmentsProvider).valueOrNull ?? const <Appointment>[];

  final upcoming = appointments
      .where((appointment) =>
          appointment.status.isActive && appointment.endTime.isAfter(now))
      .toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));

  return upcoming;
});

/// Amplitude d'ouverture du jour, en minutes. 0 si le salon est fermé ou si
/// ses horaires ne sont pas renseignés.
int _openMinutesToday(Salon? salon) {
  if (salon == null) return 0;

  final raw = salon.openingHours['${DateTime.now().weekday}'];
  if (raw is! Map<String, dynamic> || raw['closed'] == true) return 0;

  final open = _minutesOfDay(raw['open'] as String?);
  final close = _minutesOfDay(raw['close'] as String?);
  if (open == null || close == null || close <= open) return 0;

  return close - open;
}

/// « 09:00 » → 540.
int? _minutesOfDay(String? value) {
  final parts = value?.split(':');
  if (parts == null || parts.length != 2) return null;

  final hours = int.tryParse(parts.first);
  final minutes = int.tryParse(parts.last);
  if (hours == null || minutes == null) return null;

  return hours * 60 + minutes;
}
