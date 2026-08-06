import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/catalog_repository.dart';
import '../domain/salon_service.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(supabaseClientProvider)),
);

/// Prestations actives du salon (forfaits inclus).
final servicesProvider = FutureProvider<List<SalonService>>((ref) async {
  final salonId = ref.watch(currentSalonIdProvider);
  if (salonId == null) return const [];
  return ref.watch(catalogRepositoryProvider).fetchAll(salonId: salonId);
});

/// Prestations simples, hors forfaits.
final simpleServicesProvider = Provider<List<SalonService>>((ref) {
  final services = ref.watch(servicesProvider).valueOrNull ?? const [];
  return services.where((service) => !service.isPackage).toList();
});

/// Forfaits du salon.
final packagesProvider = Provider<List<SalonService>>((ref) {
  final services = ref.watch(servicesProvider).valueOrNull ?? const [];
  return services.where((service) => service.isPackage).toList();
});

/// Catégories présentes dans le catalogue, précédées de « Toutes ».
final serviceCategoriesProvider = Provider<List<String>>((ref) {
  final categories = <String>{
    for (final service in ref.watch(simpleServicesProvider)) service.category,
  }.toList()
    ..sort();
  return ['Toutes', ...categories];
});

/// Catégorie sélectionnée dans la liste des services (0 = toutes).
final selectedCategoryIndexProvider = StateProvider<int>((ref) => 0);

/// Prestations groupées par catégorie, filtrées par la puce sélectionnée.
final servicesByCategoryProvider =
    Provider<Map<String, List<SalonService>>>((ref) {
  final services = ref.watch(simpleServicesProvider);
  final categories = ref.watch(serviceCategoriesProvider);
  final index = ref.watch(selectedCategoryIndexProvider);
  final filter = index > 0 && index < categories.length ? categories[index] : null;

  final grouped = <String, List<SalonService>>{};
  for (final service in services) {
    if (filter != null && service.category != filter) continue;
    grouped.putIfAbsent(service.category, () => []).add(service);
  }
  return grouped;
});

/// Prestations incluses dans un forfait, résolues par identifiant.
final packageContentProvider =
    Provider.family<List<SalonService>, SalonService>((ref, package) {
  final services = ref.watch(servicesProvider).valueOrNull ?? const [];
  return [
    for (final id in package.includedServiceIds)
      ...services.where((service) => service.id == id),
  ];
});
