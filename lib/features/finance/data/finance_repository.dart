import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../pos/domain/payment_method.dart';
import '../domain/finance_summary.dart';

/// Chiffre d'affaires, rapports, dépenses et export comptable.
class FinanceRepository {
  const FinanceRepository(this._client);

  final SupabaseClient _client;

  /// Synthèse du CA sur une période, avec comparaison à la période précédente
  /// et découpage interne pour l'histogramme.
  Future<FinanceSummary> fetchSummary({
    required String salonId,
    required DateTime from,
    required DateTime to,
    int bucketCount = 4,
  }) async {
    final rows = await _fetchTransactions(salonId: salonId, from: from, to: to);

    final span = to.difference(from);
    final previousRows = await _fetchTransactions(
      salonId: salonId,
      from: from.subtract(span),
      to: from,
    );

    var revenue = 0;
    var collected = 0;
    var pending = 0;
    final byMethod = <PaymentMethod, int>{};
    final bucketTotals = List<int>.filled(bucketCount, 0);

    for (final row in rows) {
      final amount = (row['total_amount_fcfa'] as num?)?.toInt() ?? 0;
      final status = row['status'] as String?;
      if (status == 'cancelled' || status == 'refunded') continue;

      revenue += amount;
      if (status == 'paid') {
        collected += amount;
        final method =
            PaymentMethod.fromValue(row['payment_method'] as String?);
        byMethod[method] = (byMethod[method] ?? 0) + amount;
      } else {
        pending += amount;
      }

      final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
      final ratio = span.inMicroseconds == 0
          ? 0.0
          : createdAt.difference(from).inMicroseconds / span.inMicroseconds;
      final index = (ratio * bucketCount).floor().clamp(0, bucketCount - 1);
      bucketTotals[index] += amount;
    }

    final previousRevenue = previousRows.fold<int>(
      0,
      (sum, row) => (row['status'] == 'cancelled' || row['status'] == 'refunded')
          ? sum
          : sum + ((row['total_amount_fcfa'] as num?)?.toInt() ?? 0),
    );

    return FinanceSummary(
      from: from,
      to: to,
      revenueFcfa: revenue,
      ticketCount: rows.length,
      collectedFcfa: collected,
      pendingFcfa: pending,
      previousRevenueFcfa: previousRevenue,
      revenueByMethod: byMethod,
      buckets: [
        for (var i = 0; i < bucketCount; i++)
          FinanceBucket(label: 'S${i + 1}', revenueFcfa: bucketTotals[i]),
      ],
    );
  }

  /// Rapport par coiffeur — fonction Postgres
  /// `stylist_commissions(p_salon_id, p_from, p_to)`.
  Future<List<StylistCommission>> fetchCommissions({
    required String salonId,
    required DateTime from,
    required DateTime to,
  }) async {
    final data = await _client.rpc<List<dynamic>>(
      'stylist_commissions',
      params: {
        'p_salon_id': salonId,
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      },
    );

    return data
        .map((row) => StylistCommission.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Rapport par service — fonction Postgres
  /// `service_performance(p_salon_id, p_from, p_to)`.
  Future<List<ServicePerformance>> fetchServicePerformance({
    required String salonId,
    required DateTime from,
    required DateTime to,
  }) async {
    final data = await _client.rpc<List<dynamic>>(
      'service_performance',
      params: {
        'p_salon_id': salonId,
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      },
    );

    return data
        .map((row) => ServicePerformance.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // --- Dépenses -----------------------------------------------------------

  Future<List<Expense>> fetchExpenses({
    required String salonId,
    required DateTime from,
    required DateTime to,
  }) async {
    final data = await _client
        .from(SupabaseTables.expenses)
        .select()
        .eq('salon_id', salonId)
        .gte('spent_at', from.toUtc().toIso8601String())
        .lt('spent_at', to.toUtc().toIso8601String())
        .order('spent_at', ascending: false);

    return data.map((row) => Expense.fromMap(row)).toList();
  }

  Future<Expense> createExpense(Expense expense) async {
    final data = await _client
        .from(SupabaseTables.expenses)
        .insert(expense.toMap())
        .select()
        .single();
    return Expense.fromMap(data);
  }

  // --- Export -------------------------------------------------------------

  /// Export CSV des transactions d'une période (partage / comptabilité).
  Future<String> exportCsv({
    required String salonId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _fetchTransactions(salonId: salonId, from: from, to: to);

    final buffer = StringBuffer('date;ticket;moyen;sous_total;remise;total\n');
    for (final row in rows) {
      buffer.writeln(
        [
          row['created_at'],
          row['id'],
          row['payment_method'],
          row['subtotal_fcfa'],
          row['discount_fcfa'],
          row['total_amount_fcfa'],
        ].join(';'),
      );
    }
    return buffer.toString();
  }

  /// Envoie l'export au comptable via l'Edge Function `send-accounting-export`.
  Future<void> sendExportToAccountant({
    required String salonId,
    required DateTime from,
    required DateTime to,
    required String format,
  }) async {
    await _client.functions.invoke(
      'send-accounting-export',
      body: {
        'salon_id': salonId,
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'format': format,
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTransactions({
    required String salonId,
    required DateTime from,
    required DateTime to,
  }) {
    return _client
        .from(SupabaseTables.transactions)
        .select()
        .eq('salon_id', salonId)
        .gte('created_at', from.toUtc().toIso8601String())
        .lt('created_at', to.toUtc().toIso8601String())
        .order('created_at');
  }
}
