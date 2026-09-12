import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/finance/domain/finance_summary.dart';
import 'package:stylik/features/finance/domain/payout.dart';
import 'package:stylik/features/finance/presentation/finance_providers.dart';
import 'package:stylik/features/finance/presentation/stylist_commission_detail_page.dart';

/// Feuille « Enregistrer un versement », côté gérant.
///
/// Le bouton de validation était le dernier enfant de la zone défilante : avec
/// beaucoup de journées, il sortait de l'écran et il fallait faire défiler
/// jusqu'en bas pour valider, sans que rien ne l'indique.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeDateFormatting(Formatters.locale);
  });

  const stylistId = 'a';

  const commission = StylistCommission(
    stylistId: stylistId,
    stylistName: 'Mahamadou Santara',
    revenueFcfa: 6000,
    commissionFcfa: 1800,
    serviceCount: 4,
    commissionRate: 30,
  );

  /// Un écran de téléphone : c'est là que la place manque.
  void usePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  List<DailyCommissionItem> manyDays(int count) {
    final today = DateTime.now();
    return [
      for (var i = count - 1; i >= 0; i--)
        DailyCommissionItem(
          date: DateTime(today.year, today.month, today.day - i),
          label: Formatters.weekdayDayMonth(
            DateTime(today.year, today.month, today.day - i),
          ),
          serviceCount: 2,
          revenueFcfa: 1500,
          commissionFcfa: 450,
          isCurrentDay: i == 0,
        ),
    ];
  }

  Widget host({
    required List<DailyCommissionItem> days,
    int earned = 1800,
    List<PayoutRequest> payouts = const [],
  }) => ProviderScope(
    overrides: [
      stylistPayoutsProvider(stylistId).overrideWith((ref) async => payouts),
      stylistDailyCommissionsProvider(
        stylistId,
      ).overrideWith((ref) async => days),
      cumulativeCommissionsProvider.overrideWith(
        (ref) async => [
          StylistCommission(
            stylistId: stylistId,
            stylistName: 'Mahamadou Santara',
            revenueFcfa: earned * 100 ~/ 30,
            commissionFcfa: earned,
            serviceCount: 10,
            commissionRate: 30,
          ),
        ],
      ),
    ],
    child: const MaterialApp(
      locale: Locale('fr', 'FR'),
      home: StylistCommissionDetailPage(commission: commission),
    ),
  );

  testWidgets('le bouton reste visible malgré trente journées', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(host(days: manyDays(30), earned: 13500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer un versement'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Il doit être à l'écran sans avoir à faire défiler quoi que ce soit.
    final button = find.text('Enregistrer le versement');
    expect(button, findsOneWidget);

    final box = tester.getRect(button);
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      box.bottom,
      lessThanOrEqualTo(screenHeight),
      reason: 'le bouton dépasse le bas de l\'écran',
    );
    expect(box.top, greaterThanOrEqualTo(0));
  });

  testWidgets('le bouton est là aussi avec une seule journée', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(host(days: manyDays(1), earned: 450));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer un versement'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Enregistrer le versement'), findsOneWidget);
  });

  testWidgets('sans rien à verser, la feuille ne s\'ouvre pas', (tester) async {
    usePhone(tester);
    // Tout est réglé : le pied de page annonce l'état au lieu d'un bouton
    // actif qui mènerait à une feuille vide.
    await tester.pumpWidget(
      host(
        days: manyDays(2),
        earned: 900,
        payouts: [
          PayoutRequest(
            id: 'p1',
            salonId: 'salon',
            profileId: stylistId,
            amountFcfa: 900,
            status: PayoutStatus.paid,
            requestedAt: DateTime.now(),
            paidAt: DateTime.now(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Toutes les commissions sont réglées'), findsOneWidget);
  });

  testWidgets('le montant reste sous les yeux, liste dépliée', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(host(days: manyDays(30), earned: 13500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer un versement'));
    await tester.pumpAndSettle();

    // La liste dépliée poussait le champ « Montant versé » hors de l'écran :
    // le gérant validait sans voir ce qu'il allait sortir de sa caisse.
    await tester.tap(find.textContaining('Choisir les journées'));
    await tester.pumpAndSettle();

    final recap = find.textContaining('À verser');
    expect(recap, findsOneWidget);

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final box = tester.getRect(recap);
    expect(box.bottom, lessThanOrEqualTo(screenHeight));
    expect(box.top, greaterThanOrEqualTo(0));

    // Et il porte bien le montant, pas seulement le libellé.
    expect(find.text('À verser : ${Formatters.fcfa(13500)}'), findsOneWidget);
  });
}
