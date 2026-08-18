import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/features/clients/domain/client.dart';

/// Ancienneté de la dernière visite. C'est le repère qui sert à relancer :
/// une cliente qu'on n'a pas vue depuis trois mois doit sauter aux yeux.
void main() {
  Client client({DateTime? lastVisit, int visits = 8}) => Client(
    id: 'c1',
    salonId: 'salon',
    fullName: 'Mahamadou Santara',
    phone: '70000000',
    visitCount: visits,
    lastVisitAt: lastVisit,
  );

  DateTime ago(Duration duration) => DateTime.now().subtract(duration);

  group('libellé de la dernière visite', () {
    test('une visite du jour se nomme, elle ne se chiffre pas', () {
      // « 0 j » se lisait comme un compteur en panne.
      expect(
        client(lastVisit: ago(const Duration(hours: 2))).lastVisitLabel,
        'Aujourd\'hui',
      );
    });

    test('la veille est comptée en jour calendaire', () {
      // Hier 20 h consulté ce matin fait treize heures : en tranches de 24 h,
      // la visite serait passée pour celle du jour.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final lastNight = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        20,
      );

      expect(client(lastVisit: lastNight).lastVisitLabel, 'Hier');
    });

    test('en deçà d\'un mois, le compte se fait en jours', () {
      expect(
        client(lastVisit: ago(const Duration(days: 12))).lastVisitLabel,
        'Il y a 12 j',
      );
    });

    test('au-delà, les jours ne disent plus rien', () {
      // « Il y a 96 j » demande un calcul mental pour être utile.
      expect(
        client(lastVisit: ago(const Duration(days: 96))).lastVisitLabel,
        'Il y a 3 mois',
      );
    });

    test('au-delà d\'un an, le détail est sans intérêt', () {
      expect(
        client(lastVisit: ago(const Duration(days: 500))).lastVisitLabel,
        'Il y a plus d\'un an',
      );
    });

    test('sans visite enregistrée, on le dit', () {
      expect(client(lastVisit: null).lastVisitLabel, 'Aucune visite');
      expect(client(lastVisit: null).daysSinceLastVisit, isNull);
    });

    test('une date future ne produit pas de délai négatif', () {
      // Horloge décalée ou saisie erronée : « il y a −2 j » n'a pas de sens.
      final future = DateTime.now().add(const Duration(days: 2));
      expect(client(lastVisit: future).daysSinceLastVisit, 0);
      expect(client(lastVisit: future).lastVisitLabel, 'Aujourd\'hui');
    });
  });

  group('ligne d\'activité', () {
    test('le nombre de visites suit le délai', () {
      final row = client(
        lastVisit: ago(const Duration(days: 12)),
      ).activityLabel;
      expect(row, 'Il y a 12 j · 8 visites');
    });

    test('une seule visite reste au singulier', () {
      final row = client(
        lastVisit: ago(const Duration(days: 3)),
        visits: 1,
      ).activityLabel;
      expect(row, 'Il y a 3 j · 1 visite');
    });
  });
}
