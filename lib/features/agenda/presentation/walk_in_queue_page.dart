import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/profile.dart';
import '../../staff/presentation/staff_providers.dart';
import '../domain/walk_in_entry.dart';
import 'agenda_providers.dart';
import 'walk_in_form_dialog.dart';

/// 2.5 — Liste d'attente / walk-in : clients sans RDV, attribution rapide.
class WalkInQueuePage extends ConsumerWidget {
  const WalkInQueuePage({super.key});

  static const routeName = '/agenda/walk-in';

  Future<void> _assign(
    BuildContext context,
    WidgetRef ref,
    WalkInEntry entry,
  ) async {
    final stylists = ref.read(stylistsProvider).valueOrNull ?? const <Profile>[];
    final selected = await showModalBottomSheet<Profile>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          children: [
            Text(
              'Attribuer à…',
              style: AppTypography.sora(17, FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final stylist in stylists)
              AppListRow(
                label: stylist.fullName,
                subtitle: stylist.specialties.isEmpty
                    ? stylist.role.label
                    : stylist.specialties.join(' · '),
                strong: true,
                padding: const EdgeInsets.symmetric(vertical: 13),
                onTap: () => Navigator.pop(context, stylist),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;

    await ref.read(agendaRepositoryProvider).updateQueueEntry(
          entryId: entry.id,
          status: WalkInStatus.assigned,
          assignedStylistId: selected.id,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(walkInQueueProvider);
    final waiting = (queue.valueOrNull ?? const <WalkInEntry>[])
        .where((entry) => entry.status == WalkInStatus.waiting)
        .toList();
    final averageWait = ref.watch(averageWaitProvider);

    return AppScreen(
      title: 'Liste d\'attente',
      action: AppIconButton(
        icon: Icons.person_add_alt_rounded,
        filled: true,
        onTap: () => WalkInFormDialog.show(context),
      ),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Row(
          children: [
            Expanded(
              child: AppStatTile(
                label: 'En attente',
                value: '${waiting.length}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppStatTile(
                label: 'Attente moy.',
                value: averageWait == 0 ? '—' : '~$averageWait min',
              ),
            ),
          ],
        ),
      ),
      child: queue.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(walkInQueueProvider),
        ),
        data: (entries) => entries.isEmpty
            ? const AppEmptyState(
                title: 'File vide',
                message: 'Aucun client en attente pour le moment.',
                icon: Icons.groups_outlined,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    _WalkInCard(
                      position: i + 1,
                      entry: entries[i],
                      onAssign: () => _assign(context, ref, entries[i]),
                      onRemove: () => ref
                          .read(agendaRepositoryProvider)
                          .updateQueueEntry(
                            entryId: entries[i].id,
                            status: WalkInStatus.left,
                          ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
    );
  }
}

class _WalkInCard extends StatelessWidget {
  const _WalkInCard({
    required this.position,
    required this.entry,
    required this.onAssign,
    required this.onRemove,
  });

  final int position;
  final WalkInEntry entry;
  final VoidCallback onAssign;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isNext = position == 1;
    final minutes = entry.waitingTime.inMinutes;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isNext ? AppColors.primary : AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$position',
                  style: AppTypography.sora(
                    13,
                    FontWeight.w700,
                    color: isNext ? Colors.white : AppColors.textBody,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.clientName,
                      style: AppTypography.manrope(14.5, FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${entry.serviceRequested} · arrivée '
                      '${Formatters.time(entry.arrivalTime)}',
                      style: AppTypography.manrope(
                        12,
                        FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppBadge(
                label: '$minutes min',
                color: minutes >= 20 ? AppColors.amber : AppColors.primary,
                background:
                    minutes >= 20 ? AppColors.tintAmber : AppColors.tintGreen,
                dense: true,
              ),
            ],
          ),
          if (entry.status == WalkInStatus.waiting) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Attribuer',
                    height: 40,
                    onPressed: onAssign,
                  ),
                ),
                const SizedBox(width: 8),
                AppIconButton(
                  icon: Icons.close_rounded,
                  onTap: onRemove,
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: AppBadge(
                label: entry.status.label,
                color: AppColors.primary,
                background: AppColors.tintGreen,
                dense: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
