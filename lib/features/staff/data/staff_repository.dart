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
    var query = _client
        .from(SupabaseTables.profiles)
        .select(Profile.columns)
        .eq('salon_id', salonId);

    if (role != null) query = query.eq('role', role.value);

    final data = await query.order('full_name', ascending: true);
    return data.map((row) => Profile.fromMap(row)).toList();
  }

  /// Membres affectables à un rendez-vous ou à une ligne de ticket.
  ///
  /// Le gérant en fait partie : dans un salon, il coiffe aussi, et il touche
  /// sa commission comme les autres. L'exclure le rendait inaffectable au
  /// planning et faisait disparaître ses prestations du rapport par coiffeur.
  /// Seule la réception, qui ne réalise pas de prestation, reste écartée.
  Future<List<Profile>> fetchStylists(String salonId) async {
    final team = await fetchTeam(salonId);
    return team
        .where((member) =>
            member.isActive && member.role != UserRole.receptionniste)
        .toList();
  }

  Future<Profile?> fetchById(String profileId) async {
    final data = await _client
        .from(SupabaseTables.profiles)
        .select(Profile.columns)
        .eq('id', profileId)
        .maybeSingle();
    return data == null ? null : Profile.fromMap(data);
  }

  /// Ajoute un membre à l'équipe (écran « Nouvel employé »).
  ///
  /// Aucun compte Supabase Auth n'est créé ici : le profil vit seul et sera
  /// rattaché automatiquement si la personne s'inscrit un jour avec [email].
  /// Un coiffeur sans compte est pleinement utilisable — planning, commissions,
  /// encaissement à son nom — il ne peut simplement pas se connecter.
  Future<Profile> create({
    required String salonId,
    required String fullName,
    required UserRole role,
    List<String> specialties = const [],
    double commissionRate = 0,
    int leaveBalanceDays = 0,
    String? phone,
    String? email,
  }) async {
    final data = await _client
        .from(SupabaseTables.profiles)
        .insert({
          'salon_id': salonId,
          'full_name': fullName,
          'role': role.value,
          'specialties': specialties,
          'commission_rate': commissionRate,
          'leave_balance_days': leaveBalanceDays,
          'phone': phone,
          'email': email,
          'is_active': true,
        })
        .select(Profile.columns)
        .single();

    return Profile.fromMap(data);
  }

  Future<Profile> update(Profile profile) async {
    final data = await _client
        .from(SupabaseTables.profiles)
        .update(profile.toMap()..remove('id'))
        .eq('id', profile.id)
        .select(Profile.columns)
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

    final data = await query.order('start_date', ascending: true);
    return data.map((row) => TimeOff.fromMap(row)).toList();
  }

  /// Tranche une demande d'absence et répercute l'effet sur le solde de congés.
  ///
  /// Le solde n'est ajusté qu'à la décision, jamais au dépôt : une demande
  /// refusée ne doit pas avoir amputé les jours entre-temps.
  ///
  /// Passe par la RPC `decide_time_off`, qui verrouille la demande et applique
  /// un incrément relatif — deux gérants tranchant en même temps ne peuvent
  /// donc plus s'écraser. Le repli n'existe que pour les bases où la migration
  /// n'est pas encore appliquée ; il refait le calcul en deux temps, avec la
  /// fenêtre de concurrence que cela suppose.
  Future<void> decideTimeOff({
    required TimeOff request,
    required TimeOffStatus status,
  }) async {
    try {
      await _client.rpc<dynamic>(
        'decide_time_off',
        params: {'p_request_id': request.id, 'p_status': status.value},
      );
      return;
    } catch (_) {
      await _decideTimeOffLocally(request: request, status: status);
    }
  }

  Future<void> _decideTimeOffLocally({
    required TimeOff request,
    required TimeOffStatus status,
  }) async {
    final delta = request.balanceDeltaFor(status);

    await _client
        .from(SupabaseTables.timeOff)
        .update({'status': status.value})
        .eq('id', request.id);

    if (delta == 0) return;

    final row = await _client
        .from(SupabaseTables.profiles)
        .select('leave_balance_days')
        .eq('id', request.profileId)
        .single();

    final current = (row['leave_balance_days'] as num?)?.toInt() ?? 0;

    await _client
        .from(SupabaseTables.profiles)
        .update({'leave_balance_days': current + delta})
        .eq('id', request.profileId);
  }

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
