import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/settings/domain/subscription_plan.dart';
import 'package:stylik/features/settings/presentation/plan_selection_page.dart';
import 'package:stylik/features/settings/presentation/settings_providers.dart';

/// Tarifs des formules.
///
/// Le montant annoncé à l'écran doit être celui que la base réclame dans la
/// demande d'activation (`request_subscription_activation`). Deux écarts
/// existaient : la remise était fixée à 20 % dans l'application quand la
/// console la règle par formule, et l'arrondi se faisait par mois au lieu de
/// se faire sur l'année.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeDateFormatting(Formatters.locale);
  });

  SubscriptionPlan plan(
    int price, {
    double discount = 0.20,
    String code = 'p',
  }) => SubscriptionPlan(
    id: code,
    code: code,
    name: code,
    pricePerMonthFcfa: price,
    yearlyDiscount: discount,
  );

  group('montant annuel, comme la base le calcule', () {
    // Valeurs obtenues de PostgreSQL 17 avec l'expression exacte de
    // `request_subscription_activation` :
    //   round(prix * 12 * (1 - remise::numeric))
    const reference = [
      (18000, 0.20, 172800),
      (20000, 0.20, 192000),
      (10001, 0.20, 96010),
      (12345, 0.15, 125919),
      (9999, 0.175, 98990),
      (10000, 0.0, 120000),
      (7, 0.5, 42),
    ];

    for (final (price, discount, expected) in reference) {
      test('$price F à −${(discount * 100).toStringAsFixed(1)} %', () {
        expect(
          plan(price, discount: discount).chargeFor(BillingCycle.annual),
          expected,
        );
      });
    }

    test("l'ancien arrondi par mois perdait 10 F sur 10 001 F", () {
      // 10 001 × 0,8 = 8 000,8 arrondi à 8 000, puis × 12 = 96 000.
      // La base, elle, arrondit l'année entière : 96 010.
      expect(plan(10001).chargeFor(BillingCycle.annual), isNot(96000));
    });
  });

  group('lecture du catalogue', () {
    Map<String, dynamic> row(Object? discount) => {
      'id': 'p',
      'code': 'pro',
      'name': 'Pro Coiffure',
      'price_per_month_fcfa': 20000,
      'yearly_discount': discount,
    };

    test('la remise poussée par la console est reprise', () {
      expect(SubscriptionPlan.fromMap(row(0.15)).yearlyDiscount, 0.15);
    });

    test("un `numeric` arrivé en texte est lu aussi", () {
      // Selon le client, PostgREST rend `numeric` en nombre ou en chaîne.
      expect(SubscriptionPlan.fromMap(row('0.15')).yearlyDiscount, 0.15);
    });

    test('une remise absente retombe sur la valeur par défaut de la base', () {
      expect(SubscriptionPlan.fromMap(row(null)).yearlyDiscount, 0.20);
    });
  });

  test('le mensuel reste le prix du catalogue', () {
    final pro = plan(18000);
    expect(pro.chargeFor(BillingCycle.monthly), 18000);
    expect(pro.monthlyEquivalent(BillingCycle.monthly), 18000);
    expect(pro.discountPercentFor(BillingCycle.monthly), 0);
    expect(pro.monthlyEquivalent(BillingCycle.annual), 14400);
    expect(pro.fullYearPrice, 216000);
  });

  group('bascule annuelle', () {
    Future<void> pumpWith(
      WidgetTester tester,
      List<SubscriptionPlan> plans,
    ) async {
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionPlansProvider.overrideWith((ref) async => plans),
            subscriptionProvider.overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            locale: Locale('fr', 'FR'),
            home: PlanSelectionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('une remise commune est annoncée telle quelle', (tester) async {
      await pumpWith(tester, [
        plan(10000, code: 'starter'),
        plan(20000, code: 'pro'),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('Annuel −20 %'), findsOneWidget);
    });

    testWidgets('des remises différentes ne promettent que le maximum', (
      tester,
    ) async {
      // « −20 % » en tête d'écran quand Starter n'offre que 10 % serait une
      // promesse que la moitié du catalogue ne tient pas.
      await pumpWith(tester, [
        plan(10000, code: 'starter', discount: 0.10),
        plan(20000, code: 'pro'),
      ]);
      expect(find.text("Annuel jusqu'à −20 %"), findsOneWidget);
    });

    testWidgets('sans remise, rien n’est promis', (tester) async {
      await pumpWith(tester, [plan(10000, code: 'starter', discount: 0)]);
      expect(find.text('Annuel'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });
  });
}
