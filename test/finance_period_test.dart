import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/finance/domain/finance_summary.dart';
import 'package:stylik/features/finance/presentation/finance_providers.dart';

/// Périodes de l'écran Finance. Elles sont **calendaires** : « Mois » désigne
/// août du 1er au 31, et non les trente derniers jours. Un décalage ici ferait
/// afficher les chiffres d'une période sous le titre d'une autre.
void main() {
  setUpAll(() => initializeDateFormatting(Formatters.locale));

  // Lundi 17 août 2026, pour que les bornes de semaine soient vérifiables.
  final monday = DateTime(2026, 8, 17);
  final thursday = DateTime(2026, 8, 20);

  group('fenêtres calendaires', () {
    test('un jour va de minuit à minuit', () {
      final range = FinancePeriod.day.rangeFor(DateTime(2026, 8, 20, 15, 30));
      expect(range.from, DateTime(2026, 8, 20));
      expect(range.to, DateTime(2026, 8, 21));
    });

    test('une semaine commence le lundi, quel que soit le jour visé', () {
      for (var offset = 0; offset < 7; offset++) {
        final range = FinancePeriod.week.rangeFor(
          monday.add(Duration(days: offset)),
        );
        expect(range.from, monday, reason: 'jour +$offset');
        expect(range.to, monday.add(const Duration(days: 7)));
      }
    });

    test('un mois va du 1er au 1er suivant', () {
      final range = FinancePeriod.month.rangeFor(DateTime(2026, 8, 20));
      expect(range.from, DateTime(2026, 8, 1));
      expect(range.to, DateTime(2026, 9, 1));
    });

    test('février bissextile est couvert entièrement', () {
      // 2028 est bissextile : la fenêtre doit contenir le 29.
      final range = FinancePeriod.month.rangeFor(DateTime(2028, 2, 10));
      expect(range.to.difference(range.from).inDays, 29);
    });

    test('une année va du 1er janvier au 1er janvier suivant', () {
      final range = FinancePeriod.year.rangeFor(DateTime(2026, 8, 20));
      expect(range.from, DateTime(2026));
      expect(range.to, DateTime(2027));
    });
  });

  group('déplacement de l\'ancre', () {
    test('reculer d\'un mois depuis un 31 ne saute pas de mois', () {
      // Le piège classique : 31 mars moins un mois donnerait le 3 mars sans
      // normalisation au jour 1.
      final previous = FinancePeriod.month.shift(DateTime(2026, 3, 31), -1);
      expect(previous.year, 2026);
      expect(previous.month, 2);
    });

    test('les fenêtres successives s\'enchaînent sans trou', () {
      for (final period in FinancePeriod.values) {
        var anchor = DateTime(2026, 8, 17);
        for (var step = 0; step < 4; step++) {
          final current = period.rangeFor(anchor);
          final previous = period.rangeFor(period.shift(anchor, -1));
          expect(previous.to, current.from, reason: '${period.label} $step');
          anchor = period.shift(anchor, -1);
        }
      }
    });

    test('janvier moins un mois retombe en décembre précédent', () {
      final previous = FinancePeriod.month.shift(DateTime(2026, 1, 15), -1);
      expect(previous.month, 12);
      expect(previous.year, 2025);
    });
  });

  group('colonnes de l\'histogramme', () {
    test('la journée se lit dans sa semaine, du lundi au vendredi', () {
      final buckets = FinancePeriod.day.chartBuckets(thursday);

      expect(buckets.length, 5);
      expect(buckets.first.from, monday);
      expect(buckets.last.to, monday.add(const Duration(days: 5)));
      expect(buckets.first.label.toLowerCase(), startsWith('lun'));
    });

    test('la semaine couvre les sept jours', () {
      final buckets = FinancePeriod.week.chartBuckets(thursday);

      expect(buckets.length, 7);
      expect(buckets.first.from, monday);
      expect(buckets.last.to, monday.add(const Duration(days: 7)));
    });

    test('le mois se lit dans son année, en douze colonnes', () {
      final buckets = FinancePeriod.month.chartBuckets(DateTime(2026, 8, 20));

      expect(buckets.length, 12);
      expect(buckets.first.from, DateTime(2026));
      expect(buckets.last.to, DateTime(2027));
    });

    test('l\'année se lit sur quatre exercices', () {
      final buckets = FinancePeriod.year.chartBuckets(DateTime(2026, 8, 20));

      expect(buckets.length, 4);
      expect(buckets.map((b) => b.label), ['2023', '2024', '2025', '2026']);
    });

    test('la tranche courante est repérée', () {
      expect(FinancePeriod.day.highlightIndexFor(thursday), 3);
      expect(FinancePeriod.month.highlightIndexFor(DateTime(2026, 8, 20)), 7);
      expect(FinancePeriod.year.highlightIndexFor(DateTime(2026, 8, 20)), 3);
    });

    test('aucun libellé générique ne subsiste', () {
      // « S1 », « S2 »… ne disent rien de la période représentée.
      for (final period in FinancePeriod.values) {
        for (final bucket in period.chartBuckets(thursday)) {
          expect(
            RegExp(r'^S\d+$').hasMatch(bucket.label),
            isFalse,
            reason: bucket.label,
          );
        }
      }
    });
  });

  group('titres', () {
    test('la période en cours est nommée, pas datée', () {
      final now = DateTime.now();
      expect(FinancePeriod.day.titleFor(now), "aujourd'hui");
      expect(FinancePeriod.week.titleFor(now), 'cette semaine');
    });

    test('un mois porte son nom et son année', () {
      final title = FinancePeriod.month.titleFor(DateTime(2026, 8, 20));
      expect(title, contains('2026'));
    });

    test('une année porte son millésime', () {
      expect(FinancePeriod.year.titleFor(DateTime(2026, 8, 20)), '2026');
    });

    test('le sélecteur d\'année ne sert qu\'au mois et à l\'année', () {
      expect(FinancePeriod.day.hasYearPicker, isFalse);
      expect(FinancePeriod.week.hasYearPicker, isFalse);
      expect(FinancePeriod.month.hasYearPicker, isTrue);
      expect(FinancePeriod.year.hasYearPicker, isTrue);
    });
  });

  group('résultat net', () {
    ProviderContainer withFigures({
      required int revenue,
      required int commissions,
      required int expenses,
    }) {
      final c = ProviderContainer(
        overrides: [
          financeSummaryProvider.overrideWith(
            (ref) async => FinanceSummary(
              from: DateTime(2026, 8),
              to: DateTime(2026, 9),
              revenueFcfa: revenue,
              ticketCount: 4,
            ),
          ),
          commissionsProvider.overrideWith(
            (ref) async => [
              StylistCommission(
                stylistId: 'a',
                stylistName: 'A',
                revenueFcfa: revenue,
                commissionFcfa: commissions,
                serviceCount: 4,
              ),
            ],
          ),
          expensesProvider.overrideWith(
            (ref) async => [
              Expense(
                id: 'e1',
                salonId: 'salon',
                label: 'Loyer',
                amountFcfa: expenses,
                category: ExpenseCategory.rent,
                spentAt: DateTime(2026, 8, 5),
              ),
            ],
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<void> warm(ProviderContainer c) async {
      await c.read(financeSummaryProvider.future);
      await c.read(commissionsProvider.future);
      await c.read(expensesProvider.future);
    }

    test('les commissions sont retranchées du net', () async {
      final c = withFigures(
        revenue: 300000,
        commissions: 90000,
        expenses: 50000,
      );
      await warm(c);

      // 300 000 − 90 000 − 50 000. Sans les commissions, le net afficherait
      // 250 000 et surestimerait de 90 000 ce qui reste au gérant.
      expect(c.read(periodCommissionsProvider), 90000);
      expect(c.read(netResultProvider), 160000);
    });

    test('un net négatif reste négatif', () async {
      final c = withFigures(
        revenue: 100000,
        commissions: 60000,
        expenses: 80000,
      );
      await warm(c);

      expect(c.read(netResultProvider), -40000);
    });

    test(
      'la marge est nulle plutôt que zéro sans chiffre d\'affaires',
      () async {
        final c = withFigures(revenue: 0, commissions: 0, expenses: 0);
        await warm(c);

        // « 0 % » se lirait comme une activité non rentable, alors qu'il n'y a
        // simplement aucune activité.
        expect(c.read(netMarginProvider), isNull);
      },
    );
  });

  group('periode de comparaison', () {
    test('un mois se compare au mois precedent, nomme', () {
      final label = FinancePeriod.month.previousLabelFor(DateTime(2026, 8, 20));
      // « vs periode precedente » n apprend rien ; le badge doit nommer juillet.
      expect(label.toLowerCase(), contains('juillet'));
    });

    test('une annee se compare au millesime precedent', () {
      expect(
        FinancePeriod.year.previousLabelFor(DateTime(2026, 8, 20)),
        'vs 2025',
      );
    });

    test('le jour et la semaine ont un libelle relatif', () {
      final now = DateTime(2026, 8, 20);
      expect(FinancePeriod.day.previousLabelFor(now), 'vs hier');
      expect(FinancePeriod.week.previousLabelFor(now), contains('semaine'));
    });

    test('la comparaison couvre le mois entier, pas une duree egale', () {
      // Fevrier fait 28 jours : reculer d une duree egale ferait demarrer le
      // « mois precedent » le 4 janvier, et le badge mentirait de trois jours.
      final february = FinancePeriod.month.rangeFor(DateTime(2026, 2, 10));
      final january = FinancePeriod.month.rangeFor(
        FinancePeriod.month.shift(DateTime(2026, 2, 10), -1),
      );

      expect(january.from, DateTime(2026, 1, 1));
      expect(january.to, DateTime(2026, 2, 1));
      expect(january.to, february.from);
      expect(january.to.difference(january.from).inDays, 31);
    });
  });
}
