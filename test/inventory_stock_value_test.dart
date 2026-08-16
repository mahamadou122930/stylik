import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/features/inventory/domain/product.dart';
import 'package:stylik/features/inventory/presentation/inventory_providers.dart';

/// Valeur du stock et consommables. Le total sert à décider des achats : un
/// produit qui n'y pèse rien parce que son coût est resté à zéro fait
/// silencieusement mentir le chiffre.
void main() {
  Product product({
    required String id,
    required int quantity,
    required int cost,
    int salePrice = 0,
    ProductUsage usage = ProductUsage.resale,
  }) =>
      Product(
        id: id,
        salonId: 'salon',
        name: 'Produit $id',
        brand: 'Marque',
        category: 'Revente',
        stockQuantity: quantity,
        alertThreshold: 2,
        unitSalePriceFcfa: salePrice,
        unitCostFcfa: cost,
        usage: usage,
      );

  ProviderContainer containerWith(List<Product> products) {
    final container = ProviderContainer(
      overrides: [productsProvider.overrideWith((ref) async => products)],
    );
    addTearDown(container.dispose);
    container.read(productsProvider);
    return container;
  }

  test('revente et consommables comptent tous deux dans la valeur', () async {
    final container = containerWith([
      product(id: 'revente', quantity: 4, cost: 2500, salePrice: 6000),
      product(
        id: 'conso',
        quantity: 3,
        cost: 1000,
        usage: ProductUsage.consumable,
      ),
    ]);
    await container.read(productsProvider.future);

    // 4 × 2500 + 3 × 1000. Ce que le salon détient vaut ce qu'il l'a payé,
    // quel que soit l'usage prévu.
    expect(container.read(stockValueProvider), 13000);
  });

  test('un produit sans coût d\'achat ne pèse rien et est signalé', () async {
    final container = containerWith([
      product(id: 'sans-cout', quantity: 10, cost: 0, salePrice: 6000),
      product(id: 'avec-cout', quantity: 2, cost: 3000),
    ]);
    await container.read(productsProvider.future);

    // C'est le symptôme rapporté : la fiche de revente était bien comptée,
    // mais son coût valait zéro faute d'avoir été saisi.
    expect(container.read(stockValueProvider), 6000);
    expect(
      container.read(productsWithoutCostProvider).map((p) => p.id),
      ['sans-cout'],
    );
  });

  test('un produit épuisé sans coût n\'est pas signalé', () async {
    final container = containerWith([
      product(id: 'epuise', quantity: 0, cost: 0),
    ]);
    await container.read(productsProvider.future);

    // Rien en rayon : son coût manquant ne fausse aucun total.
    expect(container.read(productsWithoutCostProvider), isEmpty);
    expect(container.read(stockValueProvider), 0);
  });

  test('la valeur suit la quantité, ouverture d\'unité comprise', () {
    final avant = product(id: 'conso', quantity: 5, cost: 1200,
        usage: ProductUsage.consumable);

    // Méthode A : une unité entière quitte le stock à l'ouverture.
    final apres = avant.copyWith(stockQuantity: avant.stockQuantity - 1);

    expect(avant.stockValueFcfa, 6000);
    expect(apres.stockValueFcfa, 4800);
  });

  group('filtre par usage', () {
    ProviderContainer filtered(ProductUsage? usage, {String search = ''}) {
      final container = ProviderContainer(
        overrides: [
          productsProvider.overrideWith(
            (ref) async => [
              product(id: 'revente', quantity: 4, cost: 2500, salePrice: 6000),
              product(
                id: 'conso',
                quantity: 3,
                cost: 1000,
                usage: ProductUsage.consumable,
              ),
            ],
          ),
          productUsageFilterProvider.overrideWith((ref) => usage),
          productSearchProvider.overrideWith((ref) => search),
        ],
      );
      addTearDown(container.dispose);
      container.read(productsProvider);
      return container;
    }

    test('sans filtre, tout le stock est visible', () async {
      final container = filtered(null);
      await container.read(productsProvider.future);

      expect(container.read(filteredProductsProvider).length, 2);
    });

    test('le filtre consommables ecarte la revente', () async {
      final container = filtered(ProductUsage.consumable);
      await container.read(productsProvider.future);

      expect(
        container.read(filteredProductsProvider).map((p) => p.id),
        ['conso'],
      );
    });

    test('recherche et usage se combinent', () async {
      // « conso » ne matche que le nom du consommable, que le filtre revente
      // écarte : le croisement doit rendre une liste vide, et non retomber
      // sur l'un des deux critères.
      final container = filtered(ProductUsage.resale, search: 'conso');
      await container.read(productsProvider.future);

      expect(container.read(filteredProductsProvider), isEmpty);

      // Le même terme sans filtre retrouve bien le produit.
      final large = filtered(null, search: 'conso');
      await large.read(productsProvider.future);
      expect(large.read(filteredProductsProvider).map((p) => p.id), ['conso']);
    });
  });

  group('recherche', () {
    ProviderContainer searching(String query) {
      final container = ProviderContainer(
        overrides: [
          productsProvider.overrideWith(
            (ref) async => [
              Product(
                id: 'kera',
                salonId: 'salon',
                name: 'Shampooing Kerastase'.replaceAll('Kerastase', 'Kérastase'),
                brand: 'Kérastase',
                category: 'Coloration',
                stockQuantity: 4,
                alertThreshold: 2,
                unitSalePriceFcfa: 6000,
                unitCostFcfa: 2500,
              ),
            ],
          ),
          productSearchProvider.overrideWith((ref) => query),
        ],
      );
      addTearDown(container.dispose);
      container.read(productsProvider);
      return container;
    }

    test('trouve un nom accentue sans taper les accents', () async {
      final c = searching('kerastase');
      await c.read(productsProvider.future);

      // Sur un clavier de telephone, personne ne met les accents.
      expect(c.read(filteredProductsProvider).map((p) => p.id), ['kera']);
    });

    test('ignore la casse', () async {
      final c = searching('SHAMPOOING');
      await c.read(productsProvider.future);

      expect(c.read(filteredProductsProvider).map((p) => p.id), ['kera']);
    });

    test('trouve aussi en tapant les accents', () async {
      final c = searching('Kérastase');
      await c.read(productsProvider.future);

      expect(c.read(filteredProductsProvider).map((p) => p.id), ['kera']);
    });

    test('un terme absent ne renvoie rien', () async {
      final c = searching('masque');
      await c.read(productsProvider.future);

      expect(c.read(filteredProductsProvider), isEmpty);
    });
  });
}
