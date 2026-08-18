import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/agenda/domain/appointment.dart';
import 'package:stylik/features/agenda/presentation/agenda_providers.dart';
import 'package:stylik/features/auth/domain/profile.dart';
import 'package:stylik/features/auth/domain/user_role.dart';
import 'package:stylik/features/finance/domain/finance_summary.dart';
import 'package:stylik/features/finance/presentation/finance_providers.dart';
import 'package:stylik/features/home/presentation/reception_home_page.dart';
import 'package:stylik/features/home/presentation/stylist_home_page.dart';
import 'package:stylik/features/pos/domain/payment_method.dart';
import 'package:stylik/features/pos/domain/ticket.dart';
import 'package:stylik/features/pos/presentation/pos_providers.dart';

/// Les deux tableaux de bord métier. Ces écrans empilent des `Row` en
/// `CrossAxisAlignment.stretch` dans une page défilante — la combinaison qui
/// avait fait planter l'accueil sur `BoxConstraints forces an infinite height`.
/// On les rend donc pour de vrai : une exception de layout fait échouer le test.
void main() {
  // `Formatters` construit ses `DateFormat` sur la locale fr : sans ces
  // données, tout écran affichant une heure ou un mois lève `LocaleDataException`.
  setUpAll(() => initializeDateFormatting(Formatters.locale));

  final today = DateTime.now();

  Appointment appointment({
    required String id,
    required int hour,
    AppointmentStatus status = AppointmentStatus.confirmed,
    String? stylistName,
  }) => Appointment(
    id: id,
    salonId: 'salon',
    clientId: 'client-$id',
    stylistId: 'moi',
    startTime: DateTime(today.year, today.month, today.day, hour),
    endTime: DateTime(today.year, today.month, today.day, hour + 1),
    status: status,
    totalPriceFcfa: 15000,
    clientName: 'Julien Petit',
    stylistName: stylistName,
  );

  SalonTransaction paidFor(String appointmentId) => SalonTransaction(
    id: 'tx-$appointmentId',
    salonId: 'salon',
    appointmentId: appointmentId,
    subtotalFcfa: 15000,
    discountFcfa: 0,
    totalAmountFcfa: 15000,
    paymentMethod: PaymentMethod.cash,
    status: TransactionStatus.paid,
    createdAt: today,
  );

  Widget host(Widget child, List<Override> overrides) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          // Hauteur non bornée, comme dans `AppScreen`.
          child: child,
        ),
      ),
    ),
  );

  group('accueil coiffeur', () {
    testWidgets('affiche la commission du mois et le planning du jour', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          StylistHomePage(
            profile: const Profile(
              id: 'moi',
              salonId: 'salon',
              fullName: 'Karim Diop',
              role: UserRole.coiffeur,
              commissionRate: 30,
            ),
          ),
          [
            dayAppointmentsProvider.overrideWith(
              (ref) async => [
                appointment(id: 'a1', hour: 10),
                appointment(id: 'a2', hour: 11),
              ],
            ),
            myMonthCommissionProvider.overrideWith(
              (ref) async => const StylistCommission(
                stylistId: 'moi',
                stylistName: 'Karim Diop',
                revenueFcfa: 2104000,
                commissionFcfa: 322000,
                serviceCount: 12,
                commissionRate: 30,
                clientCount: 96,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Ma commission à recevoir'), findsOneWidget);
      // Via `Formatters` : la locale fr sépare les milliers par une espace
      // insécable, qu'une chaîne écrite à la main ne reproduit pas.
      expect(find.text(Formatters.fcfa(322000)), findsOneWidget);
      expect(find.text(Formatters.fcfa(2104000)), findsOneWidget);
      expect(find.text('30 %'), findsOneWidget);
      expect(find.text('Mon planning'), findsOneWidget);
      expect(find.text('96'), findsOneWidget);
    });

    testWidgets('sans vente du mois, le taux vient de la fiche employé', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const StylistHomePage(
            profile: Profile(
              id: 'moi',
              salonId: 'salon',
              fullName: 'Karim Diop',
              role: UserRole.coiffeur,
              commissionRate: 30,
            ),
          ),
          [
            dayAppointmentsProvider.overrideWith((ref) async => const []),
            // Aucune ligne : le mois n'a produit aucune vente encaissée.
            myMonthCommissionProvider.overrideWith((ref) async => null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Un mois sans vente affiche bien 0 F, mais surtout pas « 0 % » à
      // quelqu'un qui touche 30 % : le taux se rabat sur le profil.
      expect(find.text(Formatters.fcfa(0)), findsWidgets);
      expect(find.text('30 %'), findsOneWidget);
      expect(find.text('Journée libre'), findsOneWidget);
    });
  });

  group('accueil réceptionniste', () {
    testWidgets('compte les prestations terminées non encaissées', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const ReceptionHomePage(), [
          dayAppointmentsProvider.overrideWith(
            (ref) async => [
              // Terminée et payée : ne compte pas.
              appointment(
                id: 'paye',
                hour: 9,
                status: AppointmentStatus.completed,
              ),
              // Terminée sans ticket : à clôturer.
              appointment(
                id: 'impaye',
                hour: 10,
                status: AppointmentStatus.completed,
              ),
              appointment(id: 'a-venir', hour: 23, stylistName: 'Karim'),
            ],
          ),
          todayTransactionsProvider.overrideWith(
            (ref) async => [paidFor('paye')],
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('À encaisser'), findsOneWidget);
      expect(find.textContaining('1 ticket(s) à clôturer'), findsOneWidget);
      expect(find.text('Nouveau RDV'), findsOneWidget);
      expect(find.text('Ouvrir caisse'), findsOneWidget);
      expect(find.text('Prochains RDV · tout le salon'), findsOneWidget);
    });

    testWidgets('aucune alerte quand tout est encaissé', (tester) async {
      await tester.pumpWidget(
        host(const ReceptionHomePage(), [
          dayAppointmentsProvider.overrideWith(
            (ref) async => [
              appointment(
                id: 'paye',
                hour: 9,
                status: AppointmentStatus.completed,
              ),
            ],
          ),
          todayTransactionsProvider.overrideWith(
            (ref) async => [paidFor('paye')],
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('à clôturer'), findsNothing);
    });
  });
}
