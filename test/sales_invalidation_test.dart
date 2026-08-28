import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/features/finance/domain/finance_summary.dart';
import 'package:stylik/features/finance/presentation/finance_providers.dart';
import 'package:stylik/features/home/presentation/home_providers.dart';

/// Après une vente, tout ce qui se calcule à partir des transactions doit être
/// relu.
///
/// Ces providers ne sont pas `autoDispose` : sans invalidation explicite ils
/// gardent leur valeur pour toute la vie de l'application. C'est ce qui
/// obligeait à quitter et relancer pour voir une commission bouger.
void main() {
  /// Un provider qui change de valeur à chaque lecture : si l'invalidation a
  /// bien eu lieu, la seconde lecture diffère de la première.
  late int reads;

  ProviderContainer container() {
    reads = 0;
    final c = ProviderContainer(
      overrides: [
        commissionsProvider.overrideWith((ref) async {
          reads++;
          return [
            StylistCommission(
              stylistId: 'a',
              stylistName: 'Awa Traoré',
              revenueFcfa: 1000 * reads,
              commissionFcfa: 300 * reads,
              serviceCount: reads,
            ),
          ];
        }),
        financeSummaryProvider.overrideWith((ref) async {
          reads++;
          return FinanceSummary(
            from: DateTime(2026, 8),
            to: DateTime(2026, 9),
            revenueFcfa: 1000 * reads,
            collectedFcfa: 1000 * reads,
            ticketCount: reads,
          );
        }),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('sans invalidation, la commission reste figée', () async {
    final c = container();
    final first = await c.read(commissionsProvider.future);

    // Une seconde lecture ne redéclenche rien : c'est le cache de Riverpod,
    // et c'est exactement le comportement qui bloquait l'écran.
    final second = await c.read(commissionsProvider.future);
    expect(second.single.commissionFcfa, first.single.commissionFcfa);
  });

  test('après une vente, la commission est recalculée', () async {
    final c = container();
    final before = await c.read(commissionsProvider.future);

    for (final provider in salesDerivedProviders) {
      c.invalidate(provider);
    }
    final after = await c.read(commissionsProvider.future);

    expect(after.single.commissionFcfa, isNot(before.single.commissionFcfa));
  });

  test('le chiffre d\'affaires est relu lui aussi', () async {
    final c = container();
    final before = await c.read(financeSummaryProvider.future);

    for (final provider in salesDerivedProviders) {
      c.invalidate(provider);
    }
    final after = await c.read(financeSummaryProvider.future);

    expect(after.revenueFcfa, isNot(before.revenueFcfa));
  });

  test('la liste couvre les trois familles de chiffres', () {
    // Un provider oublié de la liste se remarque ici plutôt que sur le
    // terrain, des mois plus tard.
    expect(salesDerivedProviders, contains(commissionsProvider));
    expect(salesDerivedProviders, contains(financeSummaryProvider));
    expect(salesDerivedProviders, contains(servicePerformanceProvider));
    expect(salesDerivedProviders, contains(financeBucketsProvider));
    expect(salesDerivedProviders, contains(twoWeekTransactionsProvider));
  });
}
