import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../agenda/domain/appointment.dart';
import '../../agenda/presentation/agenda_page.dart';
import '../../agenda/presentation/agenda_providers.dart';
import '../../agenda/presentation/appointment_detail_page.dart';
import '../../agenda/presentation/appointment_form_page.dart';
import '../../pos/presentation/pos_page.dart';
import 'home_providers.dart';

/// Accueil de la réceptionniste — le comptoir.
///
/// Deux questions et deux seulement : qui arrive, et qu'est-ce qui reste à
/// encaisser. Le chiffre d'affaires et les commissions n'y figurent pas : ils
/// relèvent de `viewFinance`, réservée au gérant.
class ReceptionHomePage extends ConsumerWidget {
  const ReceptionHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(dayAppointmentsProvider);
    final today = appointments.valueOrNull ?? const <Appointment>[];
    final upcoming = ref.watch(upcomingTodayProvider);
    final unpaid = ref.watch(unpaidCompletedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'RDV aujourd\'hui',
                  value: '${today.length}',
                  caption: '${upcoming.length} à venir',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'À encaisser',
                  value: '${unpaid.length}',
                  caption: 'prestation(s) terminée(s)',
                  captionColor:
                      unpaid.isEmpty ? AppColors.textSecondary : AppColors.amber,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _QuickAction(
                  label: 'Nouveau RDV',
                  icon: Icons.add_rounded,
                  filled: true,
                  onTap: () => Navigator.of(context)
                      .pushNamed(AppointmentFormPage.routeName),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  label: 'Ouvrir caisse',
                  icon: Icons.receipt_long_rounded,
                  onTap: () =>
                      Navigator.of(context).pushNamed(PosPage.routeName),
                ),
              ),
            ],
          ),
        ),
        AppSectionTitle(
          'Prochains RDV · tout le salon',
          trailing: GestureDetector(
            onTap: () => Navigator.of(context).pushNamed(AgendaPage.routeName),
            child: Text(
              'Agenda',
              style: AppTypography.manrope(
                12.5,
                FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
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
                    for (final appointment in upcoming.take(4))
                      AppListRow(
                        label: appointment.clientName ?? 'Client de passage',
                        subtitle: '${appointment.summary} · '
                            '${Formatters.fcfa(appointment.totalPriceFcfa)}',
                        strong: true,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        leading: SizedBox(
                          width: 42,
                          child: Text(
                            Formatters.time(appointment.startTime),
                            style: AppTypography.sora(
                              13,
                              FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        trailing: appointment.stylistName == null
                            ? const AppChevron()
                            : AppBadge(
                                label: appointment.stylistName!,
                                color: AppColors.primary,
                                background: AppColors.tintGreen,
                                dense: true,
                              ),
                        onTap: () => Navigator.of(context).pushNamed(
                          AppointmentDetailPage.routeName,
                          arguments: appointment.id,
                        ),
                      ),
                  ],
                ),
        ),
        if (unpaid.isNotEmpty) ...[
          const SizedBox(height: 14),
          AppCard(
            onTap: () => Navigator.of(context).pushNamed(PosPage.routeName),
            radius: 14,
            shadow: false,
            color: AppColors.tintAmber,
            borderColor: AppColors.amberBorder,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 20,
                  color: AppColors.amber,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${unpaid.length} ticket(s) à clôturer',
                        style: AppTypography.manrope(
                          13,
                          FontWeight.w700,
                          color: AppColors.amberDeep,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Prestations terminées, paiement en attente',
                        style: AppTypography.manrope(
                          11.5,
                          FontWeight.w500,
                          color: AppColors.amberDeep,
                        ),
                      ),
                    ],
                  ),
                ),
                const AppChevron(),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Grand bouton d'action du comptoir.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : AppColors.textPrimary;

    return AppCard(
      onTap: onTap,
      radius: 16,
      shadow: !filled,
      color: filled ? AppColors.primary : null,
      borderColor: filled ? AppColors.primary : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: foreground),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.sora(15, FontWeight.w700, color: foreground),
          ),
        ],
      ),
    );
  }
}

/// Tuile de chiffre du comptoir.
class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.caption,
    this.captionColor = AppColors.textSecondary,
  });

  final String label;
  final String value;
  final String caption;
  final Color captionColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.statLabel),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.sora(
                24,
                FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.manrope(
              11.5,
              FontWeight.w600,
              color: captionColor,
            ),
          ),
        ],
      ),
    );
  }
}
