import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/inventory_repository.dart';
import '../domain/product.dart';

import '../../../core/services/local_db_service.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localDbServiceProvider),
  ),
);

/// Tous les produits actifs du salon.
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(inventoryRepositoryProvider).fetchAll(salonId: salonId);
});

/// Produits sous le seuil d'alerte.
final lowStockProductsProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(productsProvider).valueOrNull ?? const [];
  return products.where((product) => product.isLowStock).toList();
});

/// Valeur totale du stock, au prix d'achat.
final stockValueProvider = Provider<int>((ref) {
  final products = ref.watch(productsProvider).valueOrNull ?? const [];
  return products.fold(0, (sum, product) => sum + product.stockValueFcfa);
});

/// Fiche produit.
final productDetailProvider =
    FutureProvider.family<Product?, String>((ref, productId) {
  return ref.watch(inventoryRepositoryProvider).fetchById(productId);
});

/// Consommations en cabine du jour.
final todayConsumptionProvider =
    FutureProvider<List<StockMovement>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  return ref.watch(inventoryRepositoryProvider).fetchMovements(
        salonId: salonId,
        from: start,
        to: start.add(const Duration(days: 1)),
        reason: 'consumption',
      );
});

/// Consommations du mois, pour le coût et le classement des produits.
final monthConsumptionProvider =
    FutureProvider<List<StockMovement>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final now = DateTime.now();
  final start = DateTime(now.year, now.month);
  return ref.watch(inventoryRepositoryProvider).fetchMovements(
        salonId: salonId,
        from: start,
        to: DateTime(now.year, now.month + 1),
        reason: 'consumption',
      );
});

/// Coût des produits consommés ce mois.
final monthConsumptionCostProvider = Provider<int>((ref) {
  final movements = ref.watch(monthConsumptionProvider).valueOrNull ?? const [];
  return movements.fold(0, (sum, movement) => sum + movement.costFcfa);
});

/// Coût consommé par produit ce mois, du plus élevé au plus faible.
final topConsumedProductsProvider =
    Provider<List<({String name, int costFcfa})>>((ref) {
  final movements = ref.watch(monthConsumptionProvider).valueOrNull ?? const [];

  final totals = <String, int>{};
  for (final movement in movements) {
    final name = movement.productName ?? 'Produit';
    totals[name] = (totals[name] ?? 0) + movement.costFcfa;
  }

  final entries = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return [
    for (final entry in entries.take(5))
      (name: entry.key, costFcfa: entry.value),
  ];
});
