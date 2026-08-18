import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/auth/domain/profile.dart';
import 'package:stylik/features/auth/domain/user_role.dart';
import 'package:stylik/features/auth/presentation/auth_providers.dart';
import 'package:stylik/features/finance/domain/finance_summary.dart';
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

  Widget host({
    required List<Profile> team,
    required List<StylistCommission> commissions,
  }) => ProviderScope(
    overrides: [
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
}
