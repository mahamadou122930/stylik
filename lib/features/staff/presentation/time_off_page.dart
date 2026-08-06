import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/staff_schedule.dart';
import 'staff_providers.dart';

/// 4.4 — Congés & absences : demandes à valider et calendrier.
class TimeOffPage extends ConsumerWidget {
  const TimeOffPage({super.key});

  static const routeName = '/staff/time-off';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(timeOffProvider);
    final pending = ref.watch(pendingTimeOffProvider);
    final upcoming = ref.watch(upcomingTimeOffProvider);

    Future<void> decide(TimeOff request, TimeOffStatus status) async {
      await ref.read(staffRepositoryProvider).setTimeOffStatus(
            timeOffId: request.id,
            status: status,
          );
      ref.invalidate(timeOffProvider);
    }

    return AppScreen(
      title: 'Congés & absences',
      child: requests.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(timeOffProvider),
        ),
        data: (items) => items.isEmpty
            ? const AppEmptyState(
                title: 'Aucune absence',
                message: 'Les demandes de congé de l\'équipe arriveront ici.',
                icon: Icons.beach_access_outlined,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (pending.isNotEmpty) ...[
                    AppSectionTitle(
                      'À valider',
                      padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
                      trailing: AppBadge(
                        label: '${pending.length}',
                        color: AppColors.amber,
                        background: AppColors.tintAmber,
                        dense: true,
                      ),
                    ),
                    for (final request in pending) ...[
                      _PendingCard(
                        request: request,
                        onApprove: () =>
                            decide(request, TimeOffStatus.approved),
                        onReject: () => decide(request, TimeOffStatus.rejected),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                  if (upcoming.isNotEmpty) ...[
                    const AppSectionTitle('Absences à venir'),
                    AppListCard(
                      children: [
                        for (final request in upcoming)
                          AppListRow(
                            label: request.profileName ?? 'Membre',
                            subtitle: '${request.type.label} validé',
                            strong: true,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            leading: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: request.type == TimeOffType.sickLeave
                                    ? AppColors.blue
                                    : AppColors.violet,
                                shape: BoxShape.circle,
                              ),
                            ),
                            trailing: Text(
                              request.periodLabel,
                              style: AppTypography.sora(
                                12,
                                FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final TimeOff request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final isSick = request.type == TimeOffType.sickLeave;

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSick ? AppColors.tintBlue : AppColors.tintAmber,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  Formatters.initials(request.profileName ?? '?'),
                  style: AppTypography.sora(
                    13,
                    FontWeight.w700,
                    color: isSick ? AppColors.blue : AppColors.amber,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.profileName ?? 'Membre',
                      style: AppTypography.rowTitleStrong,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${request.type.label} · ${request.dayCount} jour(s)',
                      style: AppTypography.manrope(
                        12,
                        FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                request.periodLabel,
                style: AppTypography.sora(
                  12.5,
                  FontWeight.w700,
                  color: AppColors.textBody,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Valider',
                  height: 40,
                  onPressed: onApprove,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Refuser',
                  height: 40,
                  variant: AppButtonVariant.danger,
                  onPressed: onReject,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
