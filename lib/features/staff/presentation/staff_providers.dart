import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../auth/domain/profile.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../finance/presentation/finance_providers.dart';
import '../data/staff_repository.dart';
import '../domain/staff_schedule.dart';

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(ref.watch(supabaseClientProvider)),
);

/// Équipe complète du salon.
final teamProvider = FutureProvider<List<Profile>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(staffRepositoryProvider).fetchTeam(salonId);
});

/// Coiffeurs uniquement (affectation des RDV et de la file d'attente).
final stylistsProvider = FutureProvider<List<Profile>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(staffRepositoryProvider).fetchStylists(salonId);
});

/// Fiche d'un membre.
final staffDetailProvider =
    FutureProvider.family<Profile?, String>((ref, profileId) {
  return ref.watch(staffRepositoryProvider).fetchById(profileId);
});

/// Horaires hebdomadaires d'un membre.
final staffScheduleProvider =
    FutureProvider.family<List<StaffSchedule>, String>((ref, profileId) {
  return ref.watch(staffRepositoryProvider).fetchSchedule(profileId);
});

/// Statistiques du mois d'un membre (CA, clients, note).
final staffStatsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, profileId) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId != null) {
    try {
      final now = DateTime.now();
      final commissions =
          await ref.watch(financeRepositoryProvider).fetchCommissions(
                salonId: salonId,
                from: DateTime(now.year, now.month),
                to: DateTime(now.year, now.month + 1),
              );

      for (final c in commissions) {
        if (c.stylistId == profileId) {
          return {
            'revenue_fcfa': c.revenueFcfa,
            'commission_fcfa': c.commissionFcfa,
            'client_count': c.clientCount > 0 ? c.clientCount : c.serviceCount,
            'service_count': c.serviceCount,
          };
        }
      }
    } catch (_) {}
  }
  return ref.watch(staffRepositoryProvider).fetchStats(profileId);
});

/// Toutes les absences du salon.
final timeOffProvider = FutureProvider<List<TimeOff>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(staffRepositoryProvider).fetchTimeOff(salonId: salonId);
});

/// Absences du membre connecté — son propre historique.
final myTimeOffProvider = FutureProvider<List<TimeOff>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (salonId == null || profile == null) return const [];

  return ref.watch(staffRepositoryProvider).fetchTimeOff(
        salonId: salonId,
        profileId: profile.id,
      );
});

/// Demandes déjà tranchées, la plus récente d'abord.
///
/// `fetchTimeOff` trie par date de début croissante, ce qui convient à un
/// calendrier mais met les vieilles absences en tête d'un historique.
final timeOffHistoryProvider = Provider<List<TimeOff>>((ref) {
  final items = ref.watch(timeOffProvider).valueOrNull ?? const [];
  return _decidedFirst(items);
});

/// Même historique, restreint au membre connecté.
final myTimeOffHistoryProvider = Provider<List<TimeOff>>((ref) {
  final items = ref.watch(myTimeOffProvider).valueOrNull ?? const [];
  return _decidedFirst(items);
});

List<TimeOff> _decidedFirst(List<TimeOff> items) {
  final decided = items.where((request) => request.isDecided).toList()
    ..sort((a, b) => b.startDate.compareTo(a.startDate));
  return decided;
}

/// Demandes en attente de validation.
final pendingTimeOffProvider = Provider<List<TimeOff>>((ref) {
  final items = ref.watch(timeOffProvider).valueOrNull ?? const [];
  return items
      .where((request) => request.status == TimeOffStatus.pending)
      .toList();
});

/// Absences validées à venir ou en cours.
final upcomingTimeOffProvider = Provider<List<TimeOff>>((ref) {
  final items = ref.watch(timeOffProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  return items
      .where((request) =>
          request.status == TimeOffStatus.approved &&
          request.endDate.isAfter(now.subtract(const Duration(days: 1))))
      .toList();
});

/// Identifiants des membres absents aujourd'hui.
final absentTodayIdsProvider = Provider<Set<String>>((ref) {
  final items = ref.watch(timeOffProvider).valueOrNull ?? const [];
  return {
    for (final request in items)
      if (request.isOngoing) request.profileId,
  };
});

/// Effectif présent / total du jour.
final presenceCountProvider = Provider<({int present, int total})>((ref) {
  final team = ref.watch(teamProvider).valueOrNull ?? const [];
  final absent = ref.watch(absentTodayIdsProvider);
  final active = team.where((member) => member.isActive).toList();
  return (
    present: active.where((member) => !absent.contains(member.id)).length,
    total: active.length,
  );
});
