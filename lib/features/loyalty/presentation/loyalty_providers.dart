import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../clients/domain/client.dart';
import '../data/loyalty_repository.dart';
import '../domain/loyalty_campaign.dart';

final loyaltyRepositoryProvider = Provider<LoyaltyRepository>(
  (ref) => LoyaltyRepository(ref.watch(supabaseClientProvider)),
);

/// Règle de fidélité active (paramétrable ultérieurement en base).
final loyaltyRuleProvider = Provider<LoyaltyRule>((ref) => const LoyaltyRule());

/// Clients les plus fidèles du salon.
final topClientsProvider = FutureProvider<List<Client>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(loyaltyRepositoryProvider).fetchTopClients(salonId: salonId);
});

/// Récompenses proposées par le salon.
final rewardsProvider = FutureProvider<List<LoyaltyReward>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(loyaltyRepositoryProvider).fetchRewards(salonId);
});

/// Client dont la carte de fidélité est affichée (null = meilleur client).
final loyaltyClientProvider = StateProvider<Client?>((ref) => null);

/// Carte de fidélité affichée en haut de l'écran 9.1.
final loyaltyCardClientProvider = Provider<Client?>((ref) {
  final selected = ref.watch(loyaltyClientProvider);
  if (selected != null) return selected;
  final top = ref.watch(topClientsProvider).valueOrNull;
  return (top == null || top.isEmpty) ? null : top.first;
});

/// Promotions du salon.
final promotionsProvider = FutureProvider<List<Promotion>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(loyaltyRepositoryProvider).fetchPromotions(salonId);
});

/// Rappels automatiques configurés.
final reminderRulesProvider = FutureProvider<List<ReminderRule>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(loyaltyRepositoryProvider).fetchReminderRules(salonId);
});

/// Volume d'envois et taux de présence du mois.
final reminderStatsProvider = FutureProvider<ReminderStats>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return ReminderStats.empty;
  return ref.watch(loyaltyRepositoryProvider).fetchReminderStats(salonId);
});

/// Segment ciblé par la campagne en cours de préparation.
final campaignTagsProvider = StateProvider<List<String>>((ref) => const []);

final campaignAudienceProvider = FutureProvider<List<Client>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(loyaltyRepositoryProvider).fetchSegment(
        salonId: salonId,
        tags: ref.watch(campaignTagsProvider),
      );
});
