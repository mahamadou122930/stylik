import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/settings_repository.dart';
import '../domain/salon.dart';
import '../domain/subscription.dart';

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
