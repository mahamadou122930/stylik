import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/settings/data/settings_repository.dart';
import 'package:stylik/features/settings/domain/subscription_plan.dart';
import 'package:stylik/features/settings/domain/subscription_request.dart';
import 'package:stylik/features/settings/presentation/payment_instructions_page.dart';
import 'package:stylik/features/settings/presentation/plan_checkout_page.dart';
import 'package:stylik/features/settings/presentation/settings_providers.dart';

/// Souscription : l'application ne s'active plus elle-même.
///
/// « Payer & activer » passait le salon en formule payée sans que rien ne
/// soit payé. Le gérant dépose désormais une demande ; la base en calcule le
/// montant et la référence ; l'opérateur active depuis la console une fois
/// l'argent reçu.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeDateFormatting(Formatters.locale);
  });

  void usePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  const plan = SubscriptionPlan(
    id: 'p1',
    code: 'pro',
    name: 'Pro Coiffure',
    pricePerMonthFcfa: 20000,
    capabilities: [PlanCapability.agenda, PlanCapability.pos],
    sortOrder: 1,
  );

  SubscriptionRequest request({String? method = 'Orange Money'}) =>
      SubscriptionRequest(
        id: 'r1',
        salonId: 'salon',
        planCode: 'pro',
        planName: 'Pro Coiffure',
        billingCycle: BillingCycle.monthly,
        months: 1,
        amountFcfa: 20000,
        method: method,
        reference: 'STY-K7M2QX',
        status: 'pending',
        createdAt: DateTime.now(),
      );

  const orange = PaymentAccount(
    method: 'Orange Money',
    accountNumber: '70 00 00 01',
    holderName: 'Stylik SARL',
  );
  const wave = PaymentAccount(method: 'Wave', accountNumber: '70 00 00 02');

  group('dépôt de la demande', () {
    testWidgets('le bouton dépose une demande, puis montre où payer', (
      tester,
    ) async {
      usePhone(tester);
      final repository = _FakeSettingsRepository(returns: request());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(repository),
            subscriptionPlansProvider.overrideWith((ref) async => [plan]),
            subscriptionProvider.overrideWith((ref) async => null),
            paymentAccountsProvider.overrideWith((ref) async => [orange, wave]),
            // La page d'instructions relit la demande déposée.
            pendingSubscriptionRequestProvider.overrideWith(
              (ref) async => repository.lastRequest,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('fr', 'FR'),
            routes: {
              PaymentInstructionsPage.routeName: (_) =>
                  const PaymentInstructionsPage(),
            },
            home: const PlanCheckoutPage(plan: plan),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Les moyens proposés sont les comptes configurés, et eux seuls : plus
      // de « Carte » qu'aucun processus ne débite.
      expect(find.text('Orange Money'), findsOneWidget);
      expect(find.text('Wave'), findsOneWidget);
      expect(find.text('Carte'), findsNothing);
      // Aucune promesse de prélèvement automatique.
      expect(find.textContaining('automatiquement le'), findsNothing);

      await tester.tap(find.text('Wave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Demander l'activation"));
      await tester.pumpAndSettle();

      expect(repository.calls, 1);
      expect(repository.lastPlan?.code, 'pro');
      expect(repository.lastCycle, BillingCycle.monthly);
      expect(repository.lastMethod, 'Wave');

      // L'écran suivant donne la référence et le montant calculés par la base.
      expect(find.byType(PaymentInstructionsPage), findsOneWidget);
      expect(find.text('STY-K7M2QX'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sans compte configuré, aucun moyen fictif n’est proposé', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(
              _FakeSettingsRepository(returns: request(method: null)),
            ),
            subscriptionPlansProvider.overrideWith((ref) async => [plan]),
            subscriptionProvider.overrideWith((ref) async => null),
            paymentAccountsProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            locale: Locale('fr', 'FR'),
            home: PlanCheckoutPage(plan: plan),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('MOYEN DE PAIEMENT'), findsNothing);
      expect(find.text("Demander l'activation"), findsOneWidget);
    });
  });

  group('instructions de paiement', () {
    Future<void> pumpInstructions(
      WidgetTester tester, {
      required SubscriptionRequest? pending,
      required List<PaymentAccount> accounts,
    }) async {
      usePhone(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingSubscriptionRequestProvider.overrideWith(
              (ref) async => pending,
            ),
            paymentAccountsProvider.overrideWith((ref) async => accounts),
          ],
          child: const MaterialApp(
            locale: Locale('fr', 'FR'),
            home: PaymentInstructionsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('le compte du moyen choisi, la référence et le montant', (
      tester,
    ) async {
      await pumpInstructions(
        tester,
        pending: request(),
        accounts: [orange, wave],
      );

      expect(tester.takeException(), isNull);
      expect(find.text('STY-K7M2QX'), findsOneWidget);
      expect(find.text(Formatters.fcfa(20000)), findsOneWidget);
      // Seul le compte du moyen choisi : Orange Money, pas Wave.
      expect(find.text('Orange Money · 70 00 00 01'), findsOneWidget);
      expect(find.textContaining('Wave'), findsNothing);
      // Le nom du bénéficiaire : le gérant vérifie qu'il paie la bonne
      // personne avant de valider l'envoi.
      expect(find.text('Au nom de Stylik SARL'), findsOneWidget);
    });

    testWidgets('sans moyen choisi, tous les comptes sont montrés', (
      tester,
    ) async {
      await pumpInstructions(
        tester,
        pending: request(method: null),
        accounts: [orange, wave],
      );

      expect(find.text('Orange Money · 70 00 00 01'), findsOneWidget);
      expect(find.text('Wave · 70 00 00 02'), findsOneWidget);
    });

    testWidgets('sans compte configuré, le contact est annoncé', (
      tester,
    ) async {
      await pumpInstructions(tester, pending: request(), accounts: const []);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Notre équipe vous contacte'), findsOneWidget);
      // La référence reste donnée : elle rattachera le paiement au salon.
      expect(find.text('STY-K7M2QX'), findsOneWidget);
    });

    testWidgets('sans demande en attente, rien n’est inventé', (tester) async {
      await pumpInstructions(tester, pending: null, accounts: [orange]);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Aucune demande en attente'), findsOneWidget);
      expect(find.textContaining('STY-'), findsNothing);
    });
  });

  test('une demande se relit telle que la base la renvoie', () {
    final parsed = SubscriptionRequest.fromMap({
      'id': 'r1',
      'salon_id': 'salon',
      'plan_code': 'pro',
      'plan_name': 'Pro Coiffure',
      'billing_cycle': 'annual',
      'months': 12,
      'amount_fcfa': 192000,
      'method': null,
      'reference': 'STY-K7M2QX',
      'status': 'pending',
      'created_at': '2026-09-24T09:00:00+00:00',
    });

    expect(parsed.billingCycle, BillingCycle.annual);
    expect(parsed.months, 12);
    expect(parsed.amountFcfa, 192000);
    expect(parsed.method, isNull);
    expect(parsed.isPending, isTrue);
  });
}

/// Faux dépôt : enregistre la demande au lieu de l'envoyer.
class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({required this.returns});

  final SubscriptionRequest returns;

  int calls = 0;
  SubscriptionPlan? lastPlan;
  BillingCycle? lastCycle;
  String? lastMethod;
  SubscriptionRequest? lastRequest;

  @override
  Future<SubscriptionRequest> requestActivation({
    required SubscriptionPlan plan,
    required BillingCycle cycle,
    String? method,
  }) async {
    calls++;
    lastPlan = plan;
    lastCycle = cycle;
    lastMethod = method;
    return lastRequest = returns;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
