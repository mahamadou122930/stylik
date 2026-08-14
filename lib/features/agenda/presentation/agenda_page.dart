import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/profile.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../staff/presentation/staff_providers.dart';
import '../domain/appointment.dart';
import 'agenda_providers.dart';
import 'appointment_detail_page.dart';
import 'appointment_form_page.dart';
import 'stylist_agenda_page.dart';
import 'walk_in_queue_page.dart';

/// 2.1 — Planning global : une colonne par coiffeur, blocs horaires.
class AgendaPage extends ConsumerWidget {
  const AgendaPage({super.key});

  static const routeName = '/agenda';

  /// Hauteur d'une heure dans la grille.
  static const double hourHeight = 72;
  static const int openingHour = 9;
  static const int closingHour = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sans la permission « planning du salon », l'onglet Agenda n'est pas la
    // grille multi-colonnes mais le planning individuel : le coiffeur ne voit
    // que sa propre journée, et jamais la liste de ses collègues.
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    if (profile != null && !profile.role.canViewFullAgenda) {
      return StylistAgendaPage(stylist: profile, showBack: false);
    }

    final day = ref.watch(selectedDayProvider);
    final stylists = ref.watch(stylistsProvider).valueOrNull ?? const <Profile>[];
    final appointments = ref.watch(dayAppointmentsProvider);
    final byStylist = ref.watch(appointmentsByStylistProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Navigator.of(context).pushNamed(AppointmentFormPage.routeName),
        backgroundColor: AppColors.accent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.add_rounded, size: 26, color: Colors.white),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Formatters.day(day),
                          style: AppTypography.manrope(
                            12.5,
                            FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Planning',
                          style: AppTypography.screenTitleLarge,
                        ),
                      ],
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.groups_outlined,
                    onTap: () => Navigator.of(context)
                        .pushNamed(WalkInQueuePage.routeName),
                  ),
                  const SizedBox(width: 8),
                  AppIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => ref.read(selectedDayProvider.notifier).state =
                        day.subtract(const Duration(days: 1)),
                  ),
                  const SizedBox(width: 8),
                  AppIconButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => ref.read(selectedDayProvider.notifier).state =
                        day.add(const Duration(days: 1)),
                  ),
                ],
              ),
            ),
            _StylistHeader(stylists: stylists),
            Expanded(
              child: appointments.when(
                loading: () => const AppLoader(),
                error: (error, _) => AppErrorState(
                  message: '$error',
                  onRetry: () => ref.invalidate(dayAppointmentsProvider),
                ),
                data: (items) => stylists.isEmpty
                    ? const AppEmptyState(
                        title: 'Aucun coiffeur',
                        message: 'Ajoutez votre équipe pour afficher le '
                            'planning.',
                        icon: Icons.people_outline_rounded,
                      )
                    : _DayGrid(
                        stylists: stylists,
                        appointmentsByStylist: byStylist,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StylistHeader extends StatelessWidget {
  const _StylistHeader({required this.stylists});

  final List<Profile> stylists;

  @override
  Widget build(BuildContext context) {
    if (stylists.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.only(left: 46),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < stylists.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _accent(i).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        Formatters.initials(stylists[i].fullName)
                            .substring(0, 1),
                        style: AppTypography.sora(
                          13,
                          FontWeight.w700,
                          color: _accent(i),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stylists[i].fullName.split(' ').first,
                      style: AppTypography.manrope(
                        10.5,
                        FontWeight.w600,
                        color: AppColors.textBody,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Color _accent(int index) =>
      AppColors.chartSeries[index % AppColors.chartSeries.length];
}

/// Grille horaire : heures à gauche, une colonne par coiffeur.
class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.stylists, required this.appointmentsByStylist});

  final List<Profile> stylists;
  final Map<String, List<Appointment>> appointmentsByStylist;

  @override
  Widget build(BuildContext context) {
    const hours = AgendaPage.closingHour - AgendaPage.openingHour;
    const totalHeight = hours * AgendaPage.hourHeight;

    return SingleChildScrollView(
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          children: [
            Positioned.fill(
              left: 46,
              child: Column(
                children: [
                  for (var i = 0; i < hours; i++)
                    Container(
                      height: AgendaPage.hourHeight,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.gridLine),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: 46,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < hours; i++)
                    SizedBox(
                      height: AgendaPage.hourHeight,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10, top: 6),
                        child: Text(
                          '${AgendaPage.openingHour + i}h',
                          style: AppTypography.sora(
                            10.5,
                            FontWeight.w600,
                            color: AppColors.textFaint,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned.fill(
              left: 46,
              child: Row(
                children: [
                  for (var i = 0; i < stylists.length; i++)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: i == stylists.length - 1
                              ? null
                              : const Border(
                                  right: BorderSide(color: AppColors.gridLine),
                                ),
                        ),
                        child: Stack(
                          children: [
                            for (final appointment
                                in appointmentsByStylist[stylists[i].id] ??
                                    const <Appointment>[])
                              _positioned(context, appointment, i),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _positioned(BuildContext context, Appointment appointment, int index) {
    final startOffset = appointment.startTime.hour +
        appointment.startTime.minute / 60 -
        AgendaPage.openingHour;
    final height =
        appointment.duration.inMinutes / 60 * AgendaPage.hourHeight - 4;
    final accent = _StylistHeader._accent(index);

    return Positioned(
      left: 3,
      right: 3,
      top: startOffset * AgendaPage.hourHeight + 2,
      height: height.clamp(28, double.infinity),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed(
          AppointmentDetailPage.routeName,
          arguments: appointment.id,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.clientName ?? 'Client',
                style: AppTypography.sora(10.5, FontWeight.w700, color: accent),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                appointment.summary,
                style: AppTypography.manrope(
                  9.5,
                  FontWeight.w500,
                  color: AppColors.textBody,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Raccourci vers le planning individuel d'un coiffeur.
class StylistAgendaLink extends StatelessWidget {
  const StylistAgendaLink({super.key, required this.stylist});

  final Profile stylist;

  @override
  Widget build(BuildContext context) => AppListRow(
        label: stylist.fullName,
        subtitle: stylist.role.label,
        strong: true,
        trailing: const AppChevron(),
        onTap: () => Navigator.of(context).pushNamed(
          StylistAgendaPage.routeName,
          arguments: stylist,
        ),
      );
}
