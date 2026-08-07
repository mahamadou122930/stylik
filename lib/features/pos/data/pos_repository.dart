import 'package:supabase_flutter/supabase_flutter.dart';

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
  }) async {
    final localId = 'tx_${DateTime.now().millisecondsSinceEpoch}';

    final transaction = SalonTransaction(
      id: localId,
      salonId: salonId,
      appointmentId: ticket.appointmentId,
      clientId: ticket.clientId,
      cashierId: cashierId,
      subtotalFcfa: ticket.subtotalFcfa,
      discountFcfa: ticket.discountFcfa,
      totalAmountFcfa: ticket.totalFcfa,
      paymentMethod: paymentMethod,
      status: TransactionStatus.paid,
      lines: ticket.lines,
    );

    final map = transaction.toMap();
    if (map['id'] == null || map['id'] == '') {
      map['id'] = localId;
    }

    // 1. Sauvegarder dans le cache local SQLite
    await _localDb.cacheRecord(
      tableName: SupabaseTables.transactions,
      salonId: salonId,
      record: map,
    );

    try {
      // 2. Tenter l'envoi vers Supabase
      final data = await _client
          .from(SupabaseTables.transactions)
          .insert(map)
          .select()
          .single();

      final created = SalonTransaction.fromMap(data);
      await _localDb.cacheRecord(
        tableName: SupabaseTables.transactions,
        salonId: salonId,
        record: created.toMap(),
      );

      return created;
    } catch (_) {
      // 3. En cas d'échec réseau, mettre en file d'attente
      await _localDb.enqueueMutation(
        action: 'INSERT',
        tableName: SupabaseTables.transactions,
        recordId: localId,
        payload: map,
      );
      return transaction;
    }
  }

  /// Tickets d'une journée (clôture de caisse).
  Future<List<SalonTransaction>> fetchDay({
    required String salonId,
    required DateTime day,
  }) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    try {
      final data = await _client
          .from(SupabaseTables.transactions)
          .select('*, clients(full_name)')
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

      final list = cached.map((row) => SalonTransaction.fromMap(row)).where((tx) {
        final ct = tx.createdAt?.toLocal() ?? DateTime.now();
        return ct.year == day.year && ct.month == day.month && ct.day == day.day;
      }).toList();

      list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
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

  Future<void> refund({
    required String transactionId,
    required int amountFcfa,
    required RefundReason reason,
  }) async {
    try {
      await _client.rpc<void>(
        'refund_transaction',
        params: {
          'p_transaction_id': transactionId,
          'p_amount_fcfa': amountFcfa,
          'p_reason': reason.value,
        },
      );
    } catch (_) {}
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
