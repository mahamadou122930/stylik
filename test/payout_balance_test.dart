import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/features/auth/domain/profile.dart';
import 'package:stylik/features/auth/domain/user_role.dart';
import 'package:stylik/features/auth/presentation/auth_providers.dart';
import 'package:stylik/features/finance/domain/finance_summary.dart';
import 'package:stylik/features/finance/domain/payout.dart';
import 'package:stylik/features/finance/presentation/finance_providers.dart';

/// Le « à recevoir » de l'écran Mes commissions. C'est le chiffre sur lequel
/// un employé compte pour être payé : une erreur ici lui fait réclamer deux
/// fois la même somme, ou croire qu'on lui doit moins que la réalité.
///
/// Le solde est **cumulatif** : tout ce qui a été gagné depuis l'ouverture,
/// moins tout ce qui a été versé ou est déjà demandé.
void main() {
  const profile = Profile(
    id: 'moi',
    salonId: 'salon',
    fullName: 'Karim Coulibaly',
    role: UserRole.coiffeur,
    commissionRate: 30,
  );

  final now = DateTime.now();

  PayoutRequest payout({
    required int amount,
    required PayoutStatus status,
    DateTime? paidAt,
  }) => PayoutRequest(
    id: 'p-$amount-${status.value}',
    salonId: 'salon',
    profileId: 'moi',
    amountFcfa: amount,
    status: status,
    requestedAt: now,
    paidAt: paidAt,
  );

  Future<({int earned, int paid, int pending, int available})> balanceWith({
    required int earned,
    required List<PayoutRequest> payouts,
    bool warm = true,
  }) async {
    final container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => profile),
        cumulativeCommissionsProvider.overrideWith(
          (ref) async => [
            StylistCommission(
              stylistId: 'moi',
              stylistName: 'Karim Coulibaly',
              revenueFcfa: earned * 100 ~/ 30,
              commissionFcfa: earned,
              serviceCount: 10,
              commissionRate: 30,
            ),
          ],
        ),
        myPayoutsProvider.overrideWith((ref) async => payouts),
      ],
    );
    addTearDown(container.dispose);

    if (warm) {
      await container.read(currentProfileProvider.future);
      await container.read(cumulativeCommissionsProvider.future);
      await container.read(myPayoutsProvider.future);
    }
    return container.read(payoutBalanceProvider);
  }

  test('sans versement, tout le cumul est réclamable', () async {
    final balance = await balanceWith(earned: 322000, payouts: const []);

    expect(balance.earned, 322000);
    expect(balance.paid, 0);
    expect(balance.available, 322000);
  });

  test('un versement du mois est déduit du disponible', () async {
    final balance = await balanceWith(
      earned: 1022000,
      payouts: [
        payout(
          amount: 700000,
          status: PayoutStatus.paid,
          paidAt: DateTime(now.year, now.month, 1),
        ),
      ],
    );

    expect(balance.paid, 700000);
    expect(balance.available, 322000);
  });

  test('un versement d\'un mois passé reste déduit', () async {
    // Le comportement inverse de celui d'avant : borné au mois courant, ce
    // règlement disparaissait le 1er du mois suivant et le même dû pouvait
    // être payé une seconde fois.
    final balance = await balanceWith(
      earned: 800000,
      payouts: [
        payout(
          amount: 400000,
          status: PayoutStatus.paid,
          paidAt: DateTime(now.year, now.month - 1, 15),
        ),
      ],
    );

    expect(balance.paid, 400000);
    expect(balance.available, 400000);
  });

  test('une commission ancienne non réglée reste réclamable', () async {
    // L'exception voulue : le cumul comprend les mois précédents, donc un dû
    // oublié ne s'évapore pas au changement de mois.
    final balance = await balanceWith(earned: 800000, payouts: const []);

    expect(balance.available, 800000);
  });

  test(
    'une demande en attente n\'est pas réclamable une seconde fois',
    () async {
      final balance = await balanceWith(
        earned: 322000,
        payouts: [payout(amount: 322000, status: PayoutStatus.pending)],
      );

      expect(balance.pending, 322000);
      // Sinon le bouton resterait actif et le gérant recevrait deux demandes.
      expect(balance.available, 0);
    },
  );

  test('une avance supérieure au cumul ne rend pas le solde négatif', () async {
    final balance = await balanceWith(
      earned: 90000,
      payouts: [
        payout(
          amount: 200000,
          status: PayoutStatus.paid,
          paidAt: DateTime(now.year, now.month, 2),
        ),
      ],
    );

    expect(balance.available, 0);
  });

  test('sans données chargées, rien n\'est réclamable', () async {
    final balance = await balanceWith(
      earned: 322000,
      payouts: const [],
      warm: false,
    );

    // Un « à recevoir » affiché avant lecture ferait réclamer à l'aveugle.
    expect(balance.available, 0);
  });
}
