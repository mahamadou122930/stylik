import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../clients/presentation/clients_providers.dart';
import '../../finance/presentation/finance_providers.dart';
import '../data/settings_repository.dart';
import '../domain/salon.dart';
import '../domain/subscription.dart';
import '../domain/subscription_plan.dart';
import '../domain/subscription_request.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(storageServiceProvider),
  ),
);

/// Salon du membre connecté.
final currentSalonProvider = FutureProvider<Salon?>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return null;
  return ref.watch(settingsRepositoryProvider).fetchSalon(salonId);
});

/// Abonnement SaaS du salon.
final subscriptionProvider = FutureProvider<Subscription?>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return null;
  return ref.watch(settingsRepositoryProvider).fetchSubscription(salonId);
});

/// Catalogue des formules proposées (écran « Choisir un abonnement »).
final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlan>>((
  ref,
) async {
  return ref.watch(settingsRepositoryProvider).fetchPlans();
});

/// Périodicité choisie dans la bascule « Mensuel / Annuel », partagée entre
/// l'écran de choix du plan et l'écran de comparaison et paiement.
final billingCycleProvider = StateProvider<BillingCycle>(
  (ref) => BillingCycle.monthly,
);

/// Ce que le salon a réellement fait pendant son essai.
///
/// L'écran « Votre essai est terminé » lisait `dayAppointmentsProvider` et
/// `financeSummaryProvider` : les RDV de la **journée** sélectionnée et le CA
/// de la **période Finance courante**, qui part sur le jour. Sous un titre
/// « Pendant l'essai », un gérant dont l'essai venait d'expirer lisait donc
/// « 0 RDV · 0 F » — l'argument exactement inverse de celui que l'écran porte.
///
/// La fenêtre va du début de l'essai à maintenant, et les trois chiffres la
/// couvrent tous les trois.
typedef TrialRecap = ({
  DateTime from,
  DateTime to,
  int ticketCount,
  int clientCount,
  int revenueFcfa,
});

final trialRecapProvider = FutureProvider<TrialRecap?>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  final subscription = await ref.watch(subscriptionProvider.future);

  final from = subscription?.trialStartedAt;
  if (salonId == null || from == null) return null;

  // L'essai s'arrête à son échéance ; avant elle, le récapitulatif s'arrête
  // à l'instant présent plutôt que de compter des journées à venir.
  final now = DateTime.now();
  final to = subscription!.isExpired ? subscription.nextChargeAt! : now;
  if (!to.isAfter(from)) return null;

  final summary = await ref
      .watch(financeRepositoryProvider)
      .fetchSummary(salonId: salonId, from: from, to: to);

  final clients = await ref.watch(clientsListProvider.future);
  final newClients = clients.where((c) {
    final created = c.createdAt;
    return created != null && !created.isBefore(from) && created.isBefore(to);
  }).length;

  return (
    from: from,
    to: to,
    ticketCount: summary.ticketCount,
    clientCount: newClients,
    revenueFcfa: summary.revenueFcfa,
  );
});

/// Demande d'activation en attente de paiement, s'il y en a une.
///
/// Elle reste visible tant que l'opérateur ne l'a pas honorée : le gérant
/// qui revient sur l'écran d'abonnement retrouve sa référence et le numéro
/// où payer, au lieu de redéposer une demande.
final pendingSubscriptionRequestProvider = FutureProvider<SubscriptionRequest?>(
  (ref) async {
    final salonId = ref.watch(currentSalonIdProvider);
    if (salonId == null) return null;
    return ref.watch(settingsRepositoryProvider).fetchPendingRequest(salonId);
  },
);

/// Comptes sur lesquels envoyer le paiement.
final paymentAccountsProvider = FutureProvider<List<PaymentAccount>>(
  (ref) => ref.watch(settingsRepositoryProvider).fetchPaymentAccounts(),
);
