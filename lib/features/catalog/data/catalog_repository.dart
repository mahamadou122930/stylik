import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../domain/salon_service.dart';

/// Catalogue des prestations et forfaits.
class CatalogRepository {
  const CatalogRepository(this._client);

  final SupabaseClient _client;

  Future<List<SalonService>> fetchAll({
    required String salonId,
    bool onlyActive = true,
  }) async {
    var query = _client
        .from(SupabaseTables.services)
        .select()
        .eq('salon_id', salonId);

    if (onlyActive) query = query.eq('is_active', true);

    final data = await query.order('category').order('name');
    return data.map((row) => SalonService.fromMap(row)).toList();
  }

  Future<List<SalonService>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final data = await _client
        .from(SupabaseTables.services)
        .select()
        .inFilter('id', ids);
    return data.map((row) => SalonService.fromMap(row)).toList();
  }

  Future<SalonService> create(SalonService service) async {
    final data = await _client
        .from(SupabaseTables.services)
        .insert(service.toMap())
        .select()
        .single();
    return SalonService.fromMap(data);
  }

  Future<SalonService> update(SalonService service) async {
    final data = await _client
        .from(SupabaseTables.services)
        .update(service.toMap())
        .eq('id', service.id)
        .select()
        .single();
    return SalonService.fromMap(data);
  }

  Future<void> archive(String serviceId) => _client
      .from(SupabaseTables.services)
      .update({'is_active': false})
      .eq('id', serviceId);
}
