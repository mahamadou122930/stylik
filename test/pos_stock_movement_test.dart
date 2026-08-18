import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/features/pos/domain/ticket.dart';

/// Une vente doit sortir du stock. Ce qu'on retire se déduit des lignes du
/// ticket : s'y tromper fait dériver l'inventaire sans que rien ne le signale.
void main() {
  TicketLine product(String id, {int quantity = 1}) => TicketLine(
    refId: id,
    label: 'Shampooing',
    unitPriceFcfa: 5000,
    quantity: quantity,
    isProduct: true,
  );

  TicketLine service(String id) =>
      TicketLine(refId: id, label: 'Coupe', unitPriceFcfa: 8000);

  group('quantités à sortir du stock', () {
    test('une prestation ne touche pas au stock', () {
      // `refId` désigne alors un service : le décrémenter viserait un produit
      // qui n'existe pas, ou pire, un homonyme.
      expect([service('s1'), service('s2')].productQuantities, isEmpty);
    });

    test('seuls les produits du ticket sont retenus', () {
      final lines = [service('s1'), product('p1'), service('s2')];
      expect(lines.productQuantities, {'p1': 1});
    });

    test('la quantité vendue est respectée', () {
      expect([product('p1', quantity: 3)].productQuantities, {'p1': 3});
    });

    test('un produit sur deux lignes est cumulé', () {
      // La caisse fusionne normalement les lignes, mais un ticket repris d'un
      // rendez-vous peut en porter deux : les écraser sortirait trop peu.
      final lines = [product('p1', quantity: 2), product('p1')];
      expect(lines.productQuantities, {'p1': 3});
    });

    test('une ligne sans identifiant est ignorée', () {
      // Sans `refId`, il n'y a aucun produit à décrémenter : mieux vaut ne
      // rien faire qu'écrire un mouvement orphelin.
      final lines = [product(''), product('p1')];
      expect(lines.productQuantities, {'p1': 1});
    });

    test('un ticket vide ne produit aucun mouvement', () {
      expect(const <TicketLine>[].productQuantities, isEmpty);
    });
  });
}
