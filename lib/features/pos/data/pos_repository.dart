import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/services/local_db_service.dart';
import '../domain/payment_method.dart';
import '../domain/ticket.dart';

/// Encaissement : création des transactions et consultation des tickets avec support Offline-First.
class PosRepository {
  const PosRepository(this._client, this._localDb);

  final SupabaseClient _client;
  final LocalDbService _localDb;

  /// Encaisse un ticket et retourne la transaction créée.
  Future<SalonTransaction> checkout({
    required String salonId,
    required Ticket ticket,
    required PaymentMethod paymentMethod,
    String? cashierId,
    String? customTransactionId,
    TransactionStatus status = TransactionStatus.paid,
  }) async {
    final transactionId = customTransactionId ?? const Uuid().v4();

    final transaction = SalonTransaction(
      id: transactionId,
      salonId: salonId,
      appointmentId: (ticket.appointmentId?.isNotEmpty ?? false)
          ? ticket.appointmentId
          : null,
      clientId: (ticket.clientId?.isNotEmpty ?? false) ? ticket.clientId : null,
      cashierId: (cashierId?.isNotEmpty ?? false) ? cashierId : null,
      subtotalFcfa: ticket.subtotalFcfa,
      discountFcfa: ticket.discountFcfa,
      totalAmountFcfa: ticket.totalFcfa,
      paymentMethod: paymentMethod,
      status: status,
      lines: ticket.lines,
    );

    final payload = transaction.toMap();

    // 1. Sauvegarder dans le cache local SQLite
    await _localDb.cacheRecord(
      tableName: SupabaseTables.transactions,
      salonId: salonId,
      record: payload,
    );

    try {
      // 2. Envoi idempotent vers Supabase (upsert sur l'UUID v4 client)
      final data = await _client
          .from(SupabaseTables.transactions)
          .upsert(payload, onConflict: 'id')
          .select()
          .single();

      final created = SalonTransaction.fromMap(data);
      await _localDb.cacheRecord(
        tableName: SupabaseTables.transactions,
        salonId: salonId,
        record: created.toMap(),
      );

      // Un ticket mis en attente n'est pas une visite réglée : ni points de
      // fidélité, ni cumul dépensé tant qu'il n'est pas soldé — sinon un
      // brouillon abandonné laisserait la fiche cliente créditée à tort.
      if (created.status == TransactionStatus.paid &&
          created.clientId != null &&
          created.clientId!.isNotEmpty) {
        await _updateClientStatsOnCheckout(
          salonId,
          created.clientId!,
          created.totalAmountFcfa,
        );
      }

      return created;
    } on PostgrestException catch (e) {
      // Une erreur de schéma — colonne inconnue, clé étrangère violée — n'a
      // rien de passager : la rejouer à l'identique échouera pareil. La faire
      // remonter évite d'afficher un reçu pour une vente jamais enregistrée.
      // Seules les pannes réseau justifient la file d'attente hors ligne.
      debugPrint('Encaissement refusé par Supabase : ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Erreur réseau lors de l\'encaissement, mise en file : $e');
      // 3. En cas d'échec réseau, mise en file d'attente pour rejeu idempotent avec le même UUID v4
      await _localDb.enqueueMutation(
        action: 'UPSERT',
        tableName: SupabaseTables.transactions,
        recordId: transactionId,
        payload: payload,
      );

      if (transaction.status == TransactionStatus.paid &&
          transaction.clientId != null &&
          transaction.clientId!.isNotEmpty) {
        await _updateClientStatsOnCheckout(
          salonId,
          transaction.clientId!,
          transaction.totalAmountFcfa,
        );
      }

      return transaction;
    }
  }

  Future<void> _updateClientStatsOnCheckout(
    String salonId,
    String clientId,
    int amountFcfa,
  ) async {
    try {
      final cached = await _localDb.getCachedRecordById(
        tableName: SupabaseTables.clients,
        recordId: clientId,
      );

      final currentVisits = (cached?['visit_count'] as num?)?.toInt() ?? 0;
      final currentSpent = (cached?['total_spent_fcfa'] as num?)?.toInt() ?? 0;
      final currentPoints = (cached?['loyalty_points'] as num?)?.toInt() ?? 0;
      final pointsEarned = (amountFcfa / 1000).floor();
      final nowStr = DateTime.now().toIso8601String();

      final updatedVisits = currentVisits + 1;
      final updatedSpent = currentSpent + amountFcfa;
      final updatedPoints = currentPoints + pointsEarned;

      if (cached != null) {
        final updatedMap = Map<String, dynamic>.from(cached);
        updatedMap['visit_count'] = updatedVisits;
        updatedMap['total_spent_fcfa'] = updatedSpent;
        updatedMap['loyalty_points'] = updatedPoints;
        updatedMap['last_visit_at'] = nowStr;

        await _localDb.cacheRecord(
          tableName: SupabaseTables.clients,
          salonId: salonId,
          record: updatedMap,
        );
      }

      await _client
          .from(SupabaseTables.clients)
          .update({
            'visit_count': updatedVisits,
            'total_spent_fcfa': updatedSpent,
            'loyalty_points': updatedPoints,
            'last_visit_at': nowStr,
          })
          .eq('id', clientId);
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour des stats client: $e');
    }
  }

  /// Tickets d'une journée (clôture de caisse).
  Future<List<SalonTransaction>> fetchDay({
    required String salonId,
    required DateTime day,
  }) {
    final start = DateTime(day.year, day.month, day.day);
    return fetchRange(
      salonId: salonId,
      from: start,
      to: start.add(const Duration(days: 1)),
    );
  }

  /// Tickets encaissés entre [from] inclus et [to] exclu, dates locales.
  ///
  /// Alimente les séries de l'accueil (la semaine en cours, la comparaison au
  /// même jour la semaine passée) : une seule requête plutôt qu'une par jour.
  Future<List<SalonTransaction>> fetchRange({
    required String salonId,
    required DateTime from,
    required DateTime to,
  }) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);

    try {
      final data = await _client
          .from(SupabaseTables.transactions)
          .select('*, clients(full_name, phone)')
          .eq('salon_id', salonId)
          .gte('created_at', start.toUtc().toIso8601String())
          .lt('created_at', end.toUtc().toIso8601String())
          .order('created_at', ascending: false);

      final records = List<Map<String, dynamic>>.from(data);
      await _localDb.cacheRecords(
        tableName: SupabaseTables.transactions,
        salonId: salonId,
        records: records,
      );

      return records.map((row) => SalonTransaction.fromMap(row)).toList();
    } catch (_) {
      final cached = await _localDb.getCachedRecords(
        tableName: SupabaseTables.transactions,
        salonId: salonId,
      );

      final list = cached.map((row) => SalonTransaction.fromMap(row)).where((
        tx,
      ) {
        final ct = tx.createdAt?.toLocal() ?? DateTime.now();
        return !ct.isBefore(start) && ct.isBefore(end);
      }).toList();

      list.sort(
        (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
          a.createdAt ?? DateTime.now(),
        ),
      );
      return list;
    }
  }

  /// Tickets mis en attente, du plus ancien au plus récent.
  ///
  /// Sans borne de date, contrairement au journal de caisse : une ardoise
  /// ouverte lundi et réglée vendredi doit rester visible entre-temps. Les
  /// plus vieux en tête, ce sont ceux qu'on risque d'oublier.
  Future<List<SalonTransaction>> fetchPending({required String salonId}) async {
    try {
      final data = await _client
          .from(SupabaseTables.transactions)
          .select('*, clients(full_name, phone)')
          .eq('salon_id', salonId)
          .eq('status', TransactionStatus.draft.value)
          .order('created_at', ascending: true);

      final records = List<Map<String, dynamic>>.from(data);
      await _localDb.cacheRecords(
        tableName: SupabaseTables.transactions,
        salonId: salonId,
        records: records,
      );

      return records.map(SalonTransaction.fromMap).toList();
    } catch (_) {
      final cached = await _localDb.getCachedRecords(
        tableName: SupabaseTables.transactions,
        salonId: salonId,
      );

      final list = cached
          .map(SalonTransaction.fromMap)
          .where((tx) => tx.status == TransactionStatus.draft)
          .toList();

      list.sort(
        (a, b) => (a.createdAt ?? DateTime.now()).compareTo(
          b.createdAt ?? DateTime.now(),
        ),
      );
      return list;
    }
  }

  Future<SalonTransaction?> fetchById(String transactionId) async {
    try {
      final data = await _client
          .from(SupabaseTables.transactions)
          .select()
          .eq('id', transactionId)
          .maybeSingle();

      if (data != null) {
        await _localDb.cacheRecord(
          tableName: SupabaseTables.transactions,
          salonId: data['salon_id'] as String,
          record: data,
        );
        return SalonTransaction.fromMap(data);
      }
    } catch (_) {}

    final cached = await _localDb.getCachedRecordById(
      tableName: SupabaseTables.transactions,
      recordId: transactionId,
    );
    return cached == null ? null : SalonTransaction.fromMap(cached);
  }

  /// Annulation d'un ticket.
  Future<void> voidTransaction(String transactionId) async {
    final cached = await _localDb.getCachedRecordById(
      tableName: SupabaseTables.transactions,
      recordId: transactionId,
    );

    if (cached != null) {
      cached['status'] = TransactionStatus.cancelled.value;
      await _localDb.cacheRecord(
        tableName: SupabaseTables.transactions,
        salonId: cached['salon_id'] as String,
        record: cached,
      );
    }

    try {
      await _client
          .from(SupabaseTables.transactions)
          .update({'status': TransactionStatus.cancelled.value})
          .eq('id', transactionId);
    } catch (_) {
      await _localDb.enqueueMutation(
        action: 'UPDATE',
        tableName: SupabaseTables.transactions,
        recordId: transactionId,
        payload: {'status': TransactionStatus.cancelled.value},
      );
    }
  }

  /// Rembourse tout ou partie d'un ticket.
  ///
  /// [amountFcfa] est la somme rendue. Égale au total, elle bascule le ticket
  /// en « remboursé » ; inférieure, elle laisse le ticket **payé** et n'en
  /// retire que la part rendue — la vente a bien eu lieu pour le reste.
  ///
  /// Ce montant n'était jusqu'ici écrit nulle part : la table n'avait pas de
  /// colonne pour l'accueillir, et un remboursement partiel annulait donc le
  /// ticket entier.
  Future<void> refund({
    required String transactionId,
    required int amountFcfa,
    required RefundReason reason,
    required int ticketTotalFcfa,
  }) async {
    final isFull = amountFcfa >= ticketTotalFcfa;

    final cached = await _localDb.getCachedRecordById(
      tableName: SupabaseTables.transactions,
      recordId: transactionId,
    );

    if (cached != null) {
      if (isFull) cached['status'] = TransactionStatus.refunded.value;
      cached['refunded_amount_fcfa'] = amountFcfa;
      final currentNotes = (cached['notes'] as String?) ?? '';
      cached['notes'] = '$currentNotes [Remboursé: ${reason.label}]';
      await _localDb.cacheRecord(
        tableName: SupabaseTables.transactions,
        salonId: cached['salon_id'] as String,
        record: cached,
      );
    }

    try {
      await _client.rpc<void>(
        'refund_transaction',
        params: {
          'p_transaction_id': transactionId,
          'p_reason': reason.value,
          'p_amount': amountFcfa,
        },
      );
      return;
    } catch (e) {
      debugPrint(
        'RPC refund_transaction indisponible, mise à jour directe : $e',
      );
    }

    // Repli pour les bases où la fonction n'est pas encore créée.
    try {
      final payload = <String, dynamic>{
        'refunded_amount_fcfa': amountFcfa,
        if (isFull) 'status': TransactionStatus.refunded.value,
      };

      final updated = await _client
          .from(SupabaseTables.transactions)
          .update(payload)
          .eq('id', transactionId)
          // Même borne que la RPC : un ticket déjà remboursé ne l'est pas
          // deux fois.
          .eq('status', TransactionStatus.paid.value)
          .select('id');

      if (updated.isEmpty) {
        throw StateError('Transaction introuvable ou déjà remboursée.');
      }
    } on PostgrestException catch (e) {
      // 42703 : `refunded_amount_fcfa` n'existe pas encore. Un remboursement
      // intégral reste exprimable par le seul statut, on le passe. Un
      // remboursement partiel, lui, serait enregistré comme total : mieux vaut
      // le refuser que rendre 1 000 F et en retirer 5 000 du chiffre.
      if (e.code == '42703') {
        if (!isFull) {
          throw StateError(
            'Remboursement partiel indisponible : la base doit être mise à '
            'jour (migration 20260826_partial_refunds).',
          );
        }
        await _client
            .from(SupabaseTables.transactions)
            .update({'status': TransactionStatus.refunded.value})
            .eq('id', transactionId)
            .eq('status', TransactionStatus.paid.value);
        return;
      }

      // Refus de la base — droits, contrainte : rejouer n'y changera rien.
      // Sans ce `rethrow`, l'écran annonçait « Remboursement enregistré »
      // alors que la vente restait payée en caisse.
      debugPrint('Remboursement refusé : ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      // Panne réseau : l'opération est légitime, on la rejouera.
      debugPrint('Remboursement différé, mise en file : $e');
      await _localDb.enqueueMutation(
        action: 'UPDATE',
        tableName: SupabaseTables.transactions,
        recordId: transactionId,
        payload: {
          'refunded_amount_fcfa': amountFcfa,
          if (isFull) 'status': TransactionStatus.refunded.value,
        },
      );
    }
  }

  Future<void> sendReceipt({
    required String transactionId,
    String? phone,
  }) async {
    try {
      await _client.functions.invoke(
        'send-receipt',
        body: {'transaction_id': transactionId, 'phone': phone},
      );
    } catch (_) {}
  }
}
