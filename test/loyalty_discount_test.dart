import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/features/catalog/domain/salon_service.dart';
import 'package:stylik/features/loyalty/domain/loyalty_campaign.dart';
import 'package:stylik/features/pos/domain/ticket.dart';
import 'package:stylik/features/pos/presentation/pos_providers.dart';

/// Remise fidélité en caisse. Elle se calcule sur le sous-total et doit suivre
/// le ticket : une remise figée au moment où la cliente est rattachée
/// laisserait les lignes ajoutées ensuite au prix plein.
void main() {
  Ticket ticketOf(int subtotal, {int percent = 0}) => Ticket(
    discountPercent: percent,
    lines: [
      TicketLine(refId: 's1', label: 'Balayage', unitPriceFcfa: subtotal),
    ],
  );

  group('barème des paliers', () {
    test('le palier d\'entrée ne donne droit à rien', () {
      // Tout le monde est Bronze dès la première visite : une remise y serait
      // une baisse de tarif générale, pas de la fidélité.
      expect(LoyaltyTier.bronze.discountPercent, 0);
    });

    test('la remise augmente avec le palier', () {
      expect(LoyaltyTier.silver.discountPercent, 5);
      expect(LoyaltyTier.gold.discountPercent, 10);
      expect(LoyaltyTier.platinum.discountPercent, 15);
    });

    test('le palier se déduit des points', () {
      expect(LoyaltyTier.forPoints(0).discountPercent, 0);
      expect(LoyaltyTier.forPoints(199).discountPercent, 0);
      expect(LoyaltyTier.forPoints(200).discountPercent, 5);
      expect(LoyaltyTier.forPoints(900).discountPercent, 15);
    });
  });

  group('calcul de la remise', () {
    test('sans palier, aucune remise', () {
      final ticket = ticketOf(62500);
      expect(ticket.discountFcfa, 0);
      expect(ticket.discountLabel, isNull);
      expect(ticket.totalFcfa, 62500);
    });

    test('la remise est arrondie à la centaine inférieure', () {
      // 5 % de 62 500 F font 3 125 F. On ne rend pas la monnaie au franc près
      // en salon, et l'arrondi vers le bas garantit de ne pas dépasser le taux.
      final ticket = ticketOf(62500, percent: 5);
      expect(ticket.discountFcfa, 3100);
      expect(ticket.totalFcfa, 59400);
    });

    test('le libellé porte le taux appliqué', () {
      expect(
        ticketOf(62500, percent: 10).discountLabel,
        'Remise fidélité (10 %)',
      );
    });

    test('la remise suit les lignes ajoutées', () {
      final notifier = TicketNotifier();
      notifier.addService(_service('s1', 40000));
      notifier.setDiscountPercent(10);
      expect(notifier.state.discountFcfa, 4000);

      // Le vrai piège : stockée en francs, la remise serait restée à 4 000 F.
      notifier.addService(_service('s2', 20000));
      expect(notifier.state.subtotalFcfa, 60000);
      expect(notifier.state.discountFcfa, 6000);
      expect(notifier.state.totalFcfa, 54000);
    });

    test('retirer la remise remet le prix plein', () {
      final notifier = TicketNotifier();
      notifier.addService(_service('s1', 40000));
      notifier.setDiscountPercent(10);
      notifier.setDiscountPercent(0);

      expect(notifier.state.discountFcfa, 0);
      expect(notifier.state.totalFcfa, 40000);
    });

    test('un ticket vide ne produit pas de remise négative', () {
      const ticket = Ticket(discountPercent: 15);
      expect(ticket.discountFcfa, 0);
      expect(ticket.totalFcfa, 0);
    });
  });

  group('rattachement de la cliente', () {
    test('changer de fiche remplace le taux, sans le cumuler', () {
      final notifier = TicketNotifier();
      notifier.addService(_service('s1', 100000));
      notifier.attachClient(clientId: 'or', discountPercent: 10);
      expect(notifier.state.discountFcfa, 10000);

      // Une cliente sans palier ne doit pas hériter de la remise de la
      // précédente restée en caisse.
      notifier.attachClient(clientId: 'passage');
      expect(notifier.state.discountFcfa, 0);
    });
  });
}

SalonService _service(String id, int price) => SalonService(
  id: id,
  salonId: 'salon',
  name: 'Prestation $id',
  category: 'Coiffure',
  durationMinutes: 30,
  priceFcfa: price,
);
