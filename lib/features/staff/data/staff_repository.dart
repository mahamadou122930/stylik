import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../auth/domain/profile.dart';
import '../../auth/domain/user_role.dart';
import '../domain/staff_schedule.dart';

/// Gestion de l'équipe : membres, rôles, commissions, horaires et congés.
class StaffRepository {
  const StaffRepository(this._client);

  final SupabaseClient _client;

  Future<List<Profile>> fetchTeam(String salonId, {UserRole? role}) async {
    var query =
        _client.from(SupabaseTables.profiles).select().eq('salon_id', salonId);

    if (role != null) query = query.eq('role', role.value);

    final data = await query.order('full_name');
    return data.map((row) => Profile.fromMap(row)).toList();
  }

  /// Coiffeurs affectables à un rendez-vous.
  Future<List<Profile>> fetchStylists(String salonId) =>
      fetchTeam(salonId, role: UserRole.coiffeur);

  Future<Profile?> fetchById(String profileId) async {
    final data = await _client
        .from(SupabaseTables.profiles)
        .select()
        .eq('id', profileId)
        .maybeSingle();
    return data == null ? null : Profile.fromMap(data);
  }

  Future<Profile> update(Profile profile) async {
    final data = await _client
        .from(SupabaseTables.profiles)
        .update(profile.toMap()..remove('id'))
        .eq('id', profile.id)
        .select()
        .single();
    return Profile.fromMap(data);
  }

  Future<void> setActive({required String profileId, required bool isActive}) =>
      _client
          .from(SupabaseTables.profiles)
          .update({'is_active': isActive})
          .eq('id', profileId);

  // --- Horaires -----------------------------------------------------------

  Future<List<StaffSchedule>> fetchSchedule(String profileId) async {
    final data = await _client
        .from(SupabaseTables.profiles)
        .select('working_hours')
        .eq('id', profileId)
        .maybeSingle();

    return StaffSchedule.listFromJson(
      data?['working_hours'] as Map<String, dynamic>?,
    );
  }

  Future<void> saveSchedule({
    required String profileId,
    required List<StaffSchedule> schedule,
  }) {
    final json = {
      for (final entry in schedule) '${entry.weekday}': entry.toMap(),
    };
    return _client
        .from(SupabaseTables.profiles)
        .update({'working_hours': json})
        .eq('id', profileId);
  }

  // --- Congés & absences --------------------------------------------------

  Future<List<TimeOff>> fetchTimeOff({
    required String salonId,
    TimeOffStatus? status,
    String? profileId,
  }) async {
    var query = _client
        .from(SupabaseTables.timeOff)
        .select('*, profiles(full_name)')
        .eq('salon_id', salonId);

    if (status != null) query = query.eq('status', status.value);
    if (profileId != null) query = query.eq('profile_id', profileId);

    final data = await query.order('start_date');
    return data.map((row) => TimeOff.fromMap(row)).toList();
  }

  Future<void> setTimeOffStatus({
    required String timeOffId,
    required TimeOffStatus status,
  }) =>
      _client
          .from(SupabaseTables.timeOff)
          .update({'status': status.value})
          .eq('id', timeOffId);

  Future<TimeOff> requestTimeOff(TimeOff request) async {
    final data = await _client
        .from(SupabaseTables.timeOff)
        .insert(request.toMap())
        .select('*, profiles(full_name)')
        .single();
    return TimeOff.fromMap(data);
  }

  /// Performance d'un membre sur le mois courant (RPC `stylist_stats`).
  Future<Map<String, dynamic>?> fetchStats(String profileId) {
    return _client.rpc<Map<String, dynamic>?>(
      'stylist_stats',
      params: {'p_profile_id': profileId},
    );
  }
}
