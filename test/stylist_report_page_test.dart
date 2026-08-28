import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/auth/domain/profile.dart';
import 'package:stylik/features/auth/domain/user_role.dart';
import 'package:stylik/features/auth/presentation/auth_providers.dart';
import 'package:stylik/features/finance/domain/finance_summary.dart';
import 'package:stylik/features/finance/domain/payout.dart';
import 'package:stylik/features/finance/presentation/finance_providers.dart';
import 'package:stylik/features/finance/presentation/stylist_report_page.dart';
import 'package:stylik/features/staff/presentation/staff_providers.dart';

/// Rapport « Par coiffeur ». Il croise deux sources — les ventes et l'équipe —
/// et doit rester lisible même quand l'une des deux est vide.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeDateFormatting(Formatters.locale);
  });

  Profile member(String id, String name) => Profile(
    id: id,
    salonId: 'salon',
    fullName: name,
    role: UserRole.coiffeur,
    commissionRate: 30,
  );

  PayoutRequest settled(String profileId, int amount, DateTime paidAt) =>
      PayoutRequest(
        id: 'p-$profileId',
        salonId: 'salon',
        profileId: profileId,
        amountFcfa: amount,
        status: PayoutStatus.paid,
        requestedAt: paidAt,
        paidAt: paidAt,
      );

  Widget host({
    required List<Profile> team,
    required List<StylistCommission> commissions,
    List<PayoutRequest> payouts = const [],
  }) => ProviderScope(
    overrides: [
      allPayoutsProvider.overrideWith((ref) async => payouts),
      // Sans profil, le salon est inconnu et l'écran attend : c'est
      // volontaire, il ne doit pas conclure à une équipe vide.
      currentProfileProvider.overrideWith(
        (ref) async => member('moi', 'Gérant'),
      ),
      stylistsProvider.overrideWith((ref) async => team),
      commissionsProvider.overrideWith((ref) async => commissions),
    ],
    child: const MaterialApp(
      locale: Locale('fr', 'FR'),
      home: StylistReportPage(),
    ),
  );

  testWidgets('les coiffeurs et leurs commissions s\'affichent', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        team: [member('a', 'Mahamadou Santara'), member('b', 'Bakary Keïta')],
        commissions: [
          const StylistCommission(
            stylistId: 'a',
            stylistName: 'Mahamadou Santara',
            revenueFcfa: 3000,
            commissionFcfa: 900,
            serviceCount: 2,
            commissionRate: 30,
            clientCount: 2,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Mahamadou Santara'), findsOneWidget);
    expect(find.text(Formatters.fcfa(900)), findsOneWidget);

    // Celui qui n'a rien encaissé reste visible, à zéro.
    expect(find.text('Bakary Keïta'), findsOneWidget);
  });

  testWidgets('sans vente, l\'équipe reste listée à zéro', (tester) async {
    await tester.pumpWidget(
      host(team: [member('a', 'Awa Traoré')], commissions: const []),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Awa Traoré'), findsOneWidget);
    expect(find.text('Aucun coiffeur'), findsNothing);
  });

  testWidgets('sans équipe ni vente, un état vide explicite', (tester) async {
    await tester.pumpWidget(host(team: const [], commissions: const []));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Aucun coiffeur'), findsOneWidget);
  });

  testWidgets("sans salon chargé, l'écran attend au lieu de conclure", (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('fr', 'FR'),
          home: StylistReportPage(),
        ),
      ),
    );
    await tester.pump();

    // Hors ligne ou session non restaurée : « Aucun coiffeur » ferait croire
    // à une équipe vide alors que rien n'a pu être lu.
    expect(find.text('Aucun coiffeur'), findsNothing);
  });

  group('colonne « Versé »', () {
    /// Un écran de téléphone : trois colonnes de montants y sont à l'étroit.
    void usePhone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    StylistCommission earning(String id, String name) => StylistCommission(
      stylistId: id,
      stylistName: name,
      revenueFcfa: 2920000,
      commissionFcfa: 1022000,
      serviceCount: 118,
      clientCount: 118,
      commissionRate: 35,
    );

    testWidgets("le versé de la période s'affiche", (tester) async {
      usePhone(tester);
      final now = DateTime.now();

      await tester.pumpWidget(
        host(
          team: [member('a', 'Awa Traoré')],
          commissions: [earning('a', 'Awa Traoré')],
          payouts: [settled('a', 700000, DateTime(now.year, now.month, 5))],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Versé'), findsOneWidget);
      expect(find.text(Formatters.fcfa(700000)), findsOneWidget);
      // Les gros montants se réduisent au lieu de déborder de leur colonne.
      expect(find.text(Formatters.fcfa(2920000)), findsOneWidget);
    });

    testWidgets('sans versement, la colonne affiche zéro', (tester) async {
      usePhone(tester);

      await tester.pumpWidget(
        host(
          team: [member('a', 'Awa Traoré')],
          commissions: [earning('a', 'Awa Traoré')],
        ),
      );
      await tester.pumpAndSettle();

      // Une case vide se lirait comme une donnée manquante ; « 0 F » dit que
      // rien n'a encore été réglé.
      expect(find.text(Formatters.fcfa(0)), findsOneWidget);
    });

    testWidgets("un versement hors période n'est pas compté", (tester) async {
      usePhone(tester);

      await tester.pumpWidget(
        host(
          team: [member('a', 'Awa Traoré')],
          commissions: [earning('a', 'Awa Traoré')],
          // Réglé l'an dernier : le compter à côté d'une commission du mois
          // ferait croire à un solde alors qu'on compare deux périodes.
          payouts: [settled('a', 700000, DateTime(2020, 3, 4))],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(Formatters.fcfa(0)), findsOneWidget);
      expect(find.text(Formatters.fcfa(700000)), findsNothing);
    });

    testWidgets('une demande en attente ne compte pas comme versée', (
      tester,
    ) async {
      usePhone(tester);
      final now = DateTime.now();

      await tester.pumpWidget(
        host(
          team: [member('a', 'Awa Traoré')],
          commissions: [earning('a', 'Awa Traoré')],
          payouts: [
            PayoutRequest(
              id: 'x',
              salonId: 'salon',
              profileId: 'a',
              amountFcfa: 500000,
              status: PayoutStatus.pending,
              requestedAt: now,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tant que le gérant n'a pas réglé, l'argent est encore en caisse.
      expect(find.text(Formatters.fcfa(0)), findsOneWidget);
    });
  });

  group('échelle de temps', () {
    void usePhone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    testWidgets("les échelles sont proposées sur l'écran", (tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        host(team: [member('a', 'Awa Traoré')], commissions: const []),
      );
      await tester.pumpAndSettle();

      // Sans ce sélecteur, la période ne se changeait que depuis Finance.
      for (final period in FinancePeriod.values) {
        expect(find.text(period.label), findsOneWidget, reason: period.label);
      }
    });

    testWidgets('choisir « Jour » resserre la fenêtre sur la journée', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(
        host(team: [member('a', 'Awa Traoré')], commissions: const []),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(FinancePeriod.day.label));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(StylistReportPage)),
      );
      final range = container.read(financeRangeProvider);

      expect(container.read(financePeriodProvider), FinancePeriod.day);
      // Les commissions et le versé suivent `financeRangeProvider` : une
      // fenêtre d'un jour suffit à prouver que les trois colonnes suivront.
      expect(range.to.difference(range.from).inHours, 24);
      expect(find.textContaining("aujourd'hui"), findsWidgets);
    });
  });
}
