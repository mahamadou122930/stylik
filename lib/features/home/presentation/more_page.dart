import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/presentation/catalog_page.dart';
import '../../finance/presentation/finance_page.dart';
import '../../finance/presentation/my_commission_page.dart';
import '../../inventory/presentation/inventory_page.dart';
import '../../loyalty/presentation/loyalty_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../staff/presentation/staff_page.dart';
import '../../staff/presentation/time_off_request_page.dart';

/// Onglet « Plus » : accès aux modules qui ne tiennent pas dans la barre.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  static const routeName = '/more';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider) ?? UserRole.coiffeur;

    final entries = <_MoreEntry>[
      const _MoreEntry(
        label: 'Services',
        description: 'Catalogue et forfaits',
        icon: Icons.content_cut_rounded,
        route: CatalogPage.routeName,
      ),
      if (role.canManageInventory)
        const _MoreEntry(
          label: 'Stock',
          description: 'Inventaire et réceptions',
          icon: Icons.inventory_2_rounded,
          color: AppColors.amber,
          background: AppColors.tintAmber,
          route: InventoryPage.routeName,
        ),
      if (role.canManageStaff)
        const _MoreEntry(
          label: 'Personnel',
          description: 'Équipe, horaires, congés',
          icon: Icons.groups_rounded,
          color: AppColors.blue,
          background: AppColors.tintBlue,
          route: StaffPage.routeName,
        )
      // Sans accès à l'écran Personnel, chacun doit tout de même pouvoir
      // poser une demande de congé.
      else
        const _MoreEntry(
          label: 'Mes congés',
          description: 'Demander une absence',
          icon: Icons.beach_access_rounded,
          color: AppColors.blue,
          background: AppColors.tintBlue,
          route: TimeOffRequestPage.routeName,
        ),
      if (role.canViewFinance)
        const _MoreEntry(
          label: 'Finance',
          description: 'CA, rapports, export',
          icon: Icons.bar_chart_rounded,
          route: FinancePage.routeName,
        )
      // La finance du salon lui étant fermée, le coiffeur accède quand même à
      // sa propre rémunération — c'est la sienne.
      else if (role.canViewOwnCommission)
        const _MoreEntry(
          label: 'Mes commissions',
          description: 'Ce que je gagne',
          icon: Icons.savings_rounded,
          route: MyCommissionPage.routeName,
        ),
      const _MoreEntry(
        label: 'Fidélité',
        description: 'Points, promotions, rappels',
        icon: Icons.card_giftcard_rounded,
        color: AppColors.violet,
        background: AppColors.tintViolet,
        route: LoyaltyPage.routeName,
      ),
      const _MoreEntry(
        label: 'Paramètres',
        description: 'Salon, rôles, abonnement',
        icon: Icons.settings_rounded,
        route: SettingsPage.routeName,
      ),
    ];

    return AppScreen(
      title: 'Plus',
      largeTitle: true,
      showBack: false,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
        children: [
          for (final entry in entries)
            AppCard(
              onTap: () => Navigator.of(context).pushNamed(entry.route),
              radius: 18,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppIconTile(
                    icon: entry.icon,
                    color: entry.color,
                    background: entry.background,
                    size: 44,
                    radius: 13,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.label,
                        style: AppTypography.sora(15, FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.description,
                        style: AppTypography.rowSubtitle,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MoreEntry {
  const _MoreEntry({
    required this.label,
    required this.description,
    required this.icon,
    required this.route,
    this.color = AppColors.primary,
    this.background = AppColors.tintGreen,
  });

  final String label;
  final String description;
  final IconData icon;
  final String route;
  final Color color;
  final Color background;
}
