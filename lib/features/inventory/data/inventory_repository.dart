import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../domain/product.dart';

/// Stock : inventaire, réception fournisseur et consommation en cabine.
class InventoryRepository {
  const InventoryRepository(this._client);

  final SupabaseClient _client;

  Future<List<Product>> fetchAll({
    required String salonId,
    bool onlyLowStock = false,
  }) async {
    final data = await _client
        .from(SupabaseTables.products)
        .select()
        .eq('salon_id', salonId)
        .eq('is_active', true)
        .order('name');

    final products = data.map((row) => Product.fromMap(row)).toList();
    return onlyLowStock
        ? products.where((product) => product.isLowStock).toList()
        : products;
  }

  Future<Product?> fetchById(String productId) async {
    final data = await _client
        .from(SupabaseTables.products)
        .select()
        .eq('id', productId)
        .maybeSingle();
    return data == null ? null : Product.fromMap(data);
  }

  Future<Product> create(Product product) async {
    final data = await _client
        .from(SupabaseTables.products)
        .insert(product.toMap())
        .select()
        .single();
    return Product.fromMap(data);
  }

  Future<Product> update(Product product) async {
    final data = await _client
        .from(SupabaseTables.products)
        .update(product.toMap())
        .eq('id', product.id)
        .select()
        .single();
    return Product.fromMap(data);
  }

  /// Ajuste le stock d'un produit et journalise le mouvement.
  ///
  /// S'appuie sur la fonction Postgres `adjust_stock`, qui écrit dans
  /// `stock_movements` et met `products.stock_quantity` à jour de façon
  /// atomique.
  Future<void> adjustStock({
    required String productId,
    required int delta,
    required String reason,
    String? contextLabel,
  }) {
    return _client.rpc<void>(
      'adjust_stock',
      params: {
        'p_product_id': productId,
        'p_delta': delta,
        'p_reason': reason,
        'p_context': contextLabel,
      },
    );
  }

  /// Réception fournisseur : incrémente le stock des lignes livrées.
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

  /// Sortie de stock (consommation en cabine, casse).
  Future<void> consumeStock({
    required String productId,
    required int quantity,
    String? contextLabel,
  }) =>
      adjustStock(
        productId: productId,
        delta: -quantity,
        reason: 'consumption',
        contextLabel: contextLabel,
      );

  /// Mouvements de stock d'une période, les plus récents en premier.
  Future<List<StockMovement>> fetchMovements({
    required String salonId,
    required DateTime from,
    required DateTime to,
    String? reason,
  }) async {
    var query = _client
        .from(SupabaseTables.stockMovements)
        .select('*, products(name)')
        .eq('salon_id', salonId)
        .gte('occurred_at', from.toUtc().toIso8601String())
        .lt('occurred_at', to.toUtc().toIso8601String());

    if (reason != null) query = query.eq('reason', reason);

    final data = await query.order('occurred_at', ascending: false);
    return data.map((row) => StockMovement.fromMap(row)).toList();
  }
}
