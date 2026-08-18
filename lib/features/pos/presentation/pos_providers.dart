import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/domain/salon_service.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../data/pos_repository.dart';
import '../domain/payment_method.dart';
import '../domain/ticket.dart';

import '../../../core/services/local_db_service.dart';

final posRepositoryProvider = Provider<PosRepository>(
  (ref) => PosRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(localDbServiceProvider),
  ),
);

/// Ticket en cours de composition en caisse.
class TicketNotifier extends StateNotifier<Ticket> {
  TicketNotifier() : super(const Ticket());

  void addService(
    SalonService service, {
    String? stylistId,
    String? stylistName,
  }) {
    final existing = state.lines.indexWhere((line) => line.refId == service.id);

    if (existing >= 0) {
      final lines = [...state.lines];
      lines[existing] = lines[existing].copyWith(
        quantity: lines[existing].quantity + 1,
      );
      state = state.copyWith(lines: lines);
      return;
    }

    state = state.copyWith(
      lines: [
        ...state.lines,
        TicketLine(
          refId: service.id,
          label: service.name,
          unitPriceFcfa: service.priceFcfa,
          category: service.category,
          stylistId: stylistId,
          stylistName: stylistName,
        ),
      ],
    );
  }

  void updateLineStylist(
    String refId, {
    String? stylistId,
    String? stylistName,
  }) {
    state = state.copyWith(
      lines: [
        for (final line in state.lines)
          line.refId == refId
              ? line.copyWith(stylistId: stylistId, stylistName: stylistName)
              : line,
      ],
    );
  }

  void addProduct(Product product) {
    final existing = state.lines.indexWhere((line) => line.refId == product.id);

    if (existing >= 0) {
      final lines = [...state.lines];
      lines[existing] = lines[existing].copyWith(
        quantity: lines[existing].quantity + 1,
      );
      state = state.copyWith(lines: lines);
      return;
    }

    state = state.copyWith(
      lines: [
        ...state.lines,
        TicketLine(
          refId: product.id,
          label: product.name,
          unitPriceFcfa: product.unitSalePriceFcfa,
          category: product.brand,
          isProduct: true,
        ),
      ],
    );
  }

  void removeLine(String refId) {
    state = state.copyWith(
      lines: state.lines.where((line) => line.refId != refId).toList(),
    );
  }

  void setQuantity(String refId, int quantity) {
    if (quantity <= 0) return removeLine(refId);
    state = state.copyWith(
      lines: [
        for (final line in state.lines)
          line.refId == refId ? line.copyWith(quantity: quantity) : line,
      ],
    );
  }

  /// Applique — ou retire, avec 0 — la remise fidélité.
  void setDiscountPercent(int percent) =>
      state = state.copyWith(discountPercent: percent.clamp(0, 100));

  void attachClient({
    required String clientId,
    String? clientName,
    String? stylistName,
    String? timeLabel,
    int discountPercent = 0,
  }) => state = state.copyWith(
    clientId: clientId,
    clientName: clientName,
    stylistName: stylistName,
    timeLabel: timeLabel,
    // La remise suit la cliente : changer de fiche en cours de ticket doit
    // remplacer le taux, pas garder celui de la précédente.
    discountPercent: discountPercent,
  );

  void attachAppointment(String appointmentId) =>
      state = state.copyWith(appointmentId: appointmentId);

  void clear() => state = const Ticket();

  /// Recharge en caisse un ticket mis en attente, pour le solder ou le
  /// compléter.
  void restore(SalonTransaction transaction) {
    // Le ticket ne stocke qu'un taux : on le retrouve depuis le montant figé
    // à la mise en attente, pour que la remise reste celle accordée ce jour-là
    // même si des lignes sont ajoutées ensuite.
    final subtotal = transaction.subtotalFcfa;
    final percent = subtotal <= 0
        ? 0
        : (transaction.discountFcfa * 100 / subtotal).round();

    state = Ticket(
      lines: transaction.lines,
      discountPercent: percent,
      clientId: transaction.clientId,
      appointmentId: transaction.appointmentId,
      clientName: transaction.clientName,
    );
  }
}

final ticketProvider = StateNotifierProvider<TicketNotifier, Ticket>(
  (ref) => TicketNotifier(),
);

/// Moyen de paiement sélectionné à l'écran 6.2.
final selectedPaymentProvider = StateProvider<PaymentMethod>(
  (ref) => PaymentMethod.cash,
);

/// Dernière transaction encaissée, affichée sur le ticket (6.3).
final lastTransactionProvider = StateProvider<SalonTransaction?>((ref) => null);

/// Avertissement du dernier mouvement de stock, `null` si tout s'est écrit.
///
/// La vente ne doit pas échouer parce que le stock n'a pas pu bouger — un
/// encaissement perdu se rattrape moins bien qu'un stock à recorriger — mais
/// l'écart ne doit pas non plus passer sous silence.
final stockWarningProvider = StateProvider<String?>((ref) => null);

/// Identifiant du ticket en attente rechargé en caisse, `null` pour une vente
/// neuve.
///
/// Le règlement réutilise cet identifiant : l'`upsert` transforme alors le
/// brouillon en ticket payé au lieu d'en créer un second, ce qui compterait le
/// chiffre d'affaires deux fois.
final resumedTicketIdProvider = StateProvider<String?>((ref) => null);

/// Encaisse le ticket courant et retourne la transaction créée.
final checkoutControllerProvider = Provider<Future<SalonTransaction?> Function()>((
  ref,
) {
  return () async {
    final salonId = ref.read(currentSalonIdProvider);
    final ticket = ref.read(ticketProvider);
    if (salonId == null || ticket.isEmpty) return null;

    final resumedId = ref.read(resumedTicketIdProvider);

    final transaction = await ref
        .read(posRepositoryProvider)
        .checkout(
          salonId: salonId,
          ticket: ticket,
          paymentMethod: ref.read(selectedPaymentProvider),
          // `transactions.cashier_id` référence `profiles(id)`, pas
          // `auth.users(id)` : transmettre l'identifiant de session violait la
          // clé étrangère et faisait échouer tout l'encaissement.
          cashierId: ref.read(currentProfileProvider).valueOrNull?.id,
          customTransactionId: resumedId,
        );

    // Une vente de produit sort du stock : sans ce mouvement, l'inventaire
    // restait au chiffre de la dernière réception et les alertes de seuil ne
    // se déclenchaient jamais.
    //
    // Le mouvement a lieu au règlement, y compris pour un ticket qui a
    // patienté : un brouillon peut encore être annulé, et le déduire à la mise
    // en attente obligerait à le remettre en rayon derrière.
    await _moveStock(
      ref,
      quantities: ticket.lines.productQuantities,
      restock: false,
      contextLabel: 'Vente ${Formatters.dayMonth(DateTime.now())}',
    );

    ref.read(lastTransactionProvider.notifier).state = transaction;
    ref.read(ticketProvider.notifier).clear();
    ref.read(resumedTicketIdProvider.notifier).state = null;
    ref.invalidate(todayTransactionsProvider);
    ref.invalidate(pendingTicketsProvider);
    return transaction;
  };
});

/// Tickets en attente de règlement, toutes dates confondues.
final pendingTicketsProvider = FutureProvider<List<SalonTransaction>>((
  ref,
) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(posRepositoryProvider).fetchPending(salonId: salonId);
});

/// Montant total laissé en attente.
final pendingTicketsTotalProvider = Provider<int>((ref) {
  final tickets = ref.watch(pendingTicketsProvider).valueOrNull ?? const [];
  return tickets.fold(0, (sum, ticket) => sum + ticket.totalAmountFcfa);
});

/// Met le ticket courant de côté, sans encaisser.
///
/// La prestation est faite, l'argent pas encore là : le ticket est écrit au
/// statut brouillon pour qu'on le retrouve, et la caisse se libère pour la
/// cliente suivante.
final holdTicketControllerProvider =
    Provider<Future<SalonTransaction?> Function()>((ref) {
      return () async {
        final salonId = ref.read(currentSalonIdProvider);
        final ticket = ref.read(ticketProvider);
        if (salonId == null || ticket.isEmpty) return null;

        final transaction = await ref
            .read(posRepositoryProvider)
            .checkout(
              salonId: salonId,
              ticket: ticket,
              paymentMethod: ref.read(selectedPaymentProvider),
              cashierId: ref.read(currentProfileProvider).valueOrNull?.id,
              // Remettre en attente un ticket déjà en attente le met à jour
              // plutôt que d'en créer un doublon.
              customTransactionId: ref.read(resumedTicketIdProvider),
              status: TransactionStatus.draft,
            );

        ref.read(ticketProvider.notifier).clear();
        ref.read(resumedTicketIdProvider.notifier).state = null;
        ref.invalidate(pendingTicketsProvider);
        ref.invalidate(todayTransactionsProvider);
        return transaction;
      };
    });

/// Recharge un ticket en attente en caisse pour le solder ou le compléter.
final resumeTicketControllerProvider =
    Provider<void Function(SalonTransaction)>((ref) {
      return (transaction) {
        ref.read(ticketProvider.notifier).restore(transaction);
        ref.read(resumedTicketIdProvider.notifier).state = transaction.id;
      };
    });

/// Abandonne un ticket en attente : la cliente ne réglera pas.
///
/// Le ticket passe en annulé plutôt que d'être supprimé — il ne compte plus
/// nulle part, mais la trace reste pour comprendre un écart de caisse.
final cancelPendingControllerProvider =
    Provider<Future<void> Function(SalonTransaction)>((ref) {
      return (transaction) async {
        await ref.read(posRepositoryProvider).voidTransaction(transaction.id);

        if (ref.read(resumedTicketIdProvider) == transaction.id) {
          ref.read(ticketProvider.notifier).clear();
          ref.read(resumedTicketIdProvider.notifier).state = null;
        }

        ref.invalidate(pendingTicketsProvider);
        ref.invalidate(todayTransactionsProvider);
      };
    });

/// Rembourse un ticket et remet ses produits en stock.
final refundControllerProvider =
    Provider<Future<void> Function(SalonTransaction, int, RefundReason)>((ref) {
      return (transaction, amountFcfa, reason) async {
        await ref
            .read(posRepositoryProvider)
            .refund(
              transactionId: transaction.id,
              amountFcfa: amountFcfa,
              reason: reason,
            );

        // Le produit rendu retourne en rayon. Un remboursement partiel ne dit pas
        // quelles lignes sont concernées : on ne restocke qu'au remboursement
        // intégral, plutôt que de rendre un article peut-être conservé.
        if (amountFcfa >= transaction.totalAmountFcfa) {
          await _moveStock(
            ref,
            quantities: transaction.lines.productQuantities,
            restock: true,
            contextLabel: 'Remboursement · ${reason.label}',
          );
        }

        ref.invalidate(todayTransactionsProvider);
      };
    });

/// Applique le mouvement et rafraîchit l'inventaire, en consignant l'échec
/// éventuel au lieu de le faire remonter : le ticket, lui, est bien écrit.
Future<void> _moveStock(
  Ref ref, {
  required Map<String, int> quantities,
  required bool restock,
  String? contextLabel,
}) async {
  ref.read(stockWarningProvider.notifier).state = null;
  if (quantities.isEmpty) return;

  final inventory = ref.read(inventoryRepositoryProvider);
  try {
    if (restock) {
      await inventory.restockRefunded(
        quantitiesByProductId: quantities,
        contextLabel: contextLabel,
      );
    } else {
      await inventory.releaseSold(
        quantitiesByProductId: quantities,
        contextLabel: contextLabel,
      );
    }
  } catch (error) {
    ref.read(stockWarningProvider.notifier).state =
        'Stock non mis à jour : $error';
  }

  ref.invalidate(productsProvider);
}

/// Tickets encaissés aujourd'hui (journal de caisse).
final todayTransactionsProvider = FutureProvider<List<SalonTransaction>>((
  ref,
) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];
  return ref
      .watch(posRepositoryProvider)
      .fetchDay(salonId: salonId, day: DateTime.now());
});

/// Total encaissé aujourd'hui (ventes − remboursements).
final todayCashTotalProvider = Provider<int>((ref) {
  final transactions =
      ref.watch(todayTransactionsProvider).valueOrNull ?? const [];
  return transactions
      // Le total de caisse est ce qu'il y a dans le tiroir : un ticket en
      // attente ou annulé n'y a rien mis.
      .where(
        (transaction) =>
            transaction.status == TransactionStatus.paid ||
            transaction.status == TransactionStatus.refunded,
      )
      .fold(0, (sum, transaction) => sum + transaction.signedAmountFcfa);
});
