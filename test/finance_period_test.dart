import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
import 'package:stylik/features/finance/domain/finance_summary.dart';
import 'package:stylik/features/finance/presentation/finance_providers.dart';

/// Navigation dans le temps de l'écran Chiffre d'affaires. La fenêtre pilote
/// la synthèse, les commissions et les dépenses : un décalage faux ferait
/// afficher les chiffres d'un jour sous le titre d'un autre.
void main() {
  setUpAll(() => initializeDateFormatting(Formatters.locale));

  DateTime midnight(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  group('fenêtre décalée', () {
    test('sans décalage, la fenêtre est celle en cours', () {
      for (final period in FinancePeriod.values) {
        expect(period.rangeAt(0), period.range, reason: period.label);
      }
    });

    test('« Jour » recule d\'un jour par cran', () {
      final today = midnight(DateTime.now());
      final yesterday = FinancePeriod.day.rangeAt(-1);

      expect(yesterday.from, today.subtract(const Duration(days: 1)));
      expect(yesterday.to, today);
    });

    test('« Semaine » recule de sept jours, « Mois » de trente', () {
      final week = FinancePeriod.week.rangeAt(-1);
      final month = FinancePeriod.month.rangeAt(-1);

      expect(week.to.difference(week.from).inDays, 7);
      expect(month.to.difference(month.from).inDays, 30);

      // Les fenêtres s'enchaînent sans trou ni recouvrement.
      expect(week.to, FinancePeriod.week.range.from);
      expect(month.to, FinancePeriod.month.range.from);
    });

    test('les fenêtres successives ne se chevauchent jamais', () {
      for (final period in FinancePeriod.values) {
        for (var offset = -1; offset >= -5; offset--) {
          expect(
            period.rangeAt(offset).to,
            period.rangeAt(offset + 1).from,
            reason: '${period.label} au cran $offset',
          );
        }
      }
    });
  });

  group('libellés', () {
    test('la période en cours est nommée, pas datée', () {
      expect(FinancePeriod.day.labelAt(0), 'Aujourd\'hui');
      expect(FinancePeriod.week.labelAt(0), 'Cette semaine');
      expect(FinancePeriod.month.labelAt(0), 'Ce mois-ci');
    });

    test('le jour précédent se dit « Hier »', () {
      expect(FinancePeriod.day.labelAt(-1), 'Hier');
      expect(FinancePeriod.day.labelAt(-2), isNot('Hier'));
    });

    test('un intervalle exclut le lendemain de sa borne haute', () {
      // `to` est exclusive : une semaine du 1er au 8 se lit « 1 – 7 ».
      final range = FinancePeriod.week.rangeAt(-1);
      final last = range.to.subtract(const Duration(days: 1));

      expect(
        FinancePeriod.week.labelAt(-1),
        '${Formatters.dayMonth(range.from)} – ${Formatters.dayMonth(last)}',
      );
    });
  });

  group('provider de fenêtre', () {
    test('combine la période et le décalage', () {
      final container = ProviderContainer(
        overrides: [
          financePeriodProvider.overrideWith((ref) => FinancePeriod.day),
          financePeriodOffsetProvider.overrideWith((ref) => -3),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(financeRangeProvider),
        FinancePeriod.day.rangeAt(-3),
      );
    });

    test('revenir à zéro ramène à la période en cours', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(financePeriodProvider.notifier).state = FinancePeriod.day;
      container.read(financePeriodOffsetProvider.notifier).state = -4;
      expect(
        container.read(financeRangeProvider),
        FinancePeriod.day.rangeAt(-4),
      );

      container.read(financePeriodOffsetProvider.notifier).state = 0;
      expect(container.read(financeRangeProvider), FinancePeriod.day.range);
    });
  });

  group('resultat net', () {
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

    test('les commissions sont retranchees du net', () async {
      final c = withFigures(revenue: 300000, commissions: 90000, expenses: 50000);
      await c.read(financeSummaryProvider.future);
      await c.read(commissionsProvider.future);
      await c.read(expensesProvider.future);

      // 300 000 - 90 000 - 50 000. Sans les commissions, le net afficherait
      // 250 000 et surestimerait de 90 000 ce qui reste au gerant.
      expect(c.read(periodCommissionsProvider), 90000);
      expect(c.read(netResultProvider), 160000);
    });

    test('un net negatif reste negatif', () async {
      final c = withFigures(revenue: 100000, commissions: 60000, expenses: 80000);
      await c.read(financeSummaryProvider.future);
      await c.read(commissionsProvider.future);
      await c.read(expensesProvider.future);

      // Une perte doit se voir, pas etre bornee a zero.
      expect(c.read(netResultProvider), -40000);
    });
  });

  group('periode annuelle', () {
    test('l annee couvre douze colonnes sur 365 jours', () {
      expect(FinancePeriod.year.days, 365);
      expect(FinancePeriod.year.bucketCount, 12);

      final range = FinancePeriod.year.range;
      expect(range.to.difference(range.from).inDays, 365);
    });

    test('elle recule d une annee entiere', () {
      final previous = FinancePeriod.year.rangeAt(-1);
      expect(previous.to, FinancePeriod.year.range.from);
    });

    test('son libelle suit la meme regle que les autres', () {
      expect(FinancePeriod.year.labelAt(0), 'Cette annee'.replaceAll('annee', 'année'));
      expect(FinancePeriod.year.labelAt(-1), contains('–'));
    });
  });

  group('libelles des colonnes', () {
    test('une journee est decoupee en heures', () {
      final start = DateTime(2026, 8, 17, 8);
      expect(FinancePeriod.day.bucketLabel(start), '8h');
      expect(FinancePeriod.day.bucketLabel(DateTime(2026, 8, 17, 16)), '16h');
    });

    test('une semaine est decoupee en jours', () {
      // Lundi 17 aout 2026.
      final label = FinancePeriod.week.bucketLabel(DateTime(2026, 8, 17));
      expect(label.toLowerCase(), startsWith('lun'));
    });

    test('un mois est decoupe en dates', () {
      expect(
        FinancePeriod.month.bucketLabel(DateTime(2026, 8, 3)),
        contains('3'),
      );
    });

    test('une annee est decoupee en mois', () {
      final label = FinancePeriod.year.bucketLabel(DateTime(2026, 1, 15));
      expect(label.toLowerCase(), startsWith('janv'));
    });

    test('les douze mois produisent un libelle', () {
      // « mai » ne fait que trois lettres : une troncature fixe a quatre
      // caracteres y levait une RangeError, et seul un mois court la revele.
      for (var month = 1; month <= 12; month++) {
        final label = FinancePeriod.year.bucketLabel(DateTime(2026, month, 1));
        expect(label, isNotEmpty, reason: 'mois $month');
      }

      expect(
        FinancePeriod.year.bucketLabel(DateTime(2026, 5, 1)).toLowerCase(),
        contains('mai'),
      );
    });

    test('aucun libelle generique ne subsiste', () {
      // C'est le symptome rapporte : « S1 », « S2 »… ne disent rien de la
      // periode qu'ils representent.
      for (final period in FinancePeriod.values) {
        final label = period.bucketLabel(DateTime(2026, 8, 17, 9));
        expect(RegExp(r'^S\d+$').hasMatch(label), isFalse, reason: label);
      }
    });
  });
}
