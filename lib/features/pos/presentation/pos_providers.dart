import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/domain/salon_service.dart';
import '../../inventory/domain/product.dart';
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

  void addService(SalonService service, {String? stylistId, String? stylistName}) {
    final existing = state.lines.indexWhere((line) => line.refId == service.id);

    if (existing >= 0) {
      final lines = [...state.lines];
      lines[existing] =
          lines[existing].copyWith(quantity: lines[existing].quantity + 1);
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

  void updateLineStylist(String refId, {String? stylistId, String? stylistName}) {
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
      lines[existing] =
          lines[existing].copyWith(quantity: lines[existing].quantity + 1);
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

  void setDiscount(int discountFcfa, {String? label}) => state =
      state.copyWith(discountFcfa: discountFcfa, discountLabel: label);

  void attachClient({
    required String clientId,
    String? clientName,
    String? stylistName,
    String? timeLabel,
  }) =>
      state = state.copyWith(
        clientId: clientId,
        clientName: clientName,
        stylistName: stylistName,
        timeLabel: timeLabel,
      );

  void attachAppointment(String appointmentId) =>
      state = state.copyWith(appointmentId: appointmentId);

  void clear() => state = const Ticket();
}

final ticketProvider =
    StateNotifierProvider<TicketNotifier, Ticket>((ref) => TicketNotifier());

/// Moyen de paiement sélectionné à l'écran 6.2.
final selectedPaymentProvider =
    StateProvider<PaymentMethod>((ref) => PaymentMethod.cash);

/// Dernière transaction encaissée, affichée sur le ticket (6.3).
final lastTransactionProvider = StateProvider<SalonTransaction?>((ref) => null);

/// Encaisse le ticket courant et retourne la transaction créée.
final checkoutControllerProvider =
    Provider<Future<SalonTransaction?> Function()>((ref) {
  return () async {
    final salonId = ref.read(currentSalonIdProvider);
    final ticket = ref.read(ticketProvider);
    if (salonId == null || ticket.isEmpty) return null;

    final transaction = await ref.read(posRepositoryProvider).checkout(
          salonId: salonId,
          ticket: ticket,
          paymentMethod: ref.read(selectedPaymentProvider),
          // `transactions.cashier_id` référence `profiles(id)`, pas
          // `auth.users(id)` : transmettre l'identifiant de session violait la
          // clé étrangère et faisait échouer tout l'encaissement.
          cashierId: ref.read(currentProfileProvider).valueOrNull?.id,
        );

    ref.read(lastTransactionProvider.notifier).state = transaction;
    ref.read(ticketProvider.notifier).clear();
    ref.invalidate(todayTransactionsProvider);
    return transaction;
  };
});

/// Tickets encaissés aujourd'hui (journal de caisse).
final todayTransactionsProvider =
    FutureProvider<List<SalonTransaction>>((ref) async {
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
  return transactions.fold(
    0,
    (sum, transaction) => sum + transaction.signedAmountFcfa,
  );
});
