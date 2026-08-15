import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stylik/core/utils/formatters.dart';
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
}
