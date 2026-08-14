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
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/profile_page.dart';
import '../../inventory/presentation/inventory_page.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../pos/presentation/pos_providers.dart';
import 'home_providers.dart';
import 'reception_home_page.dart';
import 'stylist_home_page.dart';

/// 1 · Accueil — la journée du salon en un coup d'œil.
///
/// Quatre tuiles (CA, rendez-vous, panier moyen, remplissage), la semaine en
/// cours en barres, puis les prochains rendez-vous : la mise en page de la
/// maquette, chaque chiffre branché sur les données réelles du salon.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const routeName = '/home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final role = profile?.role ?? UserRole.coiffeur;
    final appointments = ref.watch(dayAppointmentsProvider);

    final today = (appointments.valueOrNull ?? const <Appointment>[]);
    final upcoming = ref.watch(upcomingTodayProvider);

    final firstName = (profile?.fullName ?? '').split(' ').first;

    return AppScreen(
      title: firstName.isEmpty ? 'Bonjour' : 'Bonjour, $firstName',
      subtitle: Formatters.day(DateTime.now()),
      showBack: false,
      largeTitle: true,
      subtitleFirst: true,
      action: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed(ProfilePage.routeName),
        child: AppAvatar(
          initials: Formatters.initials(profile?.fullName ?? '?'),
          size: 46,
          background: AppColors.primary,
          color: Colors.white,
        ),
      ),
      // Le corps dépend du métier : le gérant pilote le salon, la réception
      // tient le comptoir, le coiffeur suit sa journée et sa rémunération.
      child: profile == null
          // Le rôle décide de la mise en page : afficher un accueil au hasard
          // en attendant le profil ferait clignoter le mauvais tableau de bord.
          ? const AppLoader(compact: true)
          : switch (profile.role) {
              _ when !role.canViewFullAgenda =>
                StylistHomePage(profile: profile),
              _ when !role.canViewFinance => const ReceptionHomePage(),
              _ => _managerBody(context, ref, today: today, upcoming: upcoming),
            },
    );
  }

  /// Accueil du gérant : les chiffres du salon.
  Widget _managerBody(
    BuildContext context,
    WidgetRef ref, {
    required List<Appointment> today,
    required List<Appointment> upcoming,
  }) {
    final appointments = ref.watch(dayAppointmentsProvider);
    final lowStock = ref.watch(lowStockProductsProvider);

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statGrid(context, ref, todayCount: today.length, upcoming: upcoming.length),
          const SizedBox(height: 14),
          const _WeekCard(),
          if (lowStock.isNotEmpty) ...[
            const SizedBox(height: 14),
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
          AppSectionTitle(
            'Prochains rendez-vous',
            trailing: GestureDetector(
              onTap: () =>
                  Navigator.of(context).pushNamed(AgendaPage.routeName),
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
                          subtitle: appointment.summary,
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
        ],
    );
  }

  /// Les quatre tuiles du haut, en grille 2 × 2.
  Widget _statGrid(
    BuildContext context,
    WidgetRef ref, {
    required int todayCount,
    required int upcoming,
  }) {
    final trend = ref.watch(revenueTrendProvider);
    final basket = ref.watch(averageTicketProvider);
    final occupancy = ref.watch(occupancyProvider);

    final rate = occupancy.rate;

    return Column(
      children: [
        // `IntrinsicHeight` borne la hauteur du `Row` à celle de la plus haute
        // tuile : sans lui, `stretch` hérite de la hauteur infinie du
        // `SingleChildScrollView` qui enveloppe la page.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  label: 'CA du jour',
                  value: Formatters.fcfa(ref.watch(todayCashTotalProvider)),
                  caption: trend == null
                      ? 'aujourd\'hui'
                      : '${trend < 0 ? '▼' : '▲'} '
                          '${(trend.abs() * 100).round()} % vs sem. dern.',
                  captionColor: trend == null || trend >= 0
                      ? AppColors.primary
                      : AppColors.expense,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Rendez-vous',
                  value: '$todayCount',
                  caption: '$upcoming à venir',
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
                child: _StatTile(
                  label: 'Panier moyen',
                  value: basket.saleCount == 0
                      ? '—'
                      : Formatters.fcfa(basket.valueFcfa),
                  caption: basket.saleCount == 0
                      ? 'aucune vente'
                      : 'sur ${basket.saleCount} vente'
                          '${basket.saleCount > 1 ? 's' : ''}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Remplissage',
                  value: rate == null ? '—' : '${(rate * 100).round()} %',
                  caption: rate == null
                      ? 'horaires à renseigner'
                      : '${occupancy.freeSlots} créneaux libres',
                  captionColor: AppColors.amber,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tuile de chiffre du jour : libellé, valeur, légende colorée.
class _StatTile extends StatelessWidget {
  const _StatTile({
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
              FontWeight.w700,
              color: captionColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// « Semaine en cours » : total encaissé et barres du lundi au dimanche.
class _WeekCard extends ConsumerWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(weekRevenueProvider);
    final total = week.fold<int>(0, (sum, day) => sum + day.totalFcfa);
    final today = DateTime.now();
    final todayIndex = week.indexWhere(
      (entry) =>
          entry.day.year == today.year &&
          entry.day.month == today.month &&
          entry.day.day == today.day,
    );

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Semaine en cours',
                  style: AppTypography.sora(14.5, FontWeight.w700),
                ),
              ),
              Text(
                Formatters.fcfa(total),
                style: AppTypography.sora(
                  13,
                  FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppBarChart(
            height: 88,
            highlightMax: false,
            highlightIndex: todayIndex,
            slices: [
              for (final entry in week)
                ChartSlice(
                  label: Formatters.weekdayShort(entry.day)
                      .substring(0, 1)
                      .toUpperCase(),
                  value: entry.totalFcfa,
                  // Un jour sans encaissement reste visible en piste neutre :
                  // une barre verte au ras du sol se lirait comme un montant.
                  color: entry.totalFcfa == 0 ? AppColors.toggleOff : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
