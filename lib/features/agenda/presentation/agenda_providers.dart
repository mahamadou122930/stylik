import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/agenda_repository.dart';
import '../domain/appointment.dart';
import '../domain/walk_in_entry.dart';

import '../../../core/services/local_db_service.dart';

final agendaRepositoryProvider = Provider<AgendaRepository>(
  (ref) => AgendaRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localDbServiceProvider),
  ),
);

/// Jour affiché dans l'agenda.
final selectedDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Coiffeur filtré (null = planning global).
final selectedStylistProvider = StateProvider<String?>((ref) => null);

/// Coiffeur réellement interrogé en base.
///
/// Sans la permission « planning du salon », le filtre est verrouillé sur la
/// fiche du membre connecté : le choix est fait ici, et non dans les écrans,
/// pour qu'aucune page ne puisse charger par mégarde la journée des collègues.
/// Le verrou côté base reste la politique RLS `appointments`.
final agendaStylistFilterProvider = Provider<String?>((ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile == null) return null;
  if (!profile.role.canViewFullAgenda) return profile.id;
  return ref.watch(selectedStylistProvider);
});

/// Rendez-vous du jour sélectionné.
final dayAppointmentsProvider = FutureProvider<List<Appointment>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  return ref.watch(agendaRepositoryProvider).fetchDay(
        salonId: salonId,
        day: ref.watch(selectedDayProvider),
        stylistId: ref.watch(agendaStylistFilterProvider),
      );
});

/// Rendez-vous du jour groupés par coiffeur (colonnes du planning global).
final appointmentsByStylistProvider =
    Provider<Map<String, List<Appointment>>>((ref) {
  final appointments = ref.watch(dayAppointmentsProvider).valueOrNull ?? const [];

  final grouped = <String, List<Appointment>>{};
  for (final appointment in appointments) {
    grouped.putIfAbsent(appointment.stylistId, () => []).add(appointment);
  }
  return grouped;
});

/// Fiche d'un rendez-vous.
final appointmentDetailProvider =
    FutureProvider.family<Appointment?, String>((ref, appointmentId) {
  return ref.watch(agendaRepositoryProvider).fetchById(appointmentId);
});

/// Paramètres de recherche de créneaux libres (écran Nouveau RDV).
typedef SlotQuery = ({String stylistId, DateTime day, int durationMinutes});

final freeSlotsProvider =
    FutureProvider.family<List<DateTime>, SlotQuery>((ref, query) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  return ref.watch(agendaRepositoryProvider).fetchFreeSlots(
        salonId: salonId,
        stylistId: query.stylistId,
        day: query.day,
        durationMinutes: query.durationMinutes,
      );
});

/// File d'attente walk-in en temps réel.
final walkInQueueProvider = StreamProvider<List<WalkInEntry>>((ref) {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const Stream.empty();
  return ref.watch(agendaRepositoryProvider).watchQueue(salonId);
});

/// Temps d'attente moyen de la file, en minutes.
final averageWaitProvider = Provider<int>((ref) {
  final queue = ref.watch(walkInQueueProvider).valueOrNull ?? const [];
  final waiting =
      queue.where((entry) => entry.status == WalkInStatus.waiting).toList();
  if (waiting.isEmpty) return 0;

  final total = waiting.fold<int>(
    0,
    (sum, entry) => sum + entry.waitingTime.inMinutes,
  );
  return (total / waiting.length).round();
});
