import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/features/home/presentation/home_providers.dart';
import 'package:stylik/features/pos/domain/payment_method.dart';
import 'package:stylik/features/pos/domain/ticket.dart';
import 'package:stylik/features/pos/presentation/pos_providers.dart';

/// Les chiffres de l'accueil (maquette § 1) sont dérivés des tickets : ce sont
/// ces calculs, et non la mise en page, qui peuvent mentir au gérant.
void main() {
  SalonTransaction ticket(
    DateTime at,
    int amount, {
    TransactionStatus status = TransactionStatus.paid,
  }) => SalonTransaction(
    id: 'tx-${at.microsecondsSinceEpoch}-$amount',
    salonId: 'salon',
    subtotalFcfa: amount,
    discountFcfa: 0,
    totalAmountFcfa: amount,
    paymentMethod: PaymentMethod.cash,
    status: status,
    createdAt: at,
  );

  ProviderContainer containerWith(List<SalonTransaction> all) {
    final today = DateTime.now();
    final container = ProviderContainer(
      overrides: [
        twoWeekTransactionsProvider.overrideWith((ref) async => all),
        todayTransactionsProvider.overrideWith(
          (ref) async => all.where((t) {
            final at = t.createdAt!;
            return at.year == today.year &&
                at.month == today.month &&
                at.day == today.day;
          }).toList(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('la semaine commence le lundi', () {
    // 2026-08-13 est un jeudi ; le lundi de cette semaine est le 10.
    expect(startOfWeek(DateTime(2026, 8, 13)), DateTime(2026, 8, 10));
    // Un lundi est son propre début de semaine.
    expect(startOfWeek(DateTime(2026, 8, 10)), DateTime(2026, 8, 10));
    // Un dimanche appartient à la semaine qui vient de s'écouler.
    expect(startOfWeek(DateTime(2026, 8, 16)), DateTime(2026, 8, 10));
  });

  test('les barres de la semaine tombent sur le bon jour', () async {
    final monday = startOfWeek(DateTime.now()).add(const Duration(hours: 10));
    final wednesday = monday.add(const Duration(days: 2));

    final container = containerWith([
      ticket(monday, 30000),
      ticket(monday, 12000),
      ticket(wednesday, 8000),
    ]);
    await container.read(twoWeekTransactionsProvider.future);

    final week = container.read(weekRevenueProvider);
    expect(week, hasLength(7));
    expect(week[0].totalFcfa, 42000);
    expect(week[1].totalFcfa, 0);
    expect(week[2].totalFcfa, 8000);
  });

  test('un remboursement se déduit du jour', () async {
    final monday = startOfWeek(DateTime.now()).add(const Duration(hours: 10));

    final container = containerWith([
      ticket(monday, 30000),
      ticket(monday, 5000, status: TransactionStatus.refunded),
    ]);
    await container.read(twoWeekTransactionsProvider.future);

    expect(container.read(weekRevenueProvider)[0].totalFcfa, 25000);
  });

  test('la tendance compare au même jour la semaine passée', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 10);
    final lastWeek = today.subtract(const Duration(days: 7));

    final container = containerWith([
      ticket(today, 12000),
      ticket(lastWeek, 10000),
    ]);
    await container.read(twoWeekTransactionsProvider.future);
    await container.read(todayTransactionsProvider.future);

    expect(container.read(revenueTrendProvider), closeTo(0.2, 0.0001));
  });

  test(
    'sans repère la semaine passée, aucune tendance n\'est affichée',
    () async {
      final now = DateTime.now();
      final container = containerWith([
        ticket(DateTime(now.year, now.month, now.day, 10), 12000),
      ]);
      await container.read(twoWeekTransactionsProvider.future);
      await container.read(todayTransactionsProvider.future);

      expect(container.read(revenueTrendProvider), isNull);
    },
  );

  test('le panier moyen ne compte que les ventes au dénominateur', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 10);

    final container = containerWith([
      ticket(today, 30000),
      ticket(today, 10000),
      ticket(today, 4000, status: TransactionStatus.refunded),
    ]);
    await container.read(twoWeekTransactionsProvider.future);
    await container.read(todayTransactionsProvider.future);

    final basket = container.read(averageTicketProvider);
    expect(basket.saleCount, 2);
    // (30 000 + 10 000 − 4 000) / 2
    expect(basket.valueFcfa, 18000);
  });

  test('sans vente, le panier moyen reste vide plutôt qu\'à zéro', () async {
    final container = containerWith([]);
    await container.read(twoWeekTransactionsProvider.future);
    await container.read(todayTransactionsProvider.future);

    expect(container.read(averageTicketProvider).saleCount, 0);
  });
}
