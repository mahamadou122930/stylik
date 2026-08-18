import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/finance/domain/finance_summary.dart';
import 'package:stylik/features/finance/presentation/finance_providers.dart';
import 'package:stylik/features/finance/presentation/service_report_page.dart';

/// Rapport « Par service ». Il présente sa répartition comme celle du chiffre
/// d'affaires : les produits revendus doivent donc y figurer, sans pour autant
/// être comptés comme des passages en fauteuil.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeDateFormatting(Formatters.locale);
  });

  ServicePerformance line(
    String name, {
    required int revenue,
    int count = 1,
    String category = 'Coiffure',
    bool isProduct = false,
  }) => ServicePerformance(
    serviceId: name,
    name: name,
    category: category,
    count: count,
    revenueFcfa: revenue,
    isProduct: isProduct,
  );

  Widget host(List<ServicePerformance> items) => ProviderScope(
    overrides: [servicePerformanceProvider.overrideWith((ref) async => items)],
    child: const MaterialApp(
      locale: Locale('fr', 'FR'),
      home: ServiceReportPage(),
    ),
  );

  testWidgets('les produits vendus sont classés à part des prestations', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        line('Coupe Homme', revenue: 7500, count: 5),
        line(
          'Shampooing Kérastase',
          revenue: 12000,
          count: 3,
          category: 'Produits',
          isProduct: true,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    // Le produit ne doit pas chasser la coupe du palmarès des prestations :
    // il pèse plus lourd, mais les deux volumes ne se comparent pas.
    expect(find.text('Top prestations'), findsOneWidget);
    expect(find.text('Top produits vendus'), findsOneWidget);
    expect(find.text('Coupe Homme'), findsOneWidget);
    expect(find.text('Shampooing Kérastase'), findsOneWidget);
  });

  testWidgets('un produit se compte en unités, pas en prestations', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        line(
          'Huile capillaire',
          revenue: 9000,
          count: 3,
          category: 'Produits',
          isProduct: true,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    // « 3 prestations » sur un flacon vendu se lirait comme trois passages.
    expect(find.text('3 unités vendues'), findsOneWidget);
    expect(find.textContaining('prestations'), findsNothing);
  });

  testWidgets('le singulier est respecté', (tester) async {
    await tester.pumpWidget(
      host([
        line('Coupe Enfant', revenue: 1500),
        line(
          'Après-shampooing',
          revenue: 4000,
          category: 'Produits',
          isProduct: true,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 prestation'), findsOneWidget);
    expect(find.text('1 unité vendue'), findsOneWidget);
  });

  testWidgets('sans produit vendu, la section produits reste absente', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([line('Coupe Homme', revenue: 7500, count: 5)]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Top produits vendus'), findsNothing);
    expect(find.text('5 prestations'), findsOneWidget);
  });

  testWidgets('une catégorie vide reste nommée dans la légende', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        line('Coupe Homme', revenue: 16500, count: 11),
        line('Coupe Enfant', revenue: 500, category: ''),
      ]),
    );
    await tester.pumpAndSettle();

    // Sinon l'anneau montre une couleur en face d'une ligne muette, qu'on ne
    // peut rattacher à aucune activité.
    expect(find.text('Coiffure'), findsOneWidget);
    expect(find.text('Sans catégorie'), findsOneWidget);
  });

  group('libellés manquants', () {
    test('une catégorie vide retombe sur « Autre »', () {
      final row = ServicePerformance.fromMap(const {
        'service_id': 's1',
        'name': 'Coupe',
        'category': '   ',
        'count': 1,
        'revenue_fcfa': 500,
      });

      // `?? 'Autre'` seul laissait passer la chaîne vide.
      expect(row.category, 'Autre');
    });

    test('un nom vide dépend de la nature de la ligne', () {
      ServicePerformance withName(bool isProduct) =>
          ServicePerformance.fromMap({
            'service_id': 's1',
            'name': '',
            'category': 'Coiffure',
            'count': 1,
            'revenue_fcfa': 500,
            'is_product': isProduct,
          });

      expect(withName(false).name, 'Prestation');
      expect(withName(true).name, 'Produit');
    });

    test('un libellé renseigné est conservé tel quel', () {
      final row = ServicePerformance.fromMap(const {
        'service_id': 's1',
        'name': 'Coupe Homme',
        'category': 'Coiffure',
        'count': 1,
        'revenue_fcfa': 500,
      });

      expect(row.name, 'Coupe Homme');
      expect(row.category, 'Coiffure');
    });
  });

  testWidgets('sans aucune vente, un état vide explicite', (tester) async {
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();

    expect(find.text('Aucune donnée'), findsOneWidget);
  });
}
