import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/services/local_db_service.dart';
import '../domain/product.dart';

/// Stock : inventaire, réception fournisseur et consommation en cabine avec support Offline-First.
class InventoryRepository {
  const InventoryRepository(this._client, this._localDb);

  final SupabaseClient _client;
  final LocalDbService _localDb;

  Future<List<Product>> fetchAll({
    required String salonId,
    bool onlyLowStock = false,
  }) async {
    try {
      final data = await _client
          .from(SupabaseTables.products)
          .select()
          .eq('salon_id', salonId)
          .eq('is_active', true)
          .order('name', ascending: true);

      final records = List<Map<String, dynamic>>.from(data);
      await _localDb.cacheRecords(
        tableName: SupabaseTables.products,
        salonId: salonId,
        records: records,
      );

      final products = records.map((row) => Product.fromMap(row)).toList();
      return onlyLowStock
          ? products.where((product) => product.isLowStock).toList()
          : products;
    } catch (_) {
      final cached = await _localDb.getCachedRecords(
        tableName: SupabaseTables.products,
        salonId: salonId,
      );

      var products = cached.map((row) => Product.fromMap(row)).toList();
      products = products.where((p) => p.isActive).toList();
      products.sort((a, b) => a.name.compareTo(b.name));

      return onlyLowStock
          ? products.where((product) => product.isLowStock).toList()
          : products;
    }
  }

  Future<Product?> fetchById(String productId) async {
    try {
      final data = await _client
          .from(SupabaseTables.products)
          .select()
          .eq('id', productId)
          .maybeSingle();

      if (data != null) {
        await _localDb.cacheRecord(
          tableName: SupabaseTables.products,
          salonId: data['salon_id'] as String,
          record: data,
        );
        return Product.fromMap(data);
      }
    } catch (_) {}

    final cached = await _localDb.getCachedRecordById(
      tableName: SupabaseTables.products,
      recordId: productId,
    );
    return cached == null ? null : Product.fromMap(cached);
  }

  Future<Product> create(Product product) async {
    await _localDb.cacheRecord(
      tableName: SupabaseTables.products,
      salonId: product.salonId,
      record: product.toMap(),
    );

    try {
      final data = await _client
          .from(SupabaseTables.products)
          .insert(product.toMap())
          .select()
          .single();

      final created = Product.fromMap(data);
      await _localDb.cacheRecord(
        tableName: SupabaseTables.products,
        salonId: product.salonId,
        record: created.toMap(),
      );

      return created;
    } catch (_) {
      await _localDb.enqueueMutation(
        action: 'INSERT',
        tableName: SupabaseTables.products,
        recordId: product.id,
        payload: product.toMap(),
      );
      return product;
    }
  }

  Future<Product> update(Product product) async {
    await _localDb.cacheRecord(
      tableName: SupabaseTables.products,
      salonId: product.salonId,
      record: product.toMap(),
    );

    try {
      final data = await _client
          .from(SupabaseTables.products)
          .update(product.toMap())
          .eq('id', product.id)
          .select()
          .single();

      return Product.fromMap(data);
    } catch (_) {
      await _localDb.enqueueMutation(
        action: 'UPDATE',
        tableName: SupabaseTables.products,
        recordId: product.id,
        payload: product.toMap(),
      );
      return product;
    }
  }

  Future<void> adjustStock({
    required String productId,
    required int delta,
    required String reason,
    String? contextLabel,
  }) async {
    final cached = await _localDb.getCachedRecordById(
      tableName: SupabaseTables.products,
      recordId: productId,
    );

    if (cached != null) {
      final currentStock = (cached['stock_quantity'] as num?)?.toInt() ?? 0;
      cached['stock_quantity'] = currentStock + delta;
      await _localDb.cacheRecord(
        tableName: SupabaseTables.products,
        salonId: cached['salon_id'] as String,
        record: cached,
      );
    }

    try {
      await _client.rpc<void>(
        'adjust_stock',
        params: {
          'p_product_id': productId,
          'p_delta': delta,
          'p_reason': reason,
          'p_context': contextLabel,
        },
      );
      return;
    } catch (e) {
      debugPrint('RPC adjust_stock indisponible, ajustement direct : $e');
    }

    // Repli en deux écritures, pour les bases où `adjust_stock` n'est pas
    // encore corrigée. Il n'est pas atomique — deux ajustements simultanés
    // sur le même produit peuvent s'écraser — mais sans lui le bouton reste
    // sans effet, ce qui est pire qu'une fenêtre de concurrence.
    try {
      final row = await _client
          .from(SupabaseTables.products)
          .select('salon_id, name, stock_quantity, unit_cost_fcfa')
          .eq('id', productId)
          .single();

      final salonId = row['salon_id'] as String;
      final current = (row['stock_quantity'] as num?)?.toInt() ?? 0;
      final unitCost = (row['unit_cost_fcfa'] as num?)?.toInt() ?? 0;
      // Même borne que la RPC : un stock négatif n'a pas de sens physique.
      final next = (current + delta).clamp(0, 1 << 31);

      await _client
          .from(SupabaseTables.products)
          .update({'stock_quantity': next})
          .eq('id', productId);

      await _client.from(SupabaseTables.stockMovements).insert({
        'salon_id': salonId,
        'product_id': productId,
        // Quantité signée : c'est le signe qui distingue une entrée d'une
        // sortie, la table n'ayant pas de colonne de type.
        'quantity': delta,
        'reason': reason,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        'product_name': row['name'],
        'context_label': contextLabel,
        'cost_fcfa': delta.abs() * unitCost,
      });
    } catch (e) {
      debugPrint('Ajustement du stock impossible : $e');
      if (cached != null) {
        await _localDb.enqueueMutation(
          action: 'UPDATE',
          tableName: SupabaseTables.products,
          recordId: productId,
          payload: {'stock_quantity': cached['stock_quantity']},
        );
      }
      rethrow;
    }
  }

  Future<void> receiveDelivery({
    required Map<String, int> quantitiesByProductId,
    String? supplierLabel,
  }) async {
    for (final entry in quantitiesByProductId.entries) {
      if (entry.value <= 0) continue;
      await adjustStock(
        productId: entry.key,
        delta: entry.value,
        reason: 'reception',
        contextLabel: supplierLabel,
      );
    }
  }

  /// Sortie de stock des produits d'un ticket encaissé.
  ///
  /// Le motif `sale` reste distinct de `consumption` : un produit revendu part
  /// contre du chiffre d'affaires, un consommable ouvert contre une charge.
  /// Les confondre gonflerait le coût des consommables du mois du montant des
  /// ventes.
  Future<void> releaseSold({
    required Map<String, int> quantitiesByProductId,
    String? contextLabel,
  }) => _applyMovements(
    quantitiesByProductId,
    sign: -1,
    reason: 'sale',
    contextLabel: contextLabel,
  );

  /// Retour en stock des produits d'un ticket remboursé ou annulé.
  Future<void> restockRefunded({
    required Map<String, int> quantitiesByProductId,
    String? contextLabel,
  }) => _applyMovements(
    quantitiesByProductId,
    sign: 1,
    reason: 'refund',
    contextLabel: contextLabel,
  );

  /// Applique un mouvement par produit, sans qu'une ligne en échec n'empêche
  /// les suivantes : un produit supprimé de la fiche ne doit pas bloquer la
  /// sortie de stock des autres articles du même ticket. La première erreur
  /// est relancée à la fin, pour que l'appelant puisse la signaler.
  Future<void> _applyMovements(
    Map<String, int> quantitiesByProductId, {
    required int sign,
    required String reason,
    String? contextLabel,
  }) async {
    Object? firstError;

    for (final entry in quantitiesByProductId.entries) {
      if (entry.value <= 0) continue;
      try {
        await adjustStock(
          productId: entry.key,
          delta: sign * entry.value,
          reason: reason,
          contextLabel: contextLabel,
        );
      } catch (error) {
        firstError ??= error;
      }
    }

    if (firstError != null) throw firstError;
  }

  Future<void> consumeStock({
    required String productId,
    required int quantity,
    String? contextLabel,
  }) => adjustStock(
    productId: productId,
    delta: -quantity,
    reason: 'consumption',
    contextLabel: contextLabel,
  );

  Future<List<StockMovement>> fetchMovements({
    required String salonId,
    required DateTime from,
    required DateTime to,
    String? reason,
  }) async {
    try {
      var query = _client
          .from(SupabaseTables.stockMovements)
          .select('*, products(name)')
          .eq('salon_id', salonId)
          .gte('occurred_at', from.toUtc().toIso8601String())
          .lt('occurred_at', to.toUtc().toIso8601String());

      if (reason != null) query = query.eq('reason', reason);

      final data = await query.order('occurred_at', ascending: false);
      return data.map((row) => StockMovement.fromMap(row)).toList();
    } catch (_) {
      return const [];
    }
  }
}
