import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/profile.dart';
import '../domain/staff_schedule.dart';
import 'staff_form_page.dart';
import 'staff_providers.dart';
import 'staff_schedule_page.dart';

/// 4.2 — Fiche employé : spécialités, commissions, congés.
class StaffDetailPage extends ConsumerWidget {
  const StaffDetailPage({super.key, required this.profileId});

  static const routeName = '/staff/detail';

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(staffDetailProvider(profileId));

    return AppScreen(
      title: 'Fiche employé',
      action: AppIconButton(
        icon: Icons.edit_outlined,
        onTap: () async {
          final profile = member.valueOrNull;
          if (profile == null) return;
          await Navigator.of(context).pushNamed(
            StaffFormPage.routeName,
            arguments: profile,
          );
          ref.invalidate(staffDetailProvider(profileId));
          ref.invalidate(teamProvider);
          ref.invalidate(stylistsProvider);
        },
      ),
      child: member.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(staffDetailProvider(profileId)),
        ),
        data: (data) => data == null
            ? const AppEmptyState(
                title: 'Membre introuvable',
                icon: Icons.badge_outlined,
              )
            : _StaffBody(member: data),
      ),
    );
  }
}

class _StaffBody extends ConsumerWidget {
  const _StaffBody({required this.member});

  final Profile member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(staffStatsProvider(member.id)).valueOrNull;
    final timeOff = (ref.watch(timeOffProvider).valueOrNull ?? const <TimeOff>[])
        .where((request) =>
            request.profileId == member.id &&
            request.status == TimeOffStatus.approved &&
            request.endDate.isAfter(DateTime.now()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tintBlue,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  Formatters.initials(member.fullName),
                  style: AppTypography.sora(
                    22,
                    FontWeight.w700,
                    color: AppColors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName,
                      style: AppTypography.sora(
                        20,
                        FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        member.role.label,
                        if (member.phone?.isNotEmpty ?? false) member.phone!,
                      ].join(' · '),
                      style: AppTypography.manrope(
                        12.5,
                        FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (member.specialties.isNotEmpty) ...[
          const AppSectionTitle(
            'Spécialités',
            padding: EdgeInsets.fromLTRB(2, 2, 2, 10),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final speciality in member.specialties)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.tintBlue,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    speciality,
                    style: AppTypography.manrope(
                      12.5,
                      FontWeight.w600,
                      color: AppColors.blue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        const AppSectionTitle(
          'Commission',
          padding: EdgeInsets.fromLTRB(2, 0, 2, 10),
        ),
        AppGradientCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          bubbleColor: Colors.transparent,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Taux commission',
                    style: AppTypography.manrope(
                      12.5,
                      FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  Text(
                    '${member.commissionRate.toStringAsFixed(0)} %',
                    style: AppTypography.sora(
                      20,
                      FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(height: 1, color: Colors.white24),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Gagné ce mois',
                    style: AppTypography.manrope(
                      12.5,
                      FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  Text(
                    Formatters.fcfa(
                      (stats?['commission_fcfa'] as num?)?.toInt() ?? 0,
                    ),
                    style: AppTypography.sora(
                      24,
                      FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppSplitMetrics(
          entries: [
            (
              value: Formatters.fcfa(
                (stats?['revenue_fcfa'] as num?)?.toInt() ?? 0,
              ),
              label: 'CA généré',
              color: null,
            ),
            (
              value: '${(stats?['client_count'] as num?)?.toInt() ?? 0}',
              label: 'Clients',
              color: null,
            ),
            (
              value: stats?['rating'] == null
                  ? '—'
                  : (stats!['rating'] as num).toStringAsFixed(1),
              label: 'Note',
              color: null,
            ),
          ],
        ),
        const AppSectionTitle('Horaires & congés'),
        AppListCard(
          children: [
            AppListRow(
              label: 'Horaires de travail',
              subtitle: 'Jours travaillés et amplitude',
              strong: true,
              padding: const EdgeInsets.symmetric(vertical: 12),
              leading: const AppIconTile(
                icon: Icons.schedule_rounded,
                size: 36,
                radius: 11,
              ),
              trailing: const AppChevron(),
              onTap: () => Navigator.of(context).pushNamed(
                StaffSchedulePage.routeName,
                arguments: member,
              ),
            ),
            AppListRow(
              label: 'Solde congés',
              strong: true,
              padding: const EdgeInsets.symmetric(vertical: 12),
              leading: const AppIconTile(
                icon: Icons.beach_access_rounded,
                size: 36,
                radius: 11,
              ),
              trailing: Text(
                '${member.leaveBalanceDays} j',
                style: AppTypography.sora(
                  14,
                  FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            AppListRow(
              label: 'Prochain congé',
              strong: true,
              padding: const EdgeInsets.symmetric(vertical: 12),
              leading: const AppIconTile(
                icon: Icons.event_rounded,
                color: AppColors.amber,
                background: AppColors.tintAmber,
                size: 36,
                radius: 11,
              ),
              trailing: Text(
                timeOff.isEmpty ? 'Aucun' : timeOff.first.periodLabel,
                style: AppTypography.manrope(
                  12.5,
                  FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
