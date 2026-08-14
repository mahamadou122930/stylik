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
void main() {
  const profile = Profile(
    id: 'moi',
    salonId: 'salon',
    fullName: 'Karim Diop',
    role: UserRole.coiffeur,
    commissionRate: 30,
  );

  final now = DateTime.now();

  PayoutRequest payout({
    required int amount,
    required PayoutStatus status,
    DateTime? paidAt,
  }) =>
      PayoutRequest(
        id: 'p-$amount-${status.value}',
        salonId: 'salon',
        profileId: 'moi',
        amountFcfa: amount,
        status: status,
        requestedAt: now,
        paidAt: paidAt,
      );

  ({int earned, int paid, int pending, int available}) balanceWith({
    required int earned,
    required List<PayoutRequest> payouts,
  }) {
    final container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => profile),
        myMonthCommissionProvider.overrideWith(
          (ref) async => StylistCommission(
            stylistId: 'moi',
            stylistName: 'Karim Diop',
            revenueFcfa: earned * 100 ~/ 30,
            commissionFcfa: earned,
            serviceCount: 10,
            commissionRate: 30,
          ),
        ),
        myPayoutsProvider.overrideWith((ref) async => payouts),
      ],
    );
    addTearDown(container.dispose);

    // Les deux sources sont asynchrones : sans attente, le solde lirait zéro.
    container.read(myMonthCommissionProvider);
    container.read(myPayoutsProvider);
    return container.read(payoutBalanceProvider);
  }

  test('sans versement, tout le mois est réclamable', () async {
    final container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => profile),
        myMonthCommissionProvider.overrideWith(
          (ref) async => const StylistCommission(
            stylistId: 'moi',
            stylistName: 'Karim Diop',
            revenueFcfa: 2104000,
            commissionFcfa: 322000,
            serviceCount: 10,
            commissionRate: 30,
          ),
        ),
        myPayoutsProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);
    await container.read(myMonthCommissionProvider.future);
    await container.read(myPayoutsProvider.future);

    final balance = container.read(payoutBalanceProvider);
    expect(balance.earned, 322000);
    expect(balance.paid, 0);
    expect(balance.available, 322000);
  });

  test('un versement du mois est déduit du disponible', () async {
    final container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => profile),
        myMonthCommissionProvider.overrideWith(
          (ref) async => const StylistCommission(
            stylistId: 'moi',
            stylistName: 'Karim Diop',
            revenueFcfa: 2104000,
            commissionFcfa: 1022000,
            serviceCount: 10,
            commissionRate: 30,
          ),
        ),
        myPayoutsProvider.overrideWith(
          (ref) async => [
            payout(
              amount: 700000,
              status: PayoutStatus.paid,
              paidAt: DateTime(now.year, now.month, 1),
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(myMonthCommissionProvider.future);
    await container.read(myPayoutsProvider.future);

    final balance = container.read(payoutBalanceProvider);
    expect(balance.paid, 700000);
    expect(balance.available, 322000);
  });

  test('une demande en attente n\'est pas réclamable une seconde fois',
      () async {
    final container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => profile),
        myMonthCommissionProvider.overrideWith(
          (ref) async => const StylistCommission(
            stylistId: 'moi',
            stylistName: 'Karim Diop',
            revenueFcfa: 2104000,
            commissionFcfa: 322000,
            serviceCount: 10,
            commissionRate: 30,
          ),
        ),
        myPayoutsProvider.overrideWith(
          (ref) async => [
            payout(amount: 322000, status: PayoutStatus.pending),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(myMonthCommissionProvider.future);
    await container.read(myPayoutsProvider.future);

    final balance = container.read(payoutBalanceProvider);
    expect(balance.pending, 322000);
    // Sinon le bouton resterait actif et le gérant recevrait deux demandes.
    expect(balance.available, 0);
  });

  test('un versement d\'un mois passé ne compte pas dans « déjà versé »',
      () async {
    final lastMonth = DateTime(now.year, now.month - 1, 15);
    final container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => profile),
        myMonthCommissionProvider.overrideWith(
          (ref) async => const StylistCommission(
            stylistId: 'moi',
            stylistName: 'Karim Diop',
            revenueFcfa: 2104000,
            commissionFcfa: 322000,
            serviceCount: 10,
            commissionRate: 30,
          ),
        ),
        myPayoutsProvider.overrideWith(
          (ref) async => [
            payout(
              amount: 400000,
              status: PayoutStatus.paid,
              paidAt: lastMonth,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(myMonthCommissionProvider.future);
    await container.read(myPayoutsProvider.future);

    final balance = container.read(payoutBalanceProvider);
    expect(balance.paid, 0);
    expect(balance.available, 322000);
  });

  test('une avance supérieure à la commission ne rend pas le solde négatif',
      () async {
    final container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => profile),
        myMonthCommissionProvider.overrideWith(
          (ref) async => const StylistCommission(
            stylistId: 'moi',
            stylistName: 'Karim Diop',
            revenueFcfa: 300000,
            commissionFcfa: 90000,
            serviceCount: 2,
            commissionRate: 30,
          ),
        ),
        myPayoutsProvider.overrideWith(
          (ref) async => [
            payout(
              amount: 200000,
              status: PayoutStatus.paid,
              paidAt: DateTime(now.year, now.month, 2),
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(myMonthCommissionProvider.future);
    await container.read(myPayoutsProvider.future);

    expect(container.read(payoutBalanceProvider).available, 0);
  });

  test('sans données chargées, rien n\'est réclamable', () {
    expect(balanceWith(earned: 322000, payouts: const []).available, 0);
  });
}
