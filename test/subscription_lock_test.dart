import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/settings/domain/subscription.dart';
import 'package:stylik/features/settings/presentation/settings_providers.dart';
import 'package:stylik/features/settings/presentation/subscription_lock.dart';

/// Lecture seule à l'échéance de l'abonnement.
///
/// La règle fait foi en base (`salon_subscription_is_active`, trigger
/// `trg_subscription_required`) : ce verrou-ci ne fait que l'annoncer avant
/// d'essayer, pour éviter qu'un gérant remplisse un ticket entier avant de se
/// voir refuser à l'encaissement.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeDateFormatting(Formatters.locale);
  });

  Subscription sub({required String status, Duration? chargeIn}) =>
      Subscription(
        id: 'sub',
        salonId: 'salon',
        planCode: 'pro',
        planName: 'Pro Salon',
        pricePerMonthFcfa: 18000,
        status: status,
        nextChargeAt: chargeIn == null ? null : DateTime.now().add(chargeIn),
      );

  ProviderContainer withSubscription(Subscription? value) {
    final container = ProviderContainer(
      overrides: [subscriptionProvider.overrideWith((ref) async => value)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<bool> lockedFor(Subscription? value) async {
    final container = withSubscription(value);
    await container.read(subscriptionProvider.future);
    return container.read(subscriptionLockedProvider);
  }

  group('quand le salon est verrouillé', () {
    test('un essai échu verrouille', () async {
      expect(
        await lockedFor(
          sub(status: 'trialing', chargeIn: const Duration(days: -1)),
        ),
        isTrue,
      );
    });

    test('un essai en cours ne verrouille pas', () async {
      expect(
        await lockedFor(
          sub(status: 'trialing', chargeIn: const Duration(days: 3)),
        ),
        isFalse,
      );
    });

    test('une période payée échue verrouille, comme un essai', () async {
      // La console prolonge la période à chaque règlement reçu : il existe
      // désormais de quoi repousser l'échéance, elle s'applique donc. C'est
      // la même règle qu'en base (`salon_subscription_is_active`).
      expect(
        await lockedFor(
          sub(status: 'active', chargeIn: const Duration(days: -1)),
        ),
        isTrue,
      );
      expect(
        await lockedFor(
          sub(status: 'active', chargeIn: const Duration(days: 20)),
        ),
        isFalse,
      );
    });

    test('une suspension verrouille, même période en cours', () async {
      final suspended = Subscription(
        id: 'sub',
        salonId: 'salon',
        planCode: 'pro',
        planName: 'Pro Coiffure',
        pricePerMonthFcfa: 20000,
        status: 'active',
        nextChargeAt: DateTime.now().add(const Duration(days: 20)),
        suspended: true,
      );
      expect(await lockedFor(suspended), isTrue);
      expect(suspended.statusLabel, 'Suspendu');
    });

    test('une échéance absente laisse ouvert', () async {
      // Une donnée manquante ne ferme pas une caisse — même règle qu'en base.
      expect(await lockedFor(sub(status: 'active')), isFalse);
    });

    test('un abonnement non lu ne verrouille rien', () async {
      // Hors ligne, ou lecture en cours : fermer la caisse sur une donnée
      // absente coûterait plus cher que de laisser passer une journée.
      expect(await lockedFor(null), isFalse);

      final container = withSubscription(
        sub(status: 'trialing', chargeIn: const Duration(days: -1)),
      );
      // Avant que la lecture n'aboutisse, rien n'est verrouillé.
      expect(container.read(subscriptionLockedProvider), isFalse);
    });
  });

  group("ce que voit l'équipe", () {
    Widget host(Subscription? value) => ProviderScope(
      overrides: [subscriptionProvider.overrideWith((ref) async => value)],
      child: const MaterialApp(
        locale: Locale('fr', 'FR'),
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: SubscriptionLockBanner(),
          ),
        ),
      ),
    );

    testWidgets('le bandeau paraît quand le salon est verrouillé', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(sub(status: 'trialing', chargeIn: const Duration(days: -1))),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Salon en lecture seule'), findsOneWidget);
      // Ce que le salon garde doit être dit : le blocage porte sur la saisie,
      // pas sur l'accès aux données déjà là.
      expect(find.textContaining('consultable'), findsOneWidget);
    });

    testWidgets('aucun bandeau tant que tout est en règle', (tester) async {
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(sub(status: 'trialing', chargeIn: const Duration(days: 9))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Salon en lecture seule'), findsNothing);
    });
  });

  group('garde des écritures', () {
    /// Un écran minimal qui tente une écriture, comme le fait un formulaire.
    ///
    /// Rend un lecteur plutôt qu'une valeur : quand le salon est éteint, le
    /// garde n'a pas encore rendu la main — il attend que la feuille soit
    /// refermée, et c'est justement ce qu'il faut pouvoir observer.
    Future<bool? Function()> runGuard(
      WidgetTester tester,
      Subscription? value,
    ) async {
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      bool? allowed;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [subscriptionProvider.overrideWith((ref) async => value)],
          child: MaterialApp(
            locale: const Locale('fr', 'FR'),
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      allowed = await ensureSubscriptionActive(context, ref);
                    },
                    child: const Text('ENREGISTRER'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ENREGISTRER'));
      await tester.pumpAndSettle();
      return () => allowed;
    }

    testWidgets("l'action passe quand l'abonnement est à jour", (tester) async {
      final allowed = await runGuard(
        tester,
        sub(status: 'active', chargeIn: const Duration(days: 20)),
      );

      // Rien ne s'interpose : le garde rend la main tout de suite.
      expect(allowed(), isTrue);
      expect(find.text('Choisir un plan'), findsNothing);
    });

    testWidgets("l'action s'arrête et s'explique quand le salon est éteint", (
      tester,
    ) async {
      final allowed = await runGuard(
        tester,
        sub(status: 'trialing', chargeIn: const Duration(days: -2)),
      );

      expect(tester.takeException(), isNull);
      // L'explication arrive avant l'action, pas après un refus de la base.
      expect(find.text('Salon en lecture seule'), findsOneWidget);
      expect(find.text('Choisir un plan'), findsOneWidget);
      // Tant que la feuille est ouverte, l'appelant attend.
      expect(allowed(), isNull);

      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      // Et il repart avec un refus : l'écriture ne part jamais.
      expect(allowed(), isFalse);
    });
    testWidgets("un salon activé entre-temps n'est pas bloqué sur le cache", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      // Première lecture : essai échu, mise en cache au démarrage. Entre-temps
      // le gérant a payé et l'opérateur a activé le salon depuis la console :
      // toute lecture suivante voit la période payée.
      var reads = 0;
      final expired = sub(
        status: 'trialing',
        chargeIn: const Duration(days: -2),
      );
      final paid = sub(status: 'active', chargeIn: const Duration(days: 30));

      bool? allowed;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionProvider.overrideWith(
              (ref) async => reads++ == 0 ? expired : paid,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('fr', 'FR'),
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      allowed = await ensureSubscriptionActive(context, ref);
                    },
                    child: const Text('ENREGISTRER'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ENREGISTRER'));
      await tester.pumpAndSettle();

      // Sans la relecture avant refus, ce gérant restait bloqué jusqu'au
      // redémarrage de l'application — après avoir payé.
      expect(allowed, isTrue);
      expect(find.text('Salon en lecture seule'), findsNothing);
      expect(reads, 2);
    });

    testWidgets('une suspension le dit, au lieu de parler d’échéance', (
      tester,
    ) async {
      final allowed = await runGuard(
        tester,
        Subscription(
          id: 'sub',
          salonId: 'salon',
          planCode: 'pro',
          planName: 'Pro Coiffure',
          pricePerMonthFcfa: 20000,
          status: 'active',
          nextChargeAt: DateTime.now().add(const Duration(days: 20)),
          suspended: true,
        ),
      );

      expect(find.textContaining('suspendu'), findsOneWidget);
      expect(find.textContaining('échéance'), findsNothing);

      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      expect(allowed(), isFalse);
    });
  });
}
