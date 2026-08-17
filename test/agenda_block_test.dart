import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/agenda/domain/appointment.dart';
import 'package:stylik/features/agenda/presentation/agenda_page.dart';
import 'package:stylik/features/agenda/presentation/agenda_providers.dart';
import 'package:stylik/features/auth/domain/profile.dart';
import 'package:stylik/features/auth/domain/user_role.dart';
import 'package:stylik/features/auth/presentation/auth_providers.dart';
import 'package:stylik/features/staff/presentation/staff_providers.dart';

/// Grille du planning. La hauteur d'un bloc suit la durée du rendez-vous :
/// une prestation courte ne laisse pas la place à deux lignes de texte, ce
/// qui provoquait un « BOTTOM OVERFLOWED BY 13 PIXELS ».
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeDateFormatting(Formatters.locale);
  });

  final day = DateTime.now();

  const manager = Profile(
    id: 'gerant',
    salonId: 'salon',
    fullName: 'Fatoumata Traoré',
    role: UserRole.gerant,
  );

  const stylist = Profile(
    id: 'moi',
    salonId: 'salon',
    fullName: 'Bakary Keïta',
    role: UserRole.coiffeur,
  );

  Appointment appointment({required int hour, required int minutes}) =>
      Appointment(
        id: 'a-$hour-$minutes',
        salonId: 'salon',
        clientId: 'c1',
        stylistId: 'moi',
        startTime: DateTime(day.year, day.month, day.day, hour),
        endTime: DateTime(day.year, day.month, day.day, hour)
            .add(Duration(minutes: minutes)),
        status: AppointmentStatus.confirmed,
        totalPriceFcfa: 15000,
        clientName: 'Mahamadou Santara',
        services: const [
          AppointmentService(
            serviceId: 's1',
            name: 'Coupe dégradé et barbe',
            priceFcfa: 15000,
            durationMinutes: 30,
          ),
        ],
      );

  Profile extra(String id, String name) => Profile(
        id: id,
        salonId: 'salon',
        fullName: name,
        role: UserRole.coiffeur,
      );

  Widget host(
    List<Appointment> appointments, {
    List<Profile> team = const [stylist],
  }) =>
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => manager),
          stylistsProvider.overrideWith((ref) async => team),
          dayAppointmentsProvider.overrideWith((ref) async => appointments),
        ],
        child: const MaterialApp(
          locale: Locale('fr', 'FR'),
          supportedLocales: [Locale('fr', 'FR'), Locale('en')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AgendaPage(),
        ),
      );

  testWidgets('un rendez-vous court ne deborde pas', (tester) async {
    await tester.pumpWidget(host([appointment(hour: 16, minutes: 30)]));
    await tester.pumpAndSettle();

    // `pumpAndSettle` n'echoue pas sur un overflow : c'est l'absence
    // d'exception de layout qui compte, et le test echouerait sinon.
    expect(tester.takeException(), isNull);
    expect(find.text('Mahamadou Santara'), findsOneWidget);
  });

  testWidgets('un rendez-vous tres court reste lisible', (tester) async {
    await tester.pumpWidget(host([appointment(hour: 10, minutes: 15)]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Le nom du client survit meme au bloc le plus etroit.
    expect(find.text('Mahamadou Santara'), findsOneWidget);
  });

  testWidgets('un rendez-vous long affiche aussi la prestation',
      (tester) async {
    await tester.pumpWidget(host([appointment(hour: 9, minutes: 120)]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Mahamadou Santara'), findsOneWidget);
    expect(find.text('Coupe dégradé et barbe'), findsOneWidget);
  });

  testWidgets('plusieurs rendez-vous courts a la suite', (tester) async {
    await tester.pumpWidget(
      host([
        appointment(hour: 9, minutes: 30),
        appointment(hour: 11, minutes: 20),
        appointment(hour: 14, minutes: 45),
      ]),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('largeur des colonnes', () {
    testWidgets('une equipe nombreuse garde des colonnes lisibles',
        (tester) async {
      // Surface d un telephone : sur les 800 px par defaut, cinq colonnes
      // tiennent sans que la largeur minimale n entre en jeu.
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(
          [appointment(hour: 16, minutes: 30)],
          team: [
            stylist,
            extra('b', 'Bani Coulibaly'),
            extra('c', 'Karim Keita'),
            extra('d', 'Simon Diarra'),
            extra('e', 'Awa Traore'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Cinq colonnes ne se partagent plus la largeur de l ecran : chacune
      // garde au moins `minColumnWidth`, la grille defile.
      final widths = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .map((b) => b.width)
          .whereType<double>()
          .where((w) => w == AgendaPage.minColumnWidth);
      expect(widths, isNotEmpty);
    });

    testWidgets('le nom du client n est plus tronque a l affichage',
        (tester) async {
      await tester.pumpWidget(host([appointment(hour: 16, minutes: 30)]));
      await tester.pumpAndSettle();

      // Un seul coiffeur : la colonne occupe toute la largeur disponible.
      expect(find.text('Mahamadou Santara'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('les heures restent visibles', (tester) async {
      await tester.pumpWidget(
        host(
          const [],
          team: [stylist, extra('b', 'Bani'), extra('c', 'Karim')],
        ),
      );
      await tester.pumpAndSettle();

      // La colonne des heures est hors du defilement horizontal.
      expect(find.text('9h'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
