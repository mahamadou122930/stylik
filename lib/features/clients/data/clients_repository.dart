import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/services/storage_service.dart';
import '../domain/client.dart';

/// CRM : recherche, création et enrichissement des fiches clients.
class ClientsRepository {
  const ClientsRepository(this._client, this._storage);

  final SupabaseClient _client;
  final StorageService _storage;

  Future<List<Client>> fetchAll({
    required String salonId,
    String? search,
    int limit = 50,
  }) async {
    var query =
        _client.from(SupabaseTables.clients).select().eq('salon_id', salonId);

    if (search != null && search.trim().isNotEmpty) {
      final term = '%${search.trim()}%';
      query = query.or('full_name.ilike.$term,phone.ilike.$term');
    }

    final data = await query.order('full_name').limit(limit);
    return data.map((row) => Client.fromMap(row)).toList();
  }

  Future<Client?> fetchById(String clientId) async {
    final data = await _client
        .from(SupabaseTables.clients)
        .select()
        .eq('id', clientId)
        .maybeSingle();
    return data == null ? null : Client.fromMap(data);
  }

  Future<Client> create(Client client) async {
    final data = await _client
        .from(SupabaseTables.clients)
        .insert(client.toMap())
        .select()
        .single();
    return Client.fromMap(data);
  }

  Future<Client> update(Client client) async {
    final data = await _client
        .from(SupabaseTables.clients)
        .update(client.toMap())
        .eq('id', client.id)
        .select()
        .single();
    return Client.fromMap(data);
  }

  Future<void> delete(String clientId) =>
      _client.from(SupabaseTables.clients).delete().eq('id', clientId);

  /// Téléverse une photo avant/après et met la fiche à jour.
  Future<Client> uploadPhoto({
    required Client client,
    required File file,
    required bool isBefore,
  }) async {
    final url = await _storage.uploadClientPhoto(
      salonId: client.salonId,
      clientId: client.id,
      file: file,
      isBefore: isBefore,
    );

    final data = await _client
        .from(SupabaseTables.clients)
        .update({
          if (isBefore) 'photo_before_url': url else 'photo_after_url': url,
        })
        .eq('id', client.id)
        .select()
        .single();

    return Client.fromMap(data);
  }

  /// Historique des passages du client (rendez-vous les plus récents).
  Future<List<ClientVisit>> fetchHistory(String clientId) async {
    final data = await _client
        .from(SupabaseTables.appointments)
        .select('*, profiles!appointments_stylist_id_fkey(full_name)')
        .eq('client_id', clientId)
        .order('start_time', ascending: false)
        .limit(20);

    return data.map((row) => ClientVisit.fromMap(row)).toList();
  }
}

/// Passage d'un client, affiché dans l'historique de sa fiche.
class ClientVisit {
  const ClientVisit({
    required this.id,
    required this.date,
    required this.label,
    required this.amountFcfa,
    this.stylistName,
  });

  final String id;
  final DateTime date;

  /// Prestations réalisées (« Balayage + brushing »).
  final String label;

  final int amountFcfa;
  final String? stylistName;

  factory ClientVisit.fromMap(Map<String, dynamic> map) => ClientVisit(
        id: map['id'] as String,
        date: DateTime.parse(map['start_time'] as String).toLocal(),
        label: (map['summary'] as String?) ??
            (map['notes'] as String?) ??
            'Prestation',
        amountFcfa: (map['total_price_fcfa'] as num?)?.toInt() ?? 0,
        stylistName: map['profiles'] is Map<String, dynamic>
            ? (map['profiles'] as Map<String, dynamic>)['full_name'] as String?
            : null,
      );
}
