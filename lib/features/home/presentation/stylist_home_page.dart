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
import '../../auth/domain/profile.dart';
import '../../finance/domain/finance_summary.dart';
import '../../finance/presentation/finance_providers.dart';
import '../../finance/presentation/my_commission_page.dart';
import 'home_providers.dart';

/// Accueil du coiffeur — sa journée et sa rémunération.
///
/// Le gérant voit le chiffre du salon ; le coiffeur voit le sien. Rien ici ne
/// parle du salon dans son ensemble : ni CA global, ni planning des collègues,
/// ni panier moyen.
class StylistHomePage extends ConsumerWidget {
  const StylistHomePage({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(dayAppointmentsProvider);
    final commission = ref.watch(myMonthCommissionProvider);

    // Déjà restreints à sa fiche par `agendaStylistFilterProvider`.
    final today = appointments.valueOrNull ?? const <Appointment>[];
    final upcoming = ref.watch(upcomingTodayProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CommissionBanner(
          commission: commission.valueOrNull,
          fallbackRate: profile.commissionRate,
          isLoading: commission.isLoading,
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Mes RDV aujourd\'hui',
                  value: '${today.length}',
                  caption: '${upcoming.length} à venir',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Clients ce mois',
                  value: '${commission.valueOrNull?.clientCount ?? 0}',
                  caption:
                      '${commission.valueOrNull?.serviceCount ?? 0} prestations',
                ),
              ),
            ],
          ),
        ),
        AppSectionTitle(
          'Mon planning',
          trailing: GestureDetector(
            onTap: () => Navigator.of(context).pushNamed(AgendaPage.routeName),
            child: Text(
              'Tout voir',
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
          data: (_) => today.isEmpty
              ? const AppEmptyState(
                  compact: true,
                  title: 'Journée libre',
                  message: 'Aucun rendez-vous prévu aujourd\'hui.',
                  icon: Icons.event_available_outlined,
                )
              : AppListCard(
                  children: [
                    for (final appointment in today.take(5))
                      _PlanningRow(appointment: appointment),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        AppCard(
          onTap: () =>
              Navigator.of(context).pushNamed(MyCommissionPage.routeName),
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              const AppIconTile(
                icon: Icons.savings_rounded,
                size: 44,
                radius: 13,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Le détail de mes commissions',
                      style: AppTypography.sora(14.5, FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Par jour, semaine ou mois',
                      style: AppTypography.rowSubtitle,
                    ),
                  ],
                ),
              ),
              const AppChevron(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bandeau vert : la commission du mois, ce que le coiffeur vient vérifier.
class _CommissionBanner extends StatelessWidget {
  const _CommissionBanner({
    required this.commission,
    required this.fallbackRate,
    required this.isLoading,
  });

  final StylistCommission? commission;

  /// Taux de la fiche employé, tant que la période n'a produit aucune vente :
  /// afficher « 0 % » à quelqu'un qui touche 30 % serait faux.
  final double fallbackRate;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final rate = commission?.commissionRate ?? fallbackRate;

    return AppCard(
      color: AppColors.primary,
      borderColor: AppColors.primary,
      shadow: false,
      radius: 18,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ma commission à recevoir · ${Formatters.monthName(DateTime.now())}',
            style: AppTypography.manrope(
              12.5,
              FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isLoading
                  ? '—'
                  : Formatters.fcfa(commission?.commissionFcfa ?? 0),
              maxLines: 1,
              style: AppTypography.sora(
                30,
                FontWeight.w800,
                letterSpacing: -0.8,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _BannerTile(
                    label: 'CA que je génère',
                    value: isLoading
                        ? '—'
                        : Formatters.fcfa(commission?.revenueFcfa ?? 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BannerTile(
                    label: 'Taux',
                    value: '${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 1)} %',
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

/// Encart translucide posé sur le bandeau vert.
class _BannerTile extends StatelessWidget {
  const _BannerTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.manrope(
              11,
              FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.sora(
                15,
                FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile de chiffre secondaire, sous le bandeau.
class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

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
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne du planning : heure et durée à gauche, prestation et prix à droite,
/// barre verticale colorée par le statut (maquette « Mon planning »).
class _PlanningRow extends StatelessWidget {
  const _PlanningRow({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final isNow = appointment.isNow;

    return AppListRow(
      label: appointment.clientName ?? 'Client de passage',
      subtitle: '${appointment.summary} · '
          '${Formatters.fcfa(appointment.totalPriceFcfa)}',
      strong: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      leading: SizedBox(
        width: 54,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Formatters.time(appointment.startTime),
              style: AppTypography.sora(
                13,
                FontWeight.w700,
                color: isNow ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              isNow
                  ? 'en cours'
                  : Formatters.duration(appointment.duration.inMinutes),
              style: AppTypography.manrope(
                10,
                FontWeight.w700,
                color: isNow ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      trailing: const AppChevron(),
      onTap: () => Navigator.of(context).pushNamed(
        AppointmentDetailPage.routeName,
        arguments: appointment.id,
      ),
    );
  }
}
