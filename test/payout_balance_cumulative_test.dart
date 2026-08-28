import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/features/finance/domain/finance_summary.dart';
import 'package:stylik/features/finance/domain/payout.dart';
import 'package:stylik/features/finance/presentation/finance_providers.dart';

/// Plafond de versement.
///
/// Il était borné au **mois en cours** : une commission de juillet jamais
/// réglée devenait irréclamable le 1er août, et un versement de juillet
/// n'amputait plus rien en août — le même dû pouvait donc être payé deux fois
/// à cheval sur un changement de mois. Le solde est désormais cumulatif.
void main() {
  PayoutRequest payout({
    required int amount,
    required PayoutStatus status,
    DateTime? paidAt,
  }) => PayoutRequest(
    id: 'p-$amount-${status.value}',
    salonId: 'salon',
    profileId: 'a',
    amountFcfa: amount,
    status: status,
    requestedAt: paidAt ?? DateTime(2026),
    paidAt: status == PayoutStatus.paid
        ? (paidAt ?? DateTime(2026, 7, 10))
        : null,
  );

  ProviderContainer withState({
    required int cumulativeCommission,
    required List<PayoutRequest> payouts,
  }) {
    final c = ProviderContainer(
      overrides: [
        cumulativeCommissionsProvider.overrideWith(
          (ref) async => [
            StylistCommission(
              stylistId: 'a',
              stylistName: 'Awa Traoré',
              revenueFcfa: cumulativeCommission * 3,
              commissionFcfa: cumulativeCommission,
              serviceCount: 40,
            ),
          ],
        ),
        stylistPayoutsProvider('a').overrideWith((ref) async => payouts),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<({int earned, int paid, int pending, int available})> balance(
    ProviderContainer c,
  ) async {
    await c.read(cumulativeCommissionsProvider.future);
    await c.read(stylistPayoutsProvider('a').future);
    return c.read(stylistPayoutBalanceProvider('a'));
  }

  test('sans versement, tout le cumul est réclamable', () async {
    final c = withState(cumulativeCommission: 500000, payouts: const []);

    expect((await balance(c)).available, 500000);
  });

  test('un versement d\'un mois passé ampute toujours le solde', () async {
    // Le point du bug : réglé le 10 juillet, il ne comptait plus en août et
    // laissait redemander la même somme.
    final c = withState(
      cumulativeCommission: 500000,
      payouts: [
        payout(
          amount: 200000,
          status: PayoutStatus.paid,
          paidAt: DateTime(2026, 7, 10),
        ),
      ],
    );

    final b = await balance(c);
    expect(b.paid, 200000);
    expect(b.available, 300000);
  });

  test('une commission ancienne non réglée reste réclamable', () async {
    // L'exception voulue : le cumul comprend juillet, donc le dû survit au
    // changement de mois.
    final c = withState(cumulativeCommission: 800000, payouts: const []);

    expect((await balance(c)).available, 800000);
  });

  test('une demande en attente réserve déjà sa part', () async {
    final c = withState(
      cumulativeCommission: 500000,
      payouts: [payout(amount: 150000, status: PayoutStatus.pending)],
    );

    final b = await balance(c);
    expect(b.pending, 150000);
    // Sans cela, deux demandes successives réclameraient le même dû.
    expect(b.available, 350000);
  });

  test('tout réglé ne laisse rien à demander', () async {
    final c = withState(
      cumulativeCommission: 500000,
      payouts: [payout(amount: 500000, status: PayoutStatus.paid)],
    );

    expect((await balance(c)).available, 0);
  });

  test(
    'un versement supérieur au cumul ne rend pas le solde négatif',
    () async {
      final c = withState(
        cumulativeCommission: 500000,
        payouts: [payout(amount: 700000, status: PayoutStatus.paid)],
      );

      final b = await balance(c);
      expect(b.available, 0);
      // Le versé reste visible en entier : l'avance ne disparaît pas.
      expect(b.paid, 700000);
    },
  );

  test('une demande refusée ne réserve rien', () async {
    final c = withState(
      cumulativeCommission: 500000,
      payouts: [payout(amount: 200000, status: PayoutStatus.rejected)],
    );

    expect((await balance(c)).available, 500000);
  });
}
