import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/features/inventory/domain/product.dart';
import 'package:stylik/features/pos/domain/payment_method.dart';
import 'package:stylik/features/pos/domain/ticket.dart';
import 'package:stylik/features/pos/presentation/pos_providers.dart';

/// Tickets mis en attente : la prestation est faite, l'argent pas encore là.
/// Tant qu'un ticket patiente, il ne doit peser ni sur la caisse du jour ni
/// sur le résultat — mais il ne doit pas non plus disparaître.
void main() {
  SalonTransaction ticket({
    required String id,
    required int amount,
    required TransactionStatus status,
    List<TicketLine> lines = const [],
  }) => SalonTransaction(
    id: id,
    salonId: 'salon',
    subtotalFcfa: amount,
    discountFcfa: 0,
    totalAmountFcfa: amount,
    paymentMethod: PaymentMethod.cash,
    status: status,
    lines: lines,
  );

  group('total de caisse', () {
    ProviderContainer withTransactions(List<SalonTransaction> transactions) {
      final c = ProviderContainer(
        overrides: [
          todayTransactionsProvider.overrideWith((ref) async => transactions),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('un ticket en attente n\'entre pas dans la caisse du jour', () async {
      final c = withTransactions([
        ticket(id: 'a', amount: 10000, status: TransactionStatus.paid),
        ticket(id: 'b', amount: 8000, status: TransactionStatus.draft),
      ]);
      await c.read(todayTransactionsProvider.future);

      // Le total de caisse est ce qu'il y a dans le tiroir : l'ardoise n'y a
      // rien mis.
      expect(c.read(todayCashTotalProvider), 10000);
    });

    test('un ticket annulé n\'y entre pas non plus', () async {
      final c = withTransactions([
        ticket(id: 'a', amount: 10000, status: TransactionStatus.paid),
        ticket(id: 'b', amount: 5000, status: TransactionStatus.cancelled),
      ]);
      await c.read(todayTransactionsProvider.future);

      expect(c.read(todayCashTotalProvider), 10000);
    });

    test('un remboursement se soustrait', () async {
      final c = withTransactions([
        ticket(id: 'a', amount: 10000, status: TransactionStatus.paid),
        ticket(id: 'b', amount: 3000, status: TransactionStatus.refunded),
      ]);
      await c.read(todayTransactionsProvider.future);

      expect(c.read(todayCashTotalProvider), 7000);
    });
  });

  group('reste à encaisser', () {
    test('les ardoises ouvertes se totalisent', () async {
      final c = ProviderContainer(
        overrides: [
          pendingTicketsProvider.overrideWith(
            (ref) async => [
              ticket(id: 'a', amount: 8000, status: TransactionStatus.draft),
              ticket(id: 'b', amount: 12000, status: TransactionStatus.draft),
            ],
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(pendingTicketsProvider.future);

      expect(c.read(pendingTicketsTotalProvider), 20000);
    });

    test('sans ardoise, le reste à encaisser est nul', () async {
      final c = ProviderContainer(
        overrides: [pendingTicketsProvider.overrideWith((ref) async => [])],
      );
      addTearDown(c.dispose);
      await c.read(pendingTicketsProvider.future);

      expect(c.read(pendingTicketsTotalProvider), 0);
    });
  });

  group('reprise en caisse', () {
    test('un ticket en attente se recharge avec ses lignes', () {
      final notifier = TicketNotifier();
      notifier.restore(
        ticket(
          id: 'a',
          amount: 9000,
          status: TransactionStatus.draft,
          lines: const [
            TicketLine(refId: 's1', label: 'Coupe', unitPriceFcfa: 4000),
            TicketLine(
              refId: 'p1',
              label: 'Huile',
              unitPriceFcfa: 5000,
              isProduct: true,
            ),
          ],
        ),
      );

      expect(notifier.state.lines.length, 2);
      expect(notifier.state.totalFcfa, 9000);
      expect(notifier.state.productLines.length, 1);
    });

    test('reprendre un ticket écrase le ticket courant', () {
      final notifier = TicketNotifier();
      // Un article déjà en caisse ne doit pas se mélanger à l'ardoise
      // reprise : les deux tickets appartiennent à des clientes différentes.
      notifier.addProduct(
        const Product(
          id: 'autre',
          salonId: 'salon',
          name: 'Masque',
          brand: 'Maison',
          category: 'Soin',
          stockQuantity: 5,
          alertThreshold: 1,
          unitSalePriceFcfa: 2500,
        ),
      );
      notifier.restore(
        ticket(
          id: 'a',
          amount: 4000,
          status: TransactionStatus.draft,
          lines: const [
            TicketLine(refId: 's1', label: 'Coupe', unitPriceFcfa: 4000),
          ],
        ),
      );

      expect(notifier.state.lines.length, 1);
      expect(notifier.state.lines.single.refId, 's1');
    });
  });
}
