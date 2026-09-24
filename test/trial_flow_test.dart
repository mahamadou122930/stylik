import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/app.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/auth/domain/registration_draft.dart';
import 'package:stylik/features/auth/presentation/register_page.dart';
import 'package:stylik/features/auth/presentation/role_selection_page.dart';
import 'package:stylik/features/settings/domain/subscription.dart';
import 'package:stylik/features/settings/presentation/settings_providers.dart';
import 'package:stylik/features/settings/presentation/trial_expired_page.dart';
import 'package:stylik/features/settings/presentation/trial_welcome_page.dart';

/// Parcours de l'essai gratuit : l'entrée dans l'app après l'inscription, et
/// l'écran de fin d'essai.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeDateFormatting(Formatters.locale);
  });

  /// Un écran de téléphone.
  void usePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  const draft = RegistrationDraft(
    salonName: 'Salon Awa',
    salonPhone: '',
    salonAddress: '',
    fullName: 'Awa Traoré',
    email: 'awa@example.com',
    password: 'motdepasse',
  );

  group("entrée dans l'app après l'inscription", () {
    /// Reconstruit la vraie pile : accueil → inscription → choix du rôle.
    ///
    /// Le nombre de routes est ce qui compte : c'est lui qui décidait où
    /// retombait le bouton de l'écran d'essai.
    Future<NavigatorState> pumpSignupStack(WidgetTester tester) async {
      usePhone(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [subscriptionProvider.overrideWith((ref) async => null)],
          child: MaterialApp(
            locale: const Locale('fr', 'FR'),
            onGenerateRoute: StylikApp.buildRoute,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(RegisterPage.routeName),
                    child: const Text('ACCUEIL'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACCUEIL'));
      await tester.pumpAndSettle();

      final navigator = Navigator.of(tester.element(find.byType(RegisterPage)));
      navigator.pushNamed(RoleSelectionPage.routeName, arguments: draft);
      await tester.pumpAndSettle();

      return navigator;
    }

    testWidgets("« Commencer l'essai » mène à l'accueil, pas au formulaire", (
      tester,
    ) async {
      final navigator = await pumpSignupStack(tester);

      // Ce que fait `_submit()` une fois le compte créé.
      navigator.pushNamedAndRemoveUntil(
        TrialWelcomePage.routeName,
        (route) => route.isFirst,
      );
      await tester.pumpAndSettle();
      expect(find.byType(TrialWelcomePage), findsOneWidget);

      await tester.tap(find.text("Commencer l'essai gratuit"));
      await tester.pumpAndSettle();

      // Un `pushReplacementNamed` ne retirait que la route du rôle : le bouton
      // reposait alors le formulaire de création de salon sous les yeux d'un
      // gérant dont le compte venait d'être créé.
      expect(find.byType(RegisterPage), findsNothing);
      expect(find.text('ACCUEIL'), findsOneWidget);
    });

    testWidgets("la pile d'inscription ne survit pas à l'écran d'essai", (
      tester,
    ) async {
      final navigator = await pumpSignupStack(tester);

      navigator.pushNamedAndRemoveUntil(
        TrialWelcomePage.routeName,
        (route) => route.isFirst,
      );
      await tester.pumpAndSettle();

      // Un seul cran sépare l'essai de l'accueil : le retour matériel
      // d'Android ne peut pas rouvrir l'inscription non plus.
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('ACCUEIL'), findsOneWidget);
    });
  });

  group("récapitulatif de l'essai", () {
    Widget host({TrialRecap? recap}) => ProviderScope(
      overrides: [
        trialRecapProvider.overrideWith((ref) async => recap),
        subscriptionProvider.overrideWith((ref) async => null),
      ],
      child: const MaterialApp(
        locale: Locale('fr', 'FR'),
        home: TrialExpiredPage(),
      ),
    );

    testWidgets("les chiffres couvrent bien la fenêtre de l'essai", (
      tester,
    ) async {
      usePhone(tester);
      final to = DateTime.now();

      await tester.pumpWidget(
        host(
          recap: (
            from: to.subtract(
              const Duration(days: Subscription.trialDurationDays),
            ),
            to: to,
            ticketCount: 118,
            clientCount: 27,
            revenueFcfa: 2920000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text("PENDANT L'ESSAI"), findsOneWidget);
      expect(find.text('118'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);
      expect(find.text(Formatters.fcfaShort(2920000)), findsWidgets);
    });

    testWidgets('sans récapitulatif lu, aucun zéro inventé', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // L'écran affichait « 0 RDV · 0 F » en attendant ses données — et
      // l'argument de rétention devenait son propre contre-exemple.
      expect(find.text("PENDANT L'ESSAI"), findsNothing);
      expect(find.text('Votre essai est terminé'), findsOneWidget);
      expect(find.text('Choisir un plan'), findsOneWidget);
    });
  });
}
