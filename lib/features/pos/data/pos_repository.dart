import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../domain/payment_method.dart';
import '../domain/ticket.dart';

/// Encaissement : création des transactions et consultation des tickets.
class PosRepository {
  const PosRepository(this._client);

  final SupabaseClient _client;

  /// Encaisse un ticket et retourne la transaction créée.
  ///
  /// Les effets de bord (décrément du stock produit, points de fidélité,
  /// commissions) sont assurés côté Postgres par la fonction `checkout_ticket`
  /// afin de garantir l'atomicité.
  Future<SalonTransaction> checkout({
    required String salonId,
    required Ticket ticket,
    required PaymentMethod paymentMethod,
    String? cashierId,
  }) async {
    final transaction = SalonTransaction(
      id: '',
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

    final data = await _client
        .from(SupabaseTables.transactions)
        .insert(transaction.toMap())
        .select()
        .single();

    return SalonTransaction.fromMap(data);
  }

  /// Tickets d'une journée (clôture de caisse).
  Future<List<SalonTransaction>> fetchDay({
    required String salonId,
    required DateTime day,
  }) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final data = await _client
        .from(SupabaseTables.transactions)
        .select('*, clients(full_name)')
        .eq('salon_id', salonId)
        .gte('created_at', start.toUtc().toIso8601String())
        .lt('created_at', end.toUtc().toIso8601String())
        .order('created_at', ascending: false);

    return data.map((row) => SalonTransaction.fromMap(row)).toList();
  }

  Future<SalonTransaction?> fetchById(String transactionId) async {
    final data = await _client
        .from(SupabaseTables.transactions)
        .select()
        .eq('id', transactionId)
        .maybeSingle();
    return data == null ? null : SalonTransaction.fromMap(data);
  }

  /// Annulation d'un ticket (réservée au gérant).
  Future<void> voidTransaction(String transactionId) => _client
      .from(SupabaseTables.transactions)
      .update({'status': TransactionStatus.cancelled.value})
      .eq('id', transactionId);

  /// Remboursement total ou partiel d'un ticket.
  ///
  /// La fonction Postgres `refund_transaction` crée la transaction de
  /// contrepartie, restaure les points de fidélité et le stock des produits
  /// rendus.
  Future<void> refund({
    required String transactionId,
    required int amountFcfa,
    required RefundReason reason,
  }) {
    return _client.rpc<void>(
      'refund_transaction',
      params: {
        'p_transaction_id': transactionId,
        'p_amount_fcfa': amountFcfa,
        'p_reason': reason.value,
      },
    );
  }

  /// Envoie le reçu au client (Edge Function `send-receipt`).
  Future<void> sendReceipt({
    required String transactionId,
    String? phone,
  }) async {
    await _client.functions.invoke(
      'send-receipt',
      body: {'transaction_id': transactionId, 'phone': phone},
    );
  }
}
