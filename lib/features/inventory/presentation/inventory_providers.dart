import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../../core/utils/formatters.dart';
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
/// Texte saisi dans la barre de recherche de l'inventaire.
final productSearchProvider = StateProvider<String>((ref) => '');

/// Usage sélectionné dans l'inventaire. `null` = tous les produits.
final productUsageFilterProvider = StateProvider<ProductUsage?>((ref) => null);

/// Produits filtrés par la recherche et l'usage.
///
/// La recherche porte sur le nom, la marque, la catégorie et le fournisseur :
/// dans un stock, on cherche aussi bien « Kérastase » que « coloration ».
final filteredProductsProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(productsProvider).valueOrNull ?? const [];
  // Accents et casse neutralisés des deux côtés : « kerastase » retrouve
  // « Kérastase », et réciproquement.
  final query = Formatters.searchable(ref.watch(productSearchProvider).trim());
  final usage = ref.watch(productUsageFilterProvider);

  return products.where((product) {
    if (usage != null && product.usage != usage) return false;
    if (query.isEmpty) return true;

    final haystack = Formatters.searchable(
      [
        product.name,
        product.brand,
        product.category,
        product.supplier ?? '',
      ].join(' '),
    );
    return haystack.contains(query);
  }).toList();
});

final lowStockProductsProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(productsProvider).valueOrNull ?? const [];
  return products.where((product) => product.isLowStock).toList();
});

/// Valeur totale du stock, au prix d'achat.
///
/// Revente et consommables comptent pareil : ce que le salon détient vaut ce
/// qu'il l'a payé, quel que soit l'usage prévu.
final stockValueProvider = Provider<int>((ref) {
  final products = ref.watch(productsProvider).valueOrNull ?? const [];
  return products.fold(0, (sum, product) => sum + product.stockValueFcfa);
});

/// Produits en stock dont le coût d'achat n'est pas renseigné.
///
/// La valeur du stock se calcule au prix d'achat : une fiche à zéro n'y pèse
/// rien et fait silencieusement mentir le total. Le champ est désormais
/// obligatoire à la saisie, mais les fiches créées avant restent à corriger.
final productsWithoutCostProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(productsProvider).valueOrNull ?? const [];
  return products
      .where(
        (product) => product.unitCostFcfa <= 0 && product.stockQuantity > 0,
      )
      .toList();
});

/// Consommables encore en stock, dans l'ordre alphabétique.
final consumablesProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(productsProvider).valueOrNull ?? const [];
  return products
      .where((product) => product.usage == ProductUsage.consumable)
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

/// Méthode A — déduction par ouverture d'unité.
///
/// Le stock d'un consommable se compte en contenants, pas en millilitres : on
/// retire une unité entière au moment où le flacon est entamé, et plus rien
/// ensuite jusqu'au suivant. Le coût du mois est donc celui des contenants
/// ouverts, ce qui suffit à piloter les achats sans demander à l'équipe de
/// peser chaque dose.
///
/// Partagée par la fiche produit et l'écran Consommation, pour que les deux
/// portes d'entrée produisent exactement le même mouvement.
/// Retourne le message à afficher, succès ou échec. L'écriture peut échouer
/// — RPC absente, réseau coupé — et annoncer « 1 unité déduite » sur un stock
/// resté intact serait pire que de ne rien afficher.
Future<String> openConsumableUnit(WidgetRef ref, Product product) async {
  if (product.stockQuantity <= 0) {
    return 'Stock épuisé : réceptionnez d\'abord une livraison.';
  }

  try {
    await ref
        .read(inventoryRepositoryProvider)
        .adjustStock(
          productId: product.id,
          delta: -1,
          reason: 'consumption',
          contextLabel: product.packaging == null
              ? 'Unité ouverte'
              : 'Unité ouverte · ${product.packaging}',
        );
  } catch (error) {
    return 'Stock non modifié : $error';
  }

  ref.invalidate(productDetailProvider(product.id));
  ref.invalidate(productsProvider);
  // Le mouvement alimente « Consommation » : ses compteurs du jour et du mois
  // doivent repartir en lecture.
  ref.invalidate(todayConsumptionProvider);
  ref.invalidate(monthConsumptionProvider);

  return '1 unité de « ${product.name} » déduite · '
      'reste ${product.stockQuantity - 1}.';
}

/// Fiche produit.
final productDetailProvider = FutureProvider.family<Product?, String>((
  ref,
  productId,
) {
  return ref.watch(inventoryRepositoryProvider).fetchById(productId);
});

/// Consommations en cabine du jour.
final todayConsumptionProvider = FutureProvider<List<StockMovement>>((
  ref,
) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  return ref
      .watch(inventoryRepositoryProvider)
      .fetchMovements(
        salonId: salonId,
        from: start,
        to: start.add(const Duration(days: 1)),
        reason: 'consumption',
      );
});

/// Consommations du mois, pour le coût et le classement des produits.
final monthConsumptionProvider = FutureProvider<List<StockMovement>>((
  ref,
) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  final now = DateTime.now();
  final start = DateTime(now.year, now.month);
  return ref
      .watch(inventoryRepositoryProvider)
      .fetchMovements(
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
      final movements =
          ref.watch(monthConsumptionProvider).valueOrNull ?? const [];

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
