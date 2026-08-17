import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/profile.dart';
import '../../finance/domain/finance_summary.dart';
import '../../finance/presentation/finance_providers.dart';
import 'invite_code_card.dart';
import 'staff_detail_page.dart';
import 'staff_form_page.dart';
import 'staff_providers.dart';
import 'time_off_page.dart';

/// 4.1 — Liste du personnel : présence, rôle, spécialité.
class StaffPage extends ConsumerWidget {
  const StaffPage({super.key});

  static const routeName = '/staff';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamProvider);
    final absent = ref.watch(absentTodayIdsProvider);
    final presence = ref.watch(presenceCountProvider);
    // Clients servis et prestations du mois, par membre.
    final activity = ref.watch(monthActivityByStylistProvider);

    return AppScreen(
      title: 'Personnel',
      largeTitle: true,
      showBack: false,
      action: AppIconButton(
        icon: Icons.add_rounded,
        filled: true,
        onTap: () =>
            Navigator.of(context).pushNamed(StaffFormPage.routeName),
      ),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Row(
          children: [
            Expanded(
              child: AppStatTile(
                label: 'Présents',
                value: '${presence.present}/${presence.total}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppStatTile(
                label: 'En congé',
                value: '${absent.length}',
                onTap: () =>
                    Navigator.of(context).pushNamed(TimeOffPage.routeName),
              ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          team.when(
            loading: () => const AppLoader(),
            error: (error, _) => AppErrorState(
              message: '$error',
              onRetry: () => ref.invalidate(teamProvider),
            ),
            data: (members) => members.isEmpty
                ? const AppEmptyState(
                    title: 'Aucun membre',
                    message: 'Invitez vos coiffeurs et réceptionnistes.',
                    icon: Icons.badge_outlined,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < members.length; i++) ...[
                        _StaffCard(
                          member: members[i],
                          isAbsent: absent.contains(members[i].id),
                          activity: activity[members[i].id],
                          accent: AppColors
                              .chartSeries[i % AppColors.chartSeries.length],
                          onTap: () => Navigator.of(context).pushNamed(
                            StaffDetailPage.routeName,
                            arguments: members[i].id,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
          const AppSectionTitle('Rejoindre le salon'),
          const InviteCodeCard(
            message: 'Créez d\'abord la fiche de la personne avec son email, '
                'puis donnez-lui ce code : il lui servira à créer son compte.',
          ),
          const AppSectionTitle('Absences'),
          AppListCard(
            children: [
              AppListRow(
                label: 'Congés & absences',
                subtitle: 'Demandes à valider, calendrier',
                strong: true,
                padding: const EdgeInsets.symmetric(vertical: 12),
                leading: const AppIconTile(
                  icon: Icons.beach_access_rounded,
                  color: AppColors.amber,
                  background: AppColors.tintAmber,
                ),
                trailing: const AppChevron(),
                onTap: () =>
                    Navigator.of(context).pushNamed(TimeOffPage.routeName),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.member,
    required this.isAbsent,
    required this.accent,
    this.activity,
    this.onTap,
  });

  final Profile member;
  final bool isAbsent;
  final Color accent;

  /// Activité du mois : clients servis et prestations réalisées. `null` pour
  /// un membre qui n'encaisse pas, comme la réception.
  final StylistCommission? activity;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  Formatters.initials(member.fullName),
                  style: AppTypography.sora(15, FontWeight.w700, color: accent),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isAbsent ? AppColors.textFaint : AppColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  style: AppTypography.manrope(14.5, FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(
                  [
                    member.role.label,
                    if (member.specialties.isNotEmpty)
                      member.specialties.first,
                  ].join(' · '),
                  style: AppTypography.manrope(
                    12,
                    FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (activity != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${activity!.clientCount} client(s) · '
                    '${activity!.serviceCount} prestation(s) ce mois',
                    style: AppTypography.manrope(
                      11.5,
                      FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppBadge(
            label: isAbsent ? 'En congé' : 'Présent',
            color: isAbsent ? AppColors.amber : AppColors.primary,
            background: isAbsent ? AppColors.tintAmber : AppColors.tintGreen,
            dense: true,
          ),
        ],
      ),
    );
  }
}
