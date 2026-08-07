import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/services/local_db_service.dart';
import '../domain/appointment.dart';
import '../domain/walk_in_entry.dart';

/// Lecture / écriture du planning et de la file d'attente avec support Offline-First.
class AgendaRepository {
  const AgendaRepository(this._client, this._localDb);

  final SupabaseClient _client;
  final LocalDbService _localDb;

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

    try {
      var query = _client
          .from(SupabaseTables.appointments)
          .select(_appointmentSelect)
          .eq('salon_id', salonId)
          .gte('start_time', start.toUtc().toIso8601String())
          .lt('start_time', end.toUtc().toIso8601String());

      if (stylistId != null) query = query.eq('stylist_id', stylistId);

      final data = await query.order('start_time', ascending: true);

      final records = List<Map<String, dynamic>>.from(data);
      await _localDb.cacheRecords(
        tableName: SupabaseTables.appointments,
        salonId: salonId,
        records: records,
      );

      return records.map((row) => Appointment.fromMap(row)).toList();
    } catch (_) {
      final cached = await _localDb.getCachedRecords(
        tableName: SupabaseTables.appointments,
        salonId: salonId,
      );

      var list = cached.map((row) => Appointment.fromMap(row)).where((app) {
        final st = app.startTime.toLocal();
        final matchesDay = st.year == day.year && st.month == day.month && st.day == day.day;
        final matchesStylist = stylistId == null || app.stylistId == stylistId;
        return matchesDay && matchesStylist;
      }).toList();

      list.sort((a, b) => a.startTime.compareTo(b.startTime));
      return list;
    }
  }

  Future<Appointment> create(Appointment appointment) async {
    await _localDb.cacheRecord(
      tableName: SupabaseTables.appointments,
      salonId: appointment.salonId,
      record: appointment.toMap(),
    );

    try {
      final data = await _client
          .from(SupabaseTables.appointments)
          .insert(appointment.toMap())
          .select(_appointmentSelect)
          .single();

      final created = Appointment.fromMap(data);
      await _localDb.cacheRecord(
        tableName: SupabaseTables.appointments,
        salonId: appointment.salonId,
        record: created.toMap(),
      );

      return created;
    } catch (_) {
      await _localDb.enqueueMutation(
        action: 'INSERT',
        tableName: SupabaseTables.appointments,
        recordId: appointment.id,
        payload: appointment.toMap(),
      );
      return appointment;
    }
  }

  Future<Appointment> updateStatus({
    required String appointmentId,
    required AppointmentStatus status,
  }) async {
    try {
      final data = await _client
          .from(SupabaseTables.appointments)
          .update({'status': status.value})
          .eq('id', appointmentId)
          .select(_appointmentSelect)
          .single();

      final updated = Appointment.fromMap(data);
      await _localDb.cacheRecord(
        tableName: SupabaseTables.appointments,
        salonId: updated.salonId,
        record: updated.toMap(),
      );

      return updated;
    } catch (_) {
      final cached = await _localDb.getCachedRecordById(
        tableName: SupabaseTables.appointments,
        recordId: appointmentId,
      );

      if (cached != null) {
        cached['status'] = status.value;
        await _localDb.cacheRecord(
          tableName: SupabaseTables.appointments,
          salonId: cached['salon_id'] as String,
          record: cached,
        );

        await _localDb.enqueueMutation(
          action: 'UPDATE',
          tableName: SupabaseTables.appointments,
          recordId: appointmentId,
          payload: {'status': status.value},
        );

        return Appointment.fromMap(cached);
      }
      rethrow;
    }
  }

  Future<Appointment> reschedule({
    required String appointmentId,
    required DateTime startTime,
    required DateTime endTime,
    String? stylistId,
  }) async {
    final payload = <String, dynamic>{
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'stylist_id': ?stylistId,
    };

    try {
      final data = await _client
          .from(SupabaseTables.appointments)
          .update(payload)
          .eq('id', appointmentId)
          .select(_appointmentSelect)
          .single();

      final updated = Appointment.fromMap(data);
      await _localDb.cacheRecord(
        tableName: SupabaseTables.appointments,
        salonId: updated.salonId,
        record: updated.toMap(),
      );

      return updated;
    } catch (_) {
      final cached = await _localDb.getCachedRecordById(
        tableName: SupabaseTables.appointments,
        recordId: appointmentId,
      );

      if (cached != null) {
        cached['start_time'] = payload['start_time'];
        cached['end_time'] = payload['end_time'];
        if (stylistId != null) cached['stylist_id'] = stylistId;

        await _localDb.cacheRecord(
          tableName: SupabaseTables.appointments,
          salonId: cached['salon_id'] as String,
          record: cached,
        );

        await _localDb.enqueueMutation(
          action: 'UPDATE',
          tableName: SupabaseTables.appointments,
          recordId: appointmentId,
          payload: payload,
        );

        return Appointment.fromMap(cached);
      }
      rethrow;
    }
  }

  Future<Appointment?> fetchById(String appointmentId) async {
    try {
      final data = await _client
          .from(SupabaseTables.appointments)
          .select(_appointmentSelect)
          .eq('id', appointmentId)
          .maybeSingle();

      if (data != null) {
        await _localDb.cacheRecord(
          tableName: SupabaseTables.appointments,
          salonId: data['salon_id'] as String,
          record: data,
        );
        return Appointment.fromMap(data);
      }
    } catch (_) {}

    final cached = await _localDb.getCachedRecordById(
      tableName: SupabaseTables.appointments,
      recordId: appointmentId,
    );
    return cached == null ? null : Appointment.fromMap(cached);
  }

  /// Créneaux libres d'un coiffeur pour une journée.
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

  Future<void> delete(String appointmentId) async {
    await _localDb.deleteCachedRecord(
      tableName: SupabaseTables.appointments,
      recordId: appointmentId,
    );

    try {
      await _client.from(SupabaseTables.appointments).delete().eq('id', appointmentId);
    } catch (_) {
      await _localDb.enqueueMutation(
        action: 'DELETE',
        tableName: SupabaseTables.appointments,
        recordId: appointmentId,
        payload: {'id': appointmentId},
      );
    }
  }

  Future<bool> isSlotFree({
    required String stylistId,
    required DateTime startTime,
    required DateTime endTime,
    String? ignoreAppointmentId,
  }) async {
    try {
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
    } catch (_) {
      return true;
    }
  }

  // --- Walk-in ------------------------------------------------------------

  Future<List<WalkInEntry>> fetchQueue(String salonId) async {
    try {
      final data = await _client
          .from(SupabaseTables.walkInQueue)
          .select()
          .eq('salon_id', salonId)
          .inFilter('status', ['waiting', 'assigned', 'in_progress'])
          .order('arrival_time', ascending: true);

      return data.map((row) => WalkInEntry.fromMap(row)).toList();
    } catch (_) {
      return const [];
    }
  }

  Stream<List<WalkInEntry>> watchQueue(String salonId) {
    return _client
        .from(SupabaseTables.walkInQueue)
        .stream(primaryKey: ['id'])
        .eq('salon_id', salonId)
        .order('arrival_time', ascending: true)
        .map((rows) => rows.map(WalkInEntry.fromMap).toList());
  }

  Future<WalkInEntry> addToQueue(WalkInEntry entry) async {
    try {
      final data = await _client
          .from(SupabaseTables.walkInQueue)
          .insert(entry.toMap())
          .select()
          .single();
      return WalkInEntry.fromMap(data);
    } catch (_) {
      return entry;
    }
  }

  Future<WalkInEntry> updateQueueEntry({
    required String entryId,
    WalkInStatus? status,
    String? assignedStylistId,
  }) async {
    final payload = <String, dynamic>{
      'status': ?status?.value,
      'assigned_stylist_id': ?assignedStylistId,
    };

    final data = await _client
        .from(SupabaseTables.walkInQueue)
        .update(payload)
        .eq('id', entryId)
        .select()
        .single();
    return WalkInEntry.fromMap(data);
  }
}
