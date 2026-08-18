import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/features/auth/domain/profile.dart';
import 'package:stylik/features/auth/domain/user_role.dart';
import 'package:stylik/features/finance/domain/finance_summary.dart';
import 'package:stylik/features/finance/presentation/finance_providers.dart';
import 'package:stylik/features/staff/presentation/staff_providers.dart';

/// Rapport « Par coiffeur ». Il se construit à partir des ventes : sans
/// complément, un coiffeur qui n'a rien encaissé disparaît du rapport, et on
/// le croit absent de l'équipe.
void main() {
  Profile member(String id, String name, {double rate = 30}) => Profile(
    id: id,
    salonId: 'salon',
    fullName: name,
    role: UserRole.coiffeur,
    commissionRate: rate,
  );

  StylistCommission earned(String id, String name, int revenue) =>
      StylistCommission(
        stylistId: id,
        stylistName: name,
        revenueFcfa: revenue,
        commissionFcfa: (revenue * 0.3).round(),
        serviceCount: 3,
        commissionRate: 30,
      );

  ProviderContainer container({
    required List<Profile> team,
    required List<StylistCommission> commissions,
  }) {
    final c = ProviderContainer(
      overrides: [
        stylistsProvider.overrideWith((ref) async => team),
        commissionsProvider.overrideWith((ref) async => commissions),
      ],
    );
    addTearDown(c.dispose);
    c.read(stylistsProvider);
    c.read(commissionsProvider);
    return c;
  }

  test('un coiffeur sans vente apparaît quand même, à zéro', () async {
    final c = container(
      team: [member('ancien', 'Awa Traoré'), member('nouveau', 'Bakary Keïta')],
      commissions: [earned('ancien', 'Awa Traoré', 100000)],
    );
    await c.read(stylistsProvider.future);
    await c.read(commissionsProvider.future);

    final rows = c.read(stylistReportProvider);
    expect(rows.map((r) => r.stylistName), ['Awa Traoré', 'Bakary Keïta']);

    final nouveau = rows.firstWhere((r) => r.stylistId == 'nouveau');
    expect(nouveau.revenueFcfa, 0);
    expect(nouveau.commissionFcfa, 0);
    // Le taux vient de la fiche : il doit rester lisible avant la première
    // vente, sinon le gérant croit avoir oublié de le renseigner.
    expect(nouveau.commissionRate, 30);
  });

  test('les plus productifs sont en tête', () async {
    final c = container(
      team: [member('a', 'A'), member('b', 'B'), member('c', 'C')],
      commissions: [earned('a', 'A', 50000), earned('c', 'C', 300000)],
    );
    await c.read(stylistsProvider.future);
    await c.read(commissionsProvider.future);

    expect(c.read(stylistReportProvider).map((r) => r.stylistId), [
      'c',
      'a',
      'b',
    ]);
  });

  test('aucune ligne n\'est dupliquée', () async {
    final c = container(
      team: [member('a', 'A')],
      commissions: [earned('a', 'A', 50000)],
    );
    await c.read(stylistsProvider.future);
    await c.read(commissionsProvider.future);

    final rows = c.read(stylistReportProvider);
    expect(rows.length, 1);
    expect(rows.single.revenueFcfa, 50000);
  });

  test('une vente d\'un membre absent de l\'équipe reste visible', () async {
    // Fiche désactivée ou supprimée depuis : sa commission a été acquise et
    // ne doit pas disparaître du rapport.
    final c = container(
      team: [member('a', 'A')],
      commissions: [earned('parti', 'Ancien membre', 80000)],
    );
    await c.read(stylistsProvider.future);
    await c.read(commissionsProvider.future);

    expect(c.read(stylistReportProvider).map((r) => r.stylistId), [
      'parti',
      'a',
    ]);
  });
}
