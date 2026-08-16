import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/staff_schedule.dart';
import 'staff_providers.dart';
import 'time_off_request_page.dart';

/// « Mes congés » — solde restant, demande en cours et historique.
///
/// Le pendant employé de `TimeOffPage`, qui reste l'écran du gérant : ici on
/// ne voit que ses propres absences.
class TimeOffHistoryPage extends ConsumerWidget {
  const TimeOffHistoryPage({super.key});

  static const routeName = '/staff/time-off/history';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final requests = ref.watch(myTimeOffProvider);
    final history = ref.watch(myTimeOffHistoryProvider);

    final all = requests.valueOrNull ?? const <TimeOff>[];
    final pending = all
        .where((request) => request.status == TimeOffStatus.pending)
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    // Ce qui est validé mais pas encore décompté du calendrier : utile pour
    // savoir ce qu'il reste réellement à poser.
    final approvedDays = history
        .where((request) =>
            request.status == TimeOffStatus.approved &&
            request.type == TimeOffType.vacation)
        .fold<int>(0, (sum, request) => sum + request.dayCount);

    return AppScreen(
      title: 'Mes congés',
      footer: AppButton(
        label: 'Demander un congé',
        icon: Icons.add_rounded,
        onPressed: () =>
            Navigator.of(context).pushNamed(TimeOffRequestPage.routeName),
      ),
      child: requests.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(myTimeOffProvider),
        ),
        data: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BalanceCard(
              remaining: profile?.leaveBalanceDays ?? 0,
              takenDays: approvedDays,
            ),
            if (pending.isNotEmpty) ...[
              AppSectionTitle(
                'En attente',
                trailing: AppBadge(
                  label: '${pending.length}',
                  color: AppColors.amberDeep,
                  background: AppColors.tintAmber,
                  dense: true,
                ),
              ),
              AppListCard(
                children: [
                  for (final request in pending)
                    TimeOffHistoryRow(
                      request: request,
                      title: request.type.label,
                    ),
                ],
              ),
            ],
            const AppSectionTitle('Historique'),
            if (history.isEmpty)
              const AppEmptyState(
                compact: true,
                title: 'Aucun congé passé',
                message: 'Vos demandes tranchées apparaîtront ici.',
                icon: Icons.beach_access_outlined,
              )
            else
              AppListCard(
                children: [
                  for (final request in history)
                    TimeOffHistoryRow(
                      request: request,
                      title: request.type.label,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Solde restant, et jours déjà validés sur l'exercice.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.remaining, required this.takenDays});

  final int remaining;
  final int takenDays;

  @override
  Widget build(BuildContext context) {
    // Un solde négatif est possible : le gérant peut accorder au-delà du
    // droit. L'afficher tel quel vaut mieux que de le masquer à zéro.
    final isOverdrawn = remaining < 0;

    return AppCard(
      color: isOverdrawn ? AppColors.tintAmber : AppColors.tintGreenSoft,
      borderColor:
          isOverdrawn ? AppColors.amberBorder : AppColors.tintGreenBorder,
      shadow: false,
      radius: 18,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isOverdrawn ? 'Solde dépassé' : 'Solde de congés',
            style: AppTypography.statLabel,
          ),
          const SizedBox(height: 6),
          Text(
            '$remaining jour${remaining.abs() > 1 ? 's' : ''}',
            style: AppTypography.sora(
              28,
              FontWeight.w800,
              letterSpacing: -0.8,
              color: isOverdrawn ? AppColors.amberDeep : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            takenDays == 0
                ? 'Aucun congé validé pour le moment.'
                : '$takenDays jour(s) de congé déjà validés.',
            style: AppTypography.manrope(
              12.5,
              FontWeight.w500,
              color: AppColors.textBody,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne d'absence : pastille de statut, période, durée.
///
/// Partagée entre l'historique du gérant — où [title] porte le nom du membre —
/// et celui de l'employé, où il porte le type d'absence.
class TimeOffHistoryRow extends StatelessWidget {
  const TimeOffHistoryRow({
    super.key,
    required this.request,
    required this.title,
  });

  final TimeOff request;
  final String title;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (request.status) {
      TimeOffStatus.approved => (AppColors.primary, Icons.check_rounded),
      TimeOffStatus.rejected => (AppColors.expense, Icons.close_rounded),
      TimeOffStatus.pending => (AppColors.amber, Icons.schedule_rounded),
    };

    return AppListRow(
      label: title,
      subtitle: '${request.status.label} · ${request.type.label}'
          '${request.note == null ? '' : ' · ${request.note}'}',
      strong: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      leading: AppIconTile(
        icon: icon,
        color: color,
        background: color.withValues(alpha: 0.12),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            request.periodLabel,
            style: AppTypography.sora(12.5, FontWeight.w700),
          ),
          const SizedBox(height: 1),
          Text(
            '${request.dayCount} j',
            style: AppTypography.manrope(
              11,
              FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
