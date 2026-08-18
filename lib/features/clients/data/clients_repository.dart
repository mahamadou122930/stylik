import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/services/local_db_service.dart';
import '../../../core/services/storage_service.dart';
import '../domain/client.dart';

/// CRM : recherche, création et enrichissement des fiches clients avec support Offline-First.
class ClientsRepository {
  const ClientsRepository(this._client, this._storage, this._localDb);

  final SupabaseClient _client;
  final StorageService _storage;
  final LocalDbService _localDb;

  Future<List<Client>> fetchAll({
    required String salonId,
    String? search,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from(SupabaseTables.clients)
          .select()
          .eq('salon_id', salonId);

      if (search != null && search.trim().isNotEmpty) {
        final term = '%${search.trim()}%';
        query = query.or('full_name.ilike.$term,phone.ilike.$term');
      }

      final data = await query.order('full_name', ascending: true).limit(limit);

      // Mettre en cache local
      final records = List<Map<String, dynamic>>.from(data);
      await _localDb.cacheRecords(
        tableName: SupabaseTables.clients,
        salonId: salonId,
        records: records,
      );

      return records.map((row) => Client.fromMap(row)).toList();
    } catch (_) {
      // Fallback sur le cache local en cas de panne réseau
      final cached = await _localDb.getCachedRecords(
        tableName: SupabaseTables.clients,
        salonId: salonId,
      );

      var clients = cached.map((row) => Client.fromMap(row)).toList();

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim().toLowerCase();
        clients = clients.where((c) {
          return c.fullName.toLowerCase().contains(term) ||
              c.phone.contains(term);
        }).toList();
      }

      clients.sort((a, b) => a.fullName.compareTo(b.fullName));
      return clients.take(limit).toList();
    }
  }

  Future<Client?> fetchById(String clientId) async {
    try {
      final data = await _client
          .from(SupabaseTables.clients)
          .select()
          .eq('id', clientId)
          .maybeSingle();

      if (data != null) {
        await _localDb.cacheRecord(
          tableName: SupabaseTables.clients,
          salonId: data['salon_id'] as String,
          record: data,
        );
        return Client.fromMap(data);
      }
    } catch (_) {
      // Fallback cache local
    }

    final cached = await _localDb.getCachedRecordById(
      tableName: SupabaseTables.clients,
      recordId: clientId,
    );
    return cached == null ? null : Client.fromMap(cached);
  }

  Future<Client> create(Client client) async {
    // 1. Sauvegarder immédiatement dans le cache local
    await _localDb.cacheRecord(
      tableName: SupabaseTables.clients,
      salonId: client.salonId,
      record: client.toMap(),
    );

    try {
      // 2. Tenter d'envoyer à Supabase
      final data = await _client
          .from(SupabaseTables.clients)
          .insert(client.toMap())
          .select()
          .single();

      final createdClient = Client.fromMap(data);
      await _localDb.cacheRecord(
        tableName: SupabaseTables.clients,
        salonId: client.salonId,
        record: createdClient.toMap(),
      );

      return createdClient;
    } catch (_) {
      // 3. En cas d'échec réseau, enregistrer dans la file de synchro
      await _localDb.enqueueMutation(
        action: 'INSERT',
        tableName: SupabaseTables.clients,
        recordId: client.id,
        payload: client.toMap(),
      );
      return client;
    }
  }

  Future<Client> update(Client client) async {
    await _localDb.cacheRecord(
      tableName: SupabaseTables.clients,
      salonId: client.salonId,
      record: client.toMap(),
    );

    try {
      final data = await _client
          .from(SupabaseTables.clients)
          .update(client.toMap())
          .eq('id', client.id)
          .select()
          .single();

      return Client.fromMap(data);
    } catch (_) {
      await _localDb.enqueueMutation(
        action: 'UPDATE',
        tableName: SupabaseTables.clients,
        recordId: client.id,
        payload: client.toMap(),
      );
      return client;
    }
  }

  Future<void> delete(String clientId) async {
    await _localDb.deleteCachedRecord(
      tableName: SupabaseTables.clients,
      recordId: clientId,
    );

    try {
      await _client.from(SupabaseTables.clients).delete().eq('id', clientId);
    } catch (_) {
      await _localDb.enqueueMutation(
        action: 'DELETE',
        tableName: SupabaseTables.clients,
        recordId: clientId,
        payload: {'id': clientId},
      );
    }
  }

  /// Téléverse une photo avant/après et met la fiche à jour avec support offline.
  Future<Client> uploadPhoto({
    required Client client,
    required File file,
    required bool isBefore,
  }) async {
    String url = file.path; // Fallback local

    try {
      url = await _storage.uploadClientPhoto(
        salonId: client.salonId,
        clientId: client.id,
        file: file,
        isBefore: isBefore,
      );
    } catch (_) {
      // En mode hors-ligne, on utilise le chemin de fichier local temporaire
    }

    final updated = client.copyWith(
      photoBeforeUrl: isBefore ? url : client.photoBeforeUrl,
      photoAfterUrl: !isBefore ? url : client.photoAfterUrl,
    );

    return update(updated);
  }

  /// Historique des passages et ventes du client (rendez-vous et transactions caisse).
  Future<List<ClientVisit>> fetchHistory(
    String clientId, {
    String? salonId,
  }) async {
    final visits = <ClientVisit>[];

    try {
      final transactionsData = await _client
          .from(SupabaseTables.transactions)
          .select('*, profiles!transactions_cashier_id_fkey(full_name)')
          .eq('client_id', clientId)
          .order('created_at', ascending: false)
          .limit(20);

      for (final row in transactionsData) {
        visits.add(ClientVisit.fromTransaction(row));
      }
    } catch (_) {}

    try {
      final appointmentsData = await _client
          .from(SupabaseTables.appointments)
          .select('*, profiles!appointments_stylist_id_fkey(full_name)')
          .eq('client_id', clientId)
          .order('start_time', ascending: false)
          .limit(20);

      for (final row in appointmentsData) {
        visits.add(ClientVisit.fromMap(row));
      }
    } catch (_) {}

    if (visits.isEmpty && salonId != null && salonId.isNotEmpty) {
      final cachedTransactions = await _localDb.getCachedRecords(
        tableName: SupabaseTables.transactions,
        salonId: salonId,
      );
      for (final row in cachedTransactions) {
        if (row['client_id'] == clientId) {
          visits.add(ClientVisit.fromTransaction(row));
        }
      }
    }

    visits.sort((a, b) => b.date.compareTo(a.date));
    return visits;
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
    this.isTransaction = false,
  });

  final String id;
  final DateTime date;
  final String label;
  final int amountFcfa;
  final String? stylistName;
  final bool isTransaction;

  factory ClientVisit.fromMap(Map<String, dynamic> map) => ClientVisit(
    id: (map['id'] as String?) ?? '',
    date: map['start_time'] != null
        ? DateTime.parse(map['start_time'] as String).toLocal()
        : DateTime.now(),
    label:
        (map['summary'] as String?) ??
        (map['notes'] as String?) ??
        'Prestation RDV',
    amountFcfa: (map['total_price_fcfa'] as num?)?.toInt() ?? 0,
    stylistName: map['profiles'] is Map<String, dynamic>
        ? (map['profiles'] as Map<String, dynamic>)['full_name'] as String?
        : null,
  );

  factory ClientVisit.fromTransaction(Map<String, dynamic> map) {
    final linesRaw = map['lines'];
    String summary = 'Achat / Ticket caisse';
    if (linesRaw is List && linesRaw.isNotEmpty) {
      final labels = linesRaw
          .map((l) => l['label'] ?? l['name'] ?? l['service_name'] ?? '')
          .where((l) => l.toString().isNotEmpty)
          .join(', ');
      if (labels.isNotEmpty) summary = labels;
    }

    return ClientVisit(
      id: (map['id'] as String?) ?? '',
      date: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String).toLocal()
          : DateTime.now(),
      label: summary,
      amountFcfa:
          (map['total_amount_fcfa'] as num?)?.toInt() ??
          (map['total_amount'] as num?)?.toInt() ??
          0,
      stylistName: map['profiles'] is Map<String, dynamic>
          ? (map['profiles'] as Map<String, dynamic>)['full_name'] as String?
          : null,
      isTransaction: true,
    );
  }
}
