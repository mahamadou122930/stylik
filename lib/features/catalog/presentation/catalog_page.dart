import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/salon_service.dart';
import 'catalog_providers.dart';
import 'packages_page.dart';
import 'service_edit_page.dart';

/// 5.1 — Liste des services : catalogue éditable par catégorie.
class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key});

  static const routeName = '/catalog';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final categories = ref.watch(serviceCategoriesProvider);
    final grouped = ref.watch(servicesByCategoryProvider);
    final packages = ref.watch(packagesProvider);

    return AppScreen(
      title: 'Services',
      largeTitle: true,
      showBack: false,
      action: AppIconButton(
        icon: Icons.add_rounded,
        filled: true,
        onTap: () => Navigator.of(context).pushNamed(ServiceEditPage.routeName),
      ),
      header: categories.length <= 1
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppFilterChips(
                items: categories,
                selectedIndex: ref.watch(selectedCategoryIndexProvider),
                onChanged: (index) => ref
                    .read(selectedCategoryIndexProvider.notifier)
                    .state = index,
              ),
            ),
      child: services.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(servicesProvider),
        ),
        data: (items) => items.isEmpty
            ? AppEmptyState(
                title: 'Catalogue vide',
                message: 'Ajoutez vos prestations et vos forfaits.',
                icon: Icons.content_cut_rounded,
                actionLabel: 'Ajouter une prestation',
                onAction: () =>
                    Navigator.of(context).pushNamed(ServiceEditPage.routeName),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in grouped.entries) ...[
                    AppSectionLabel(
                      entry.key,
                      padding: EdgeInsets.fromLTRB(
                        2,
                        entry.key == grouped.keys.first ? 6 : 18,
                        2,
                        10,
                      ),
                    ),
                    AppListCard(
                      children: [
                        for (final service in entry.value)
                          ServiceRow(
                            service: service,
                            onTap: () => Navigator.of(context).pushNamed(
                              ServiceEditPage.routeName,
                              arguments: service,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const AppSectionTitle('Forfaits'),
                  AppListCard(
                    children: [
                      AppListRow(
                        label: 'Packages / forfaits',
                        subtitle: packages.isEmpty
                            ? 'Aucun forfait pour le moment'
                            : '${packages.length} forfait(s) actif(s)',
                        strong: true,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        leading: const AppIconTile(
                          icon: Icons.auto_awesome_rounded,
                        ),
                        trailing: const AppChevron(),
                        onTap: () => Navigator.of(context)
                            .pushNamed(PackagesPage.routeName),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// Ligne de prestation : nom, durée, prix et chevron.
class ServiceRow extends StatelessWidget {
  const ServiceRow({
    super.key,
    required this.service,
    this.onTap,
    this.trailing,
  });

  final SalonService service;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      label: service.name,
      subtitle: Formatters.duration(service.durationMinutes),
      strong: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Formatters.fcfa(service.priceFcfa),
            style: AppTypography.sora(14.5, FontWeight.w800),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ] else ...[
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.dashLine,
            ),
          ],
        ],
      ),
    );
  }
}
