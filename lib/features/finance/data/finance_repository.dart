import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/services/local_db_service.dart';
import '../../pos/domain/payment_method.dart';
import '../domain/finance_summary.dart';
import '../domain/payout.dart';

/// Chiffre d'affaires, rapports, dépenses et export comptable avec support Offline-First et tolérance aux erreurs RPC.
class FinanceRepository {
  const FinanceRepository(this._client, this._localDb);

  final SupabaseClient _client;
  final LocalDbService _localDb;

  // --- Versements de commission -------------------------------------------

  /// Demandes de versement d'un salon (ou filtrées par membre).
  Future<List<PayoutRequest>> fetchPayouts({
    required String salonId,
    String? profileId,
  }) async {
    var query = _client
        .from(SupabaseTables.payoutRequests)
        .select('*, profiles(full_name)')
        .eq('salon_id', salonId);

    if (profileId != null) {
      query = query.eq('profile_id', profileId);
    }

    final data = await query.order('requested_at', ascending: false);
    return data.map((row) => PayoutRequest.fromMap(row)).toList();
  }

  /// Dépose une demande de versement (pour soi-même ou pour un coiffeur).
  Future<PayoutRequest> requestPayout({
    int? amountFcfa,
    String? profileId,
    String? note,
  }) async {
    final data = await _client.rpc<Map<String, dynamic>>(
      'request_payout',
      params: {
        'p_amount_fcfa': amountFcfa,
        'p_profile_id': profileId,
        'p_note': note,
      },
    );
    return PayoutRequest.fromMap(data);
  }

  /// Valide et règle une demande de versement (gérant).
  Future<PayoutRequest> settlePayout({
    required String requestId,
    required PayoutMethod method,
    String? reference,
  }) async {
    try {
      final data = await _client.rpc<Map<String, dynamic>>(
        'settle_payout',
        params: {
          'p_request_id': requestId,
          'p_method': method.value,
          'p_reference': reference,
        },
      );
      return PayoutRequest.fromMap(data);
    } catch (_) {
      final data = await _client
          .from(SupabaseTables.payoutRequests)
          .update({
            'status': PayoutStatus.paid.value,
            'method': method.value,
            'reference': reference,
            'paid_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId)
          .select('*, profiles(full_name)')
          .single();
      return PayoutRequest.fromMap(data);
    }
  }

  /// Refuse une demande de versement (gérant).
  Future<PayoutRequest> rejectPayout({
    required String requestId,
    String? reason,
  }) async {
    final data = await _client
        .from(SupabaseTables.payoutRequests)
        .update({'status': PayoutStatus.rejected.value, 'note': reason})
        .eq('id', requestId)
        .select('*, profiles(full_name)')
        .single();
    return PayoutRequest.fromMap(data);
  }

  /// Enregistre un versement direct à un coiffeur (gérant).
  Future<PayoutRequest> createDirectPayout({
    required String salonId,
    required String profileId,
    required int amountFcfa,
    required PayoutMethod method,
    String? reference,
    String? note,
  }) async {
    final data = await _client
        .from(SupabaseTables.payoutRequests)
        .insert({
          'salon_id': salonId,
          'profile_id': profileId,
          'amount_fcfa': amountFcfa,
          'status': PayoutStatus.paid.value,
          'method': method.value,
          'reference': reference,
          'note': note,
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('*, profiles(full_name)')
        .single();
    return PayoutRequest.fromMap(data);
  }

  /// Chiffre d'affaires et commissions dues, agrégés par tranche.
  ///
  /// Les tranches sont calendaires — jours d'une semaine, mois d'une année —
  /// donc de largeurs inégales : on ne peut pas les déduire d'un découpage
  /// régulier de la période.
  ///
  /// Tout est calculé à partir d'une seule lecture des transactions et d'une
  /// seule lecture des profils. Interroger la base tranche par tranche
  /// coûterait vingt-quatre allers-retours pour une année.
  Future<List<({int revenueFcfa, int commissionFcfa})>> fetchBucketTotals({
    required String salonId,
    required List<({DateTime from, DateTime to})> buckets,
  }) async {
    if (buckets.isEmpty) return const [];

    final rows = await _fetchTransactions(
      salonId: salonId,
      from: buckets.first.from,
      to: buckets.last.to,
    );

    // Taux de commission par membre, pour n'appliquer que le sien à chaque
    // ligne : un taux moyen fausserait le total dès que deux taux diffèrent.
    final rates = <String, double>{};
    try {
      final staff = await _client
          .from(SupabaseTables.profiles)
          .select('id, commission_rate')
          .eq('salon_id', salonId);
      for (final row in staff) {
        rates[row['id'].toString()] =
            (row['commission_rate'] as num?)?.toDouble() ?? 0;
      }
    } catch (_) {
      // Sans les taux, le chiffre d'affaires reste juste ; seules les
      // commissions tombent à zéro.
    }

    final revenue = List<int>.filled(buckets.length, 0);
    final commission = List<double>.filled(buckets.length, 0);

    for (final row in rows) {
      if (row['status'] != 'paid') continue;

      final createdAtStr = row['created_at'] as String?;
      if (createdAtStr == null) continue;
      final createdAt = DateTime.parse(createdAtStr).toLocal();

      final index = buckets.indexWhere(
        (b) => !createdAt.isBefore(b.from) && createdAt.isBefore(b.to),
      );
      if (index < 0) continue;

      revenue[index] += (row['total_amount_fcfa'] as num?)?.toInt() ?? 0;

      final rawLines = row['lines'];
      final lines = rawLines is String
          ? ((jsonDecode(rawLines) as List?) ?? const [])
          : (rawLines is List ? rawLines : const []);

      for (final line in lines) {
        if (line is! Map<String, dynamic>) continue;
        if (((line['is_product'] ?? line['isProduct']) as bool?) ?? false) {
          continue;
        }

        final stylistId =
            (line['stylist_id'] as String?) ??
            (line['stylistId'] as String?) ??
            (row['cashier_id'] as String?);
        final rate = rates[stylistId] ?? 0;
        if (rate == 0) continue;

        final unit = (line['unit_price_fcfa'] ?? line['unitPriceFcfa']) as num?;
        final qty = (line['quantity'] as num?)?.toInt() ?? 1;
        commission[index] += (unit?.toInt() ?? 0) * qty * rate / 100;
      }
    }

    return [
      for (var i = 0; i < buckets.length; i++)
        (revenueFcfa: revenue[i], commissionFcfa: commission[i].round()),
    ];
  }

  /// Synthèse du CA sur une période.
  Future<FinanceSummary> fetchSummary({
    required String salonId,
    required DateTime from,
    required DateTime to,
    int bucketCount = 4,
    DateTime? previousFrom,
    DateTime? previousTo,
  }) async {
    try {
      final data = await _client.rpc<Map<String, dynamic>>(
        'finance_summary',
        params: {
          'p_salon_id': salonId,
          'p_from': from.toUtc().toIso8601String(),
          'p_to': to.toUtc().toIso8601String(),
          'p_bucket_count': bucketCount,
        },
      );

      return FinanceSummary(
        from: from,
        to: to,
        revenueFcfa: (data['revenue_fcfa'] as num?)?.toInt() ?? 0,
        ticketCount: (data['ticket_count'] as num?)?.toInt() ?? 0,
        collectedFcfa: (data['collected_fcfa'] as num?)?.toInt() ?? 0,
        pendingFcfa: (data['pending_fcfa'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      // Fallback calcul local à partir des transactions de la période
      final rows = await _fetchTransactions(
        salonId: salonId,
        from: from,
        to: to,
      );

      // Période de comparaison. Fournie explicitement, elle est calendaire :
      // reculer d'une durée égale ferait démarrer le « mois précédent » de
      // février le 4 janvier, et le badge « vs janvier » mentirait de trois
      // jours.
      final span = to.difference(from);
      final previousRows = await _fetchTransactions(
        salonId: salonId,
        from: previousFrom ?? from.subtract(span),
        to: previousTo ?? from,
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
          final method = PaymentMethod.fromValue(
            row['payment_method'] as String?,
          );
          byMethod[method] = (byMethod[method] ?? 0) + amount;
        } else {
          pending += amount;
        }

        final createdAtStr = row['created_at'] as String?;
        if (createdAtStr != null) {
          final createdAt = DateTime.parse(createdAtStr).toLocal();
          final ratio = span.inMicroseconds == 0
              ? 0.0
              : createdAt.difference(from).inMicroseconds / span.inMicroseconds;
          final index = (ratio * bucketCount).floor().clamp(0, bucketCount - 1);
          bucketTotals[index] += amount;
        }
      }

      final previousRevenue = previousRows.fold<int>(
        0,
        (sum, row) =>
            (row['status'] == 'cancelled' || row['status'] == 'refunded')
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
  }

  /// Rapport par coiffeur — tente l'RPC Supabase, bascule sur le calcul local en cas d'erreur ou hors-ligne.
  Future<List<StylistCommission>> fetchCommissions({
    required String salonId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
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
    } catch (_) {
      // Fallback calcul en Dart à partir des transactions de la période
      final rows = await _fetchTransactions(
        salonId: salonId,
        from: from,
        to: to,
      );

      // Charger les profils pour récupérer leurs noms et taux de commission
      final profilesMap = <String, Map<String, dynamic>>{};
      try {
        final staffData = await _client
            .from(SupabaseTables.profiles)
            .select()
            .eq('salon_id', salonId);
        for (final p in staffData) {
          profilesMap[p['id'].toString()] = p;
        }
      } catch (_) {
        try {
          final cachedProfiles = await _localDb.getCachedRecords(
            tableName: SupabaseTables.profiles,
            salonId: salonId,
          );
          for (final p in cachedProfiles) {
            profilesMap[p['id'].toString()] = p;
          }
        } catch (_) {}
      }

      final map = <String, Map<String, dynamic>>{};

      for (final row in rows) {
        if (row['status'] != 'paid') continue;

        final rawLines = row['lines'];
        List lines = [];
        if (rawLines is String) {
          try {
            lines = (jsonDecode(rawLines) as List?) ?? const [];
          } catch (_) {}
        } else if (rawLines is List) {
          lines = rawLines;
        }

        // Clé de comptage des clients servis : la fiche si elle existe, le
        // ticket sinon. La caisse n'attache pas toujours un client — « Client
        // de passage » n'en a pas — et ne compter que les fiches affichait
        // « 0 clients » sur un coiffeur qui avait pourtant encaissé.
        final clientId = row['client_id'] as String?;
        final servedKey = (clientId != null && clientId.isNotEmpty)
            ? 'c:$clientId'
            : 't:${row['id']}';

        for (final line in lines) {
          if (line is! Map<String, dynamic>) continue;
          if ((line['is_product'] ?? line['isProduct'] as bool?) ?? false) {
            continue;
          }

          final stylistId =
              (line['stylist_id'] as String?) ??
              (line['stylistId'] as String?) ??
              (row['cashier_id'] as String?) ??
              'unknown';
          final fallbackName =
              (line['stylist_name'] as String?) ??
              (line['stylistName'] as String?) ??
              'Coiffeur';

          final profile = profilesMap[stylistId];
          final name = (profile?['full_name'] as String?) ?? fallbackName;
          final rate = (profile?['commission_rate'] as num?)?.toDouble() ?? 0.0;
          final spec = (profile?['speciality'] as String?) ?? 'Coiffure';

          final qty = (line['quantity'] as num?)?.toInt() ?? 1;
          final price =
              ((line['unit_price_fcfa'] ?? line['unitPriceFcfa']) as num?)
                  ?.toInt() ??
              0;
          final amount = price * qty;

          final entry = map.putIfAbsent(
            stylistId,
            () => {
              'stylist_id': stylistId,
              'stylist_name': name,
              'revenue_fcfa': 0,
              'commission_fcfa': 0,
              'service_count': 0,
              'commission_rate': rate,
              'speciality': spec,
              'client_count': 0,
              'clients': <String>{},
            },
          );

          entry['revenue_fcfa'] = (entry['revenue_fcfa'] as int) + amount;
          entry['service_count'] = (entry['service_count'] as int) + qty;
          (entry['clients'] as Set<String>).add(servedKey);
        }
      }

      for (final entry in map.values) {
        final rev = entry['revenue_fcfa'] as int;
        final rate = (entry['commission_rate'] as num).toDouble();
        entry['commission_fcfa'] = (rev * (rate / 100)).round();
        entry['client_count'] = (entry['clients'] as Set<String>).length;
      }

      return map.values.map(StylistCommission.fromMap).toList();
    }
  }

  /// Rapport par service — tente l'RPC Supabase, bascule sur le calcul local si l'RPC est introuvable ou hors-ligne.
  /// Texte de la ligne, ou [fallback] si la valeur est absente **ou vide**.
  ///
  /// `??` seul laissait passer la chaîne vide : une prestation sans catégorie
  /// produisait une part de l'anneau sans libellé dans la légende — une
  /// couleur qu'on ne pouvait rattacher à rien.
  static String _orDefault(Object? value, String fallback) {
    final text = (value as String?)?.trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Future<List<ServicePerformance>> fetchServicePerformance({
    required String salonId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
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
    } catch (_) {
      // Fallback calcul local à partir des transactions de la période
      final rows = await _fetchTransactions(
        salonId: salonId,
        from: from,
        to: to,
      );
      final map = <String, Map<String, dynamic>>{};

      for (final row in rows) {
        if (row['status'] != 'paid') continue;

        final rawLines = row['lines'];
        List lines = [];
        if (rawLines is String) {
          try {
            lines = (jsonDecode(rawLines) as List?) ?? const [];
          } catch (_) {}
        } else if (rawLines is List) {
          lines = rawLines;
        }

        for (final line in lines) {
          if (line is! Map<String, dynamic>) continue;

          // Les produits revendus comptaient dans le chiffre d'affaires mais
          // étaient écartés d'ici : la répartition annonçait « 100 % du CA »
          // en n'en couvrant qu'une partie. Ils sont désormais retenus, avec
          // le drapeau qui permet de ne pas les compter en prestations.
          final isProduct =
              ((line['is_product'] ?? line['isProduct']) as bool?) ?? false;

          final serviceId =
              (line['ref_id'] ?? line['refId'] as String?) ??
              (line['label'] as String?) ??
              'service';
          final name = _orDefault(
            line['label'],
            isProduct ? 'Produit' : 'Prestation',
          );
          // La catégorie d'un produit est sa marque : la remplacer par
          // « Produits » garde l'anneau lisible — une part par activité, et
          // non une part par marque noyée parmi les prestations.
          final category = isProduct
              ? 'Produits'
              : _orDefault(line['category'], 'Autre');
          final qty = (line['quantity'] as num?)?.toInt() ?? 1;
          final price =
              ((line['unit_price_fcfa'] ?? line['unitPriceFcfa']) as num?)
                  ?.toInt() ??
              0;
          final amount = price * qty;

          final entry = map.putIfAbsent(
            serviceId,
            () => {
              'service_id': serviceId,
              'name': name,
              'category': category,
              'count': 0,
              'revenue_fcfa': 0,
              'is_product': isProduct,
            },
          );

          entry['count'] = (entry['count'] as int) + qty;
          entry['revenue_fcfa'] = (entry['revenue_fcfa'] as int) + amount;
        }
      }

      final list = map.values.map(ServicePerformance.fromMap).toList();
      list.sort((a, b) => b.revenueFcfa.compareTo(a.revenueFcfa));
      return list;
    }
  }

  // --- Dépenses -----------------------------------------------------------

  Future<List<Expense>> fetchExpenses({
    required String salonId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final data = await _client
          .from(SupabaseTables.expenses)
          .select()
          .eq('salon_id', salonId)
          .gte('spent_at', from.toUtc().toIso8601String())
          .lt('spent_at', to.toUtc().toIso8601String())
          .order('spent_at', ascending: false);

      final records = List<Map<String, dynamic>>.from(data);
      await _localDb.cacheRecords(
        tableName: SupabaseTables.expenses,
        salonId: salonId,
        records: records,
      );

      return records.map((row) => Expense.fromMap(row)).toList();
    } catch (_) {
      final cached = await _localDb.getCachedRecords(
        tableName: SupabaseTables.expenses,
        salonId: salonId,
      );

      return cached.map((row) => Expense.fromMap(row)).toList();
    }
  }

  Future<Expense> createExpense(Expense expense) async {
    await _localDb.cacheRecord(
      tableName: SupabaseTables.expenses,
      salonId: expense.salonId,
      record: expense.toMap(),
    );

    try {
      final data = await _client
          .from(SupabaseTables.expenses)
          .insert(expense.toMap())
          .select()
          .single();

      final created = Expense.fromMap(data);
      await _localDb.cacheRecord(
        tableName: SupabaseTables.expenses,
        salonId: expense.salonId,
        record: created.toMap(),
      );

      return created;
    } catch (_) {
      await _localDb.enqueueMutation(
        action: 'INSERT',
        tableName: SupabaseTables.expenses,
        recordId: expense.id,
        payload: expense.toMap(),
      );
      return expense;
    }
  }

  // --- Export -------------------------------------------------------------

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

  Future<void> sendExportToAccountant({
    required String salonId,
    required DateTime from,
    required DateTime to,
    required String format,
  }) async {
    try {
      await _client.functions.invoke(
        'send-accounting-export',
        body: {
          'salon_id': salonId,
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
          'format': format,
        },
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _fetchTransactions({
    required String salonId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final data = await _client
          .from(SupabaseTables.transactions)
          .select()
          .eq('salon_id', salonId)
          .gte('created_at', from.toUtc().toIso8601String())
          .lt('created_at', to.toUtc().toIso8601String())
          .order('created_at', ascending: true);

      final records = List<Map<String, dynamic>>.from(data);
      await _localDb.cacheRecords(
        tableName: SupabaseTables.transactions,
        salonId: salonId,
        records: records,
      );

      return records;
    } catch (_) {
      final cached = await _localDb.getCachedRecords(
        tableName: SupabaseTables.transactions,
        salonId: salonId,
      );

      return cached.where((row) {
        final caStr = row['created_at'] as String?;
        if (caStr == null) return false;
        final ca = DateTime.parse(caStr);
        return (ca.isAfter(from) || ca.isAtSameMomentAs(from)) &&
            ca.isBefore(to);
      }).toList();
    }
  }
}
