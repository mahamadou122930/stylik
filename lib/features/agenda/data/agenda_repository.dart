import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../domain/appointment.dart';
import '../domain/walk_in_entry.dart';

/// Lecture / écriture du planning et de la file d'attente.
class AgendaRepository {
  const AgendaRepository(this._client);

  final SupabaseClient _client;

  static const String _appointmentSelect =
      '*, clients(full_name, phone, visit_count), '
      'profiles!appointments_stylist_id_fkey(full_name)';

  /// Rendez-vous d'une journée. [stylistId] non nul → planning individuel.
  Future<List<Appointment>> fetchDay({
    required String salonId,
    required DateTime day,
    String? stylistId,
  }) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    var query = _client
        .from(SupabaseTables.appointments)
        .select(_appointmentSelect)
        .eq('salon_id', salonId)
        .gte('start_time', start.toUtc().toIso8601String())
        .lt('start_time', end.toUtc().toIso8601String());

    if (stylistId != null) query = query.eq('stylist_id', stylistId);

    final data = await query.order('start_time');
    return data.map((row) => Appointment.fromMap(row)).toList();
  }

  Future<Appointment> create(Appointment appointment) async {
    final data = await _client
        .from(SupabaseTables.appointments)
        .insert(appointment.toMap())
        .select(_appointmentSelect)
        .single();
    return Appointment.fromMap(data);
  }

  Future<Appointment> updateStatus({
    required String appointmentId,
    required AppointmentStatus status,
  }) async {
    final data = await _client
        .from(SupabaseTables.appointments)
        .update({'status': status.value})
        .eq('id', appointmentId)
        .select(_appointmentSelect)
        .single();
    return Appointment.fromMap(data);
  }

  Future<Appointment> reschedule({
    required String appointmentId,
    required DateTime startTime,
    required DateTime endTime,
    String? stylistId,
  }) async {
    final data = await _client
        .from(SupabaseTables.appointments)
        .update({
          'start_time': startTime.toUtc().toIso8601String(),
          'end_time': endTime.toUtc().toIso8601String(),
          'stylist_id': ?stylistId,
        })
        .eq('id', appointmentId)
        .select(_appointmentSelect)
        .single();
    return Appointment.fromMap(data);
  }

  Future<Appointment?> fetchById(String appointmentId) async {
    final data = await _client
        .from(SupabaseTables.appointments)
        .select(_appointmentSelect)
        .eq('id', appointmentId)
        .maybeSingle();
    return data == null ? null : Appointment.fromMap(data);
  }

  /// Créneaux libres d'un coiffeur pour une journée, par pas de 30 min.
  Future<List<DateTime>> fetchFreeSlots({
    required String salonId,
    required String stylistId,
    required DateTime day,
    required int durationMinutes,
    int openingHour = 9,
    int closingHour = 19,
  }) async {
    final booked = await fetchDay(
      salonId: salonId,
      day: day,
      stylistId: stylistId,
    );

    final slots = <DateTime>[];
    var cursor = DateTime(day.year, day.month, day.day, openingHour);
    final closing = DateTime(day.year, day.month, day.day, closingHour);

    while (cursor.add(Duration(minutes: durationMinutes)).isBefore(closing) ||
        cursor
            .add(Duration(minutes: durationMinutes))
            .isAtSameMomentAs(closing)) {
      final end = cursor.add(Duration(minutes: durationMinutes));
      final overlaps = booked.any(
        (appointment) =>
            appointment.status.isActive &&
            cursor.isBefore(appointment.endTime) &&
            end.isAfter(appointment.startTime),
      );
      if (!overlaps && cursor.isAfter(DateTime.now())) slots.add(cursor);
      cursor = cursor.add(const Duration(minutes: 30));
    }

    return slots;
  }

  Future<void> delete(String appointmentId) =>
      _client.from(SupabaseTables.appointments).delete().eq('id', appointmentId);

  /// Vérifie qu'un créneau est libre pour un coiffeur (anti double-booking).
  Future<bool> isSlotFree({
    required String stylistId,
    required DateTime startTime,
    required DateTime endTime,
    String? ignoreAppointmentId,
  }) async {
    var query = _client
        .from(SupabaseTables.appointments)
        .select('id')
        .eq('stylist_id', stylistId)
        .lt('start_time', endTime.toUtc().toIso8601String())
        .gt('end_time', startTime.toUtc().toIso8601String())
        .not('status', 'in', '(cancelled,no_show)');

    if (ignoreAppointmentId != null) {
      query = query.neq('id', ignoreAppointmentId);
    }

    final data = await query;
    return data.isEmpty;
  }

  // --- Walk-in ------------------------------------------------------------

  /// File d'attente courante, la plus ancienne arrivée en tête.
  Future<List<WalkInEntry>> fetchQueue(String salonId) async {
    final data = await _client
        .from(SupabaseTables.walkInQueue)
        .select()
        .eq('salon_id', salonId)
        .inFilter('status', ['waiting', 'assigned', 'in_progress'])
        .order('arrival_time');

    return data.map((row) => WalkInEntry.fromMap(row)).toList();
  }

  /// Flux temps réel de la file d'attente (affichage tablette accueil).
  Stream<List<WalkInEntry>> watchQueue(String salonId) {
    return _client
        .from(SupabaseTables.walkInQueue)
        .stream(primaryKey: ['id'])
        .eq('salon_id', salonId)
        .order('arrival_time')
        .map((rows) => rows.map(WalkInEntry.fromMap).toList());
  }

  Future<WalkInEntry> addToQueue(WalkInEntry entry) async {
    final data = await _client
        .from(SupabaseTables.walkInQueue)
        .insert(entry.toMap())
        .select()
        .single();
    return WalkInEntry.fromMap(data);
  }

  Future<WalkInEntry> updateQueueEntry({
    required String entryId,
    WalkInStatus? status,
    String? assignedStylistId,
  }) async {
    final data = await _client
        .from(SupabaseTables.walkInQueue)
        .update({
          'status': ?status?.value,
          'assigned_stylist_id': ?assignedStylistId,
        })
        .eq('id', entryId)
        .select()
        .single();
    return WalkInEntry.fromMap(data);
  }
}
