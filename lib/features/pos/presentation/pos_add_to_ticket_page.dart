import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../staff/presentation/staff_providers.dart';
import 'pos_providers.dart';

/// Écran « Ajouter au ticket » identique à la maquette du prototype.
class PosAddToTicketPage extends ConsumerStatefulWidget {
  const PosAddToTicketPage({super.key});

  static const routeName = '/pos/add-to-ticket';

  @override
  ConsumerState<PosAddToTicketPage> createState() => _PosAddToTicketPageState();
}

class _PosAddToTicketPageState extends ConsumerState<PosAddToTicketPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(servicesProvider);
    final productsAsync = ref.watch(productsProvider);
    final ticket = ref.watch(ticketProvider);
    final currentProfile = ref.watch(currentProfileProvider).valueOrNull;
    final stylists = ref.watch(stylistsProvider).valueOrNull ?? const [];
    final defaultStylist = currentProfile ?? (stylists.isNotEmpty ? stylists.first : null);

    return AppScreen(
      title: 'Ajouter au ticket',
      footer: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1E1B),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Retour au ticket',
                style: AppTypography.sora(15, FontWeight.w700, color: Colors.white),
              ),
              Text(
                '${ticket.lines.length} article${ticket.lines.length > 1 ? 's' : ''} · ${Formatters.fcfa(ticket.totalFcfa)}',
                style: AppTypography.sora(14, FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Champ de recherche identique à la maquette
          AppInput(
            controller: _searchController,
            hint: 'Rechercher une prestation...',
            prefixIcon: Icons.search_rounded,
            suffix: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
          ),
          const SizedBox(height: 16),

          // En-tête de section "PRESTATIONS"
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              'PRESTATIONS',
              style: AppTypography.manrope(
                12.5,
                FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Carte regroupée des prestations et produits
          servicesAsync.when(
            loading: () => const AppLoader(),
            error: (err, _) => AppErrorState(message: '$err'),
            data: (services) {
              final products = productsAsync.valueOrNull ?? const [];
              final activeProducts = products.where((p) => !p.isOutOfStock).toList();

              final filteredServices = services.where((s) {
                if (_searchQuery.isEmpty) return true;
                return s.name.toLowerCase().contains(_searchQuery) ||
                    s.category.toLowerCase().contains(_searchQuery);
              }).toList();

              final filteredProducts = activeProducts.where((p) {
                if (_searchQuery.isEmpty) return true;
                return p.name.toLowerCase().contains(_searchQuery) ||
                    p.brand.toLowerCase().contains(_searchQuery);
              }).toList();

              if (filteredServices.isEmpty && filteredProducts.isEmpty) {
                return AppEmptyState(
                  title: 'Aucun résultat',
                  message: _searchQuery.isNotEmpty
                      ? 'Aucune prestation ni produit ne correspond à "$_searchQuery".'
                      : 'Aucune prestation disponible.',
                );
              }

              return AppCard(
                padding: EdgeInsets.zero,
                child: ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Prestations
                    for (int i = 0; i < filteredServices.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.border),
                      _ServiceRow(
                        serviceName: filteredServices[i].name,
                        subtitle: '${filteredServices[i].category} · ${Formatters.duration(filteredServices[i].durationMinutes)}',
                        priceFcfa: filteredServices[i].priceFcfa,
                        onAdd: () {
                          HapticFeedback.lightImpact();
                          ref.read(ticketProvider.notifier).addService(
                                filteredServices[i],
                                stylistId: defaultStylist?.id,
                                stylistName: defaultStylist?.fullName,
                              );
                        },
                      ),
                    ],

                    // Produits en vente
                    if (filteredServices.isNotEmpty && filteredProducts.isNotEmpty)
                      const Divider(height: 1, color: AppColors.border),

                    for (int i = 0; i < filteredProducts.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.border),
                      _ServiceRow(
                        serviceName: filteredProducts[i].name,
                        subtitle: 'Vente · ${filteredProducts[i].brand}',
                        priceFcfa: filteredProducts[i].unitSalePriceFcfa,
                        onAdd: () {
                          HapticFeedback.lightImpact();
                          ref.read(ticketProvider.notifier).addProduct(filteredProducts[i]);
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.serviceName,
    required this.subtitle,
    required this.priceFcfa,
    required this.onAdd,
  });

  final String serviceName;
  final String subtitle;
  final int priceFcfa;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceName,
                  style: AppTypography.sora(15, FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTypography.manrope(
                    12,
                    FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            Formatters.fcfa(priceFcfa),
            style: AppTypography.sora(15, FontWeight.w700),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
