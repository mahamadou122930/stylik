import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/features/pos/domain/payment_method.dart';
import 'package:stylik/features/pos/domain/ticket.dart';

/// Remboursements partiels.
///
/// Le montant rendu n'était stocké nulle part : l'écran de remboursement
/// proposait un montant partiel, mais la base ne retenait que `refunded`. Un
/// remboursement de 1 000 F sur un ticket de 5 000 F annulait donc le ticket
/// entier — le chiffre d'affaires perdait 5 000 F, et le coiffeur toute sa
/// commission.
void main() {
  SalonTransaction ticket({
    required int total,
    int refunded = 0,
    TransactionStatus status = TransactionStatus.paid,
  }) => SalonTransaction(
    id: 't1',
    salonId: 'salon',
    subtotalFcfa: total,
    discountFcfa: 0,
    totalAmountFcfa: total,
    refundedAmountFcfa: refunded,
    paymentMethod: PaymentMethod.cash,
    status: status,
  );

  group('encaissement net', () {
    test('vendre 5 000 F et en rendre 1 000 en laisse 4 000', () {
      // Le cas signalé : le ticket reste payé, seule la part rendue sort.
      expect(ticket(total: 5000, refunded: 1000).cashImpactFcfa, 4000);
    });

    test('sans remboursement, le ticket vaut son montant', () {
      expect(ticket(total: 5000).cashImpactFcfa, 5000);
    });

    test('un remboursement intégral ne laisse rien', () {
      expect(
        ticket(
          total: 5000,
          refunded: 5000,
          status: TransactionStatus.refunded,
        ).cashImpactFcfa,
        0,
      );
    });

    test('un remboursement ne peut pas rendre le ticket négatif', () {
      // Garde-fou : une donnée incohérente ne doit pas creuser la caisse.
      expect(ticket(total: 5000, refunded: 9000).cashImpactFcfa, 0);
    });
  });

  group('part conservée, pour la commission', () {
    test('rendre un cinquième laisse quatre cinquièmes au coiffeur', () {
      expect(ticket(total: 5000, refunded: 1000).keptRatio, closeTo(0.8, 1e-9));
    });

    test('un ticket intact laisse tout', () {
      expect(ticket(total: 5000).keptRatio, 1.0);
    });

    test('un ticket remboursé ne laisse rien', () {
      expect(
        ticket(
          total: 5000,
          refunded: 5000,
          status: TransactionStatus.refunded,
        ).keptRatio,
        0.0,
      );
    });

    test('un ticket en attente ne donne pas de commission', () {
      // La prestation n'est pas réglée : rien n'est dû tant qu'elle ne l'est
      // pas.
      expect(ticket(total: 5000, status: TransactionStatus.draft).keptRatio, 0);
    });

    test('un ticket à zéro ne divise pas par zéro', () {
      expect(ticket(total: 0).keptRatio, 0);
    });
  });

  group('reconnaissance du remboursement partiel', () {
    test('un ticket partiellement rendu reste payé', () {
      final row = ticket(total: 5000, refunded: 1000);
      expect(row.isPartiallyRefunded, isTrue);
      // Il n'est PAS « remboursé » : la vente tient pour les 4 000 F restants.
      expect(row.isRefund, isFalse);
    });

    test('un ticket intégralement rendu bascule de statut', () {
      final row = ticket(
        total: 5000,
        refunded: 5000,
        status: TransactionStatus.refunded,
      );
      expect(row.isRefund, isTrue);
      expect(row.isPartiallyRefunded, isFalse);
    });
  });

  group('lecture depuis la base', () {
    test('la somme rendue est relue', () {
      final row = SalonTransaction.fromMap({
        'id': 't1',
        'salon_id': 'salon',
        'total_amount_fcfa': 5000,
        'refunded_amount_fcfa': 1000,
        'status': 'paid',
      });

      expect(row.refundedAmountFcfa, 1000);
      expect(row.cashImpactFcfa, 4000);
    });

    test('une base sans la colonne se lit comme non remboursée', () {
      // Avant la migration, la colonne est absente : le ticket vaut son
      // montant plein plutôt que zéro.
      final row = SalonTransaction.fromMap({
        'id': 't1',
        'salon_id': 'salon',
        'total_amount_fcfa': 5000,
        'status': 'paid',
      });

      expect(row.refundedAmountFcfa, 0);
      expect(row.cashImpactFcfa, 5000);
    });
  });
}
