import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/core/widgets/widgets.dart';
import 'package:stylik/features/auth/domain/profile.dart';
import 'package:stylik/features/auth/domain/user_role.dart';
import 'package:stylik/features/auth/presentation/auth_providers.dart';
import 'package:stylik/features/staff/presentation/staff_providers.dart';
import 'package:stylik/features/staff/presentation/time_off_request_page.dart';

/// Écran de demande de congé. Le sélecteur de date est le point sensible :
/// `showDatePicker` exige des `MaterialLocalizations` pour la locale demandée,
/// et l'app n'embarquait aucun délégué — demander une date en français faisait
/// donc échouer la résolution et cassait la sélection.
void main() {
  setUpAll(() => initializeDateFormatting(Formatters.locale));

  const profile = Profile(
    id: 'moi',
    salonId: 'salon',
    fullName: 'Bakary Keïta',
    role: UserRole.coiffeur,
    leaveBalanceDays: 12,
  );

  Widget host() => ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((ref) async => profile),
          teamProvider.overrideWith((ref) async => const <Profile>[]),
        ],
        child: const MaterialApp(
          // Même configuration que `AtelierApp` : c'est elle qui rend le
          // sélecteur natif utilisable en français.
          locale: Locale('fr', 'FR'),
          supportedLocales: [Locale('fr', 'FR'), Locale('en')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: TimeOffRequestPage(),
        ),
      );

  testWidgets('le sélecteur de date s\'ouvre en français', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // La zone cliquable est le corps du champ, pas son libellé : « Du » est
    // le premier des deux `AppSelectField` de la période.
    await tester.tap(find.byType(AppSelectField).first);
    await tester.pumpAndSettle();

    // Sans les délégués, cette ouverture lançait une exception au lieu
    // d'afficher le calendrier.
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // Le libellé vient de `GlobalMaterialLocalizations` : en anglais il dirait
    // « Cancel ». C'est la preuve que la locale fr est bien résolue.
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(DatePickerDialog)),
    );
    expect(localizations.cancelButtonLabel, 'Annuler');
    expect(localizations.datePickerHelpText.toLowerCase(), contains('date'));

    await tester.tap(find.text(localizations.cancelButtonLabel));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('la durée part à un jour et le solde est affiché',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // Bornes incluses : même début et même fin font une journée, pas zéro.
    expect(find.text('1 jour'), findsOneWidget);
    expect(find.text('12 j restants'), findsOneWidget);
  });

  testWidgets('les trois types d\'absence sont proposés', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Congé'), findsOneWidget);
    expect(find.text('Maladie'), findsOneWidget);
    expect(find.text('Absence'), findsOneWidget);
  });
}
