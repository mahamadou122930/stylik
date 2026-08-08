import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/profile_page.dart';
import '../../staff/presentation/staff_page.dart';
import 'notifications_page.dart';
import 'roles_page.dart';
import 'salon_info_page.dart';
import 'settings_providers.dart';
import 'subscription_page.dart';

/// Écran racine des paramètres (lot 10).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salon = ref.watch(currentSalonProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return AppScreen(
      title: 'Paramètres',
      showBack: false,
      largeTitle: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          salon.when(
            loading: () => const AppLoader(compact: true),
            error: (error, _) => AppErrorState(
              message: '$error',
              compact: true,
              onRetry: () => ref.invalidate(currentSalonProvider),
            ),
            data: (data) => AppCard(
              onTap: () => Navigator.of(context)
                  .pushNamed(SalonInfoPage.routeName),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      image: (data?.logoUrl?.isNotEmpty ?? false)
                          ? DecorationImage(
                              image: NetworkImage(data!.logoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (data?.logoUrl?.isNotEmpty ?? false)
                        ? null
                        : const Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data?.name ?? 'Mon salon',
                          style: AppTypography.sora(
                            19,
                            FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data?.address.isNotEmpty ?? false
                              ? data!.address
                              : 'Adresse à renseigner',
                          style: AppTypography.manrope(
                            12.5,
                            FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const AppChevron(),
                ],
              ),
            ),
          ),
          const AppSectionTitle('Salon'),
          AppListCard(
            children: [
              AppListRow(
                label: 'Infos & horaires',
                subtitle: 'Contact, ouverture du salon',
                leading: const AppIconTile(icon: Icons.schedule_rounded),
                trailing: const AppChevron(),
                strong: true,
                onTap: () => Navigator.of(context)
                    .pushNamed(SalonInfoPage.routeName),
              ),
              AppListRow(
                label: 'Équipe',
                subtitle: 'Coiffeurs, réceptionnistes, horaires',
                leading: const AppIconTile(icon: Icons.groups_rounded),
                trailing: const AppChevron(),
                strong: true,
                onTap: () =>
                    Navigator.of(context).pushNamed(StaffPage.routeName),
              ),
              AppListRow(
                label: 'Rôles & permissions',
                subtitle: 'Ce que chaque rôle peut faire',
                leading: const AppIconTile(
                  icon: Icons.admin_panel_settings_rounded,
                ),
                trailing: const AppChevron(),
                strong: true,
                onTap: () =>
                    Navigator.of(context).pushNamed(RolesPage.routeName),
              ),
            ],
          ),
          const AppSectionTitle('Application'),
          AppListCard(
            children: [
              AppListRow(
                label: 'Mon profil',
                subtitle: 'Compte, préférences, déconnexion',
                leading: const AppIconTile(
                  icon: Icons.person_rounded,
                  color: AppColors.primary,
                  background: AppColors.tintGreen,
                ),
                trailing: const AppChevron(),
                strong: true,
                onTap: () => Navigator.of(context)
                    .pushNamed(ProfilePage.routeName),
              ),
              AppListRow(
                label: 'Notifications',
                subtitle: 'Ce que l\'app vous signale',
                leading: const AppIconTile(
                  icon: Icons.notifications_rounded,
                  color: AppColors.amber,
                  background: AppColors.tintAmber,
                ),
                trailing: const AppChevron(),
                strong: true,
                onTap: () => Navigator.of(context)
                    .pushNamed(NotificationsPage.routeName),
              ),
              AppListRow(
                label: 'Abonnement',
                subtitle: 'Formule et facturation',
                leading: const AppIconTile(
                  icon: Icons.workspace_premium_rounded,
                  color: AppColors.violet,
                  background: AppColors.tintViolet,
                ),
                trailing: const AppChevron(),
                strong: true,
                onTap: () => Navigator.of(context)
                    .pushNamed(SubscriptionPage.routeName),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (profile != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Connecté·e — ${profile.fullName} · ${profile.role.label}',
                textAlign: TextAlign.center,
                style: AppTypography.rowSubtitle,
              ),
            ),
          AppButton(
            label: 'Se déconnecter',
            variant: AppButtonVariant.danger,
            icon: Icons.logout_rounded,
            onPressed: () async {
              Navigator.of(context).popUntil((route) => route.isFirst);
              await ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }
}
