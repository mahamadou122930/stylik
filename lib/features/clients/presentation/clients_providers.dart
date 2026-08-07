import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/clients_repository.dart';
import '../domain/client.dart';

import '../../../core/services/local_db_service.dart';

final clientsRepositoryProvider = Provider<ClientsRepository>(
  (ref) => ClientsRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(storageServiceProvider),
    ref.watch(localDbServiceProvider),
  ),
);

/// Terme de recherche du CRM.
final clientSearchProvider = StateProvider<String>((ref) => '');

/// Liste des clients du salon, filtrée par la recherche.
final clientsListProvider = FutureProvider<List<Client>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];

  return ref.watch(clientsRepositoryProvider).fetchAll(
        salonId: salonId,
        search: ref.watch(clientSearchProvider),
      );
});

/// Clients regroupés par initiale, pour l'index alphabétique.
final clientsByLetterProvider = Provider<Map<String, List<Client>>>((ref) {
  final clients = ref.watch(clientsListProvider).valueOrNull ?? const [];

  final grouped = <String, List<Client>>{};
  for (final client in clients) {
    final letter = client.fullName.trim().isEmpty
        ? '#'
        : client.fullName.trim()[0].toUpperCase();
    grouped.putIfAbsent(letter, () => []).add(client);
  }

  return Map.fromEntries(
    grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
});

/// Fiche client détaillée.
final clientDetailProvider =
    FutureProvider.family<Client?, String>((ref, clientId) {
  return ref.watch(clientsRepositoryProvider).fetchById(clientId);
});

/// Historique des passages d'un client.
final clientHistoryProvider =
    FutureProvider.family<List<ClientVisit>, String>((ref, clientId) {
  return ref.watch(clientsRepositoryProvider).fetchHistory(clientId);
});
