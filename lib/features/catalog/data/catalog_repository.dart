import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/services/local_db_service.dart';
import '../domain/salon_service.dart';

/// Catalogue des prestations et forfaits avec support Offline-First.
class CatalogRepository {
  const CatalogRepository(this._client, this._localDb);

  final SupabaseClient _client;
  final LocalDbService _localDb;

  Future<List<SalonService>> fetchAll({
    required String salonId,
    bool onlyActive = true,
  }) async {
    try {
      var query = _client
          .from(SupabaseTables.services)
          .select()
          .eq('salon_id', salonId);

      if (onlyActive) query = query.eq('is_active', true);

      final data = await query
          .order('category', ascending: true)
          .order('name', ascending: true);

      final records = List<Map<String, dynamic>>.from(data);
      await _localDb.cacheRecords(
        tableName: SupabaseTables.services,
        salonId: salonId,
        records: records,
      );

      return records.map((row) => SalonService.fromMap(row)).toList();
    } catch (_) {
      final cached = await _localDb.getCachedRecords(
        tableName: SupabaseTables.services,
        salonId: salonId,
      );

      var services = cached.map((row) => SalonService.fromMap(row)).toList();
      if (onlyActive) services = services.where((s) => s.isActive).toList();
      services.sort((a, b) => a.name.compareTo(b.name));
      return services;
    }
  }

  Future<List<SalonService>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      final data = await _client
          .from(SupabaseTables.services)
          .select()
          .inFilter('id', ids);
      return data.map((row) => SalonService.fromMap(row)).toList();
    } catch (_) {
      final list = <SalonService>[];
      for (final id in ids) {
        final cached = await _localDb.getCachedRecordById(
          tableName: SupabaseTables.services,
          recordId: id,
        );
        if (cached != null) list.add(SalonService.fromMap(cached));
      }
      return list;
    }
  }

  Future<SalonService> create(SalonService service) async {
    await _localDb.cacheRecord(
      tableName: SupabaseTables.services,
      salonId: service.salonId,
      record: service.toMap(),
    );

    try {
      final data = await _client
          .from(SupabaseTables.services)
          .insert(service.toMap())
          .select()
          .single();

      final created = SalonService.fromMap(data);
      await _localDb.cacheRecord(
        tableName: SupabaseTables.services,
        salonId: service.salonId,
        record: created.toMap(),
      );

      return created;
    } catch (_) {
      await _localDb.enqueueMutation(
        action: 'INSERT',
        tableName: SupabaseTables.services,
        recordId: service.id,
        payload: service.toMap(),
      );
      return service;
    }
  }

  Future<SalonService> update(SalonService service) async {
    await _localDb.cacheRecord(
      tableName: SupabaseTables.services,
      salonId: service.salonId,
      record: service.toMap(),
    );

    try {
      final data = await _client
          .from(SupabaseTables.services)
          .update(service.toMap())
          .eq('id', service.id)
          .select()
          .single();

      return SalonService.fromMap(data);
    } catch (_) {
      await _localDb.enqueueMutation(
        action: 'UPDATE',
        tableName: SupabaseTables.services,
        recordId: service.id,
        payload: service.toMap(),
      );
      return service;
    }
  }

  Future<void> archive(String serviceId) async {
    final cached = await _localDb.getCachedRecordById(
      tableName: SupabaseTables.services,
      recordId: serviceId,
    );

    if (cached != null) {
      cached['is_active'] = false;
      await _localDb.cacheRecord(
        tableName: SupabaseTables.services,
        salonId: cached['salon_id'] as String,
        record: cached,
      );
    }

    try {
      await _client
          .from(SupabaseTables.services)
          .update({'is_active': false})
          .eq('id', serviceId);
    } catch (_) {
      await _localDb.enqueueMutation(
        action: 'UPDATE',
        tableName: SupabaseTables.services,
        recordId: serviceId,
        payload: {'is_active': false},
      );
    }
  }
}
