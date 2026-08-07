import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/settings_repository.dart';
import '../domain/salon.dart';
import '../domain/subscription.dart';
import '../domain/subscription_plan.dart';

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
final subscriptionPlansProvider =
    FutureProvider<List<SubscriptionPlan>>((ref) async {
  return ref.watch(settingsRepositoryProvider).fetchPlans();
});

/// Périodicité choisie dans la bascule « Mensuel / Annuel », partagée entre
/// l'écran de choix du plan et l'écran de comparaison et paiement.
final billingCycleProvider = StateProvider<BillingCycle>(
  (ref) => BillingCycle.monthly,
);
