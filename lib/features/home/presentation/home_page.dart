import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../agenda/domain/appointment.dart';
import '../../agenda/presentation/agenda_providers.dart';
import '../../agenda/presentation/appointment_detail_page.dart';
import '../../agenda/presentation/walk_in_queue_page.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/profile_page.dart';
import '../../inventory/presentation/inventory_page.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../pos/presentation/pos_providers.dart';
import '../../settings/presentation/settings_providers.dart';

/// Accueil : la journée du salon en un coup d'œil.
///
/// Reprend les blocs de la maquette (carte verte de CA, tuiles, listes) pour
/// rassembler ce que le personnel consulte en arrivant.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const routeName = '/home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final salon = ref.watch(currentSalonProvider).valueOrNull;
    final appointments = ref.watch(dayAppointmentsProvider);
    final queue = ref.watch(walkInQueueProvider).valueOrNull ?? const [];
    final cashTotal = ref.watch(todayCashTotalProvider);
    final ticketCount =
        ref.watch(todayTransactionsProvider).valueOrNull?.length ?? 0;
    final lowStock = ref.watch(lowStockProductsProvider);

    final upcoming = (appointments.valueOrNull ?? const <Appointment>[])
        .where((appointment) =>
            appointment.status.isActive &&
            appointment.endTime.isAfter(DateTime.now()))
        .take(4)
        .toList();

    return AppScreen(
      title: salon?.name ?? 'Mon salon',
      subtitle: Formatters.day(DateTime.now()),
      showBack: false,
      largeTitle: true,
      action: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed(ProfilePage.routeName),
        child: AppAvatar(
          initials: Formatters.initials(profile?.fullName ?? '?'),
          size: 40,
          background: AppColors.primary,
          color: Colors.white,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppGradientCard(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            bubbleColor: Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Caisse du jour',
                        style: AppTypography.manrope(
                          12.5,
                          FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        Formatters.fcfa(cashTotal),
                        style: AppTypography.sora(
                          28,
                          FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$ticketCount',
                      style: AppTypography.sora(
                        15,
                        FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'ventes',
                      style: AppTypography.manrope(
                        11,
                        FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppStatTile(
                  label: 'RDV aujourd\'hui',
                  value: '${appointments.valueOrNull?.length ?? 0}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppStatTile(
                  label: 'File d\'attente',
                  value: '${queue.length}',
                  tinted: queue.isNotEmpty,
                  onTap: () => Navigator.of(context)
                      .pushNamed(WalkInQueuePage.routeName),
                ),
              ),
            ],
          ),
          if (lowStock.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              onTap: () =>
                  Navigator.of(context).pushNamed(InventoryPage.routeName),
              radius: 14,
              shadow: false,
              color: AppColors.tintAmber,
              borderColor: AppColors.amberBorder,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: AppColors.amber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${lowStock.length} produit(s) à réapprovisionner',
                      style: AppTypography.manrope(
                        13,
                        FontWeight.w600,
                        color: AppColors.amberDeep,
                      ),
                    ),
                  ),
                  const AppChevron(),
                ],
              ),
            ),
          ],
          const AppSectionTitle('Prochains rendez-vous'),
          appointments.when(
            loading: () => const AppLoader(compact: true),
            error: (error, _) => AppErrorState(
              message: '$error',
              compact: true,
              onRetry: () => ref.invalidate(dayAppointmentsProvider),
            ),
            data: (_) => upcoming.isEmpty
                ? const AppEmptyState(
                    compact: true,
                    title: 'Plus de rendez-vous',
                    message: 'La journée est terminée côté planning.',
                    icon: Icons.event_available_outlined,
                  )
                : AppListCard(
                    children: [
                      for (final appointment in upcoming)
                        AppListRow(
                          label: appointment.clientName ?? 'Client de passage',
                          subtitle:
                              '${appointment.summary} · ${appointment.stylistName ?? ''}',
                          strong: true,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          leading: AppBadge(
                            label: Formatters.time(appointment.startTime),
                            color: appointment.status.color,
                            background:
                                appointment.status.color.withValues(alpha: 0.12),
                            dense: true,
                          ),
                          trailing: const AppChevron(),
                          onTap: () => Navigator.of(context).pushNamed(
                            AppointmentDetailPage.routeName,
                            arguments: appointment.id,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
