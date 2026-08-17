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
  ///
  /// Assez haute pour qu'une prestation de trente minutes affiche le client
  /// *et* la prestation : à 72, elle ne laissait qu'une ligne.
  static const double hourHeight = 96;

  /// Largeur minimale d'une colonne de coiffeur.
  ///
  /// En dessous, un nom se réduit à « Maha… ». Au-delà de deux ou trois
  /// coiffeurs, la grille défile horizontalement plutôt que de comprimer
  /// chaque colonne jusqu'à l'illisible.
  static const double minColumnWidth = 118;

  /// Largeur de la colonne des heures, à gauche.
  static const double gutterWidth = 46;

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
  const _StylistHeader({required this.stylists, required this.columnWidth});

  final List<Profile> stylists;

  /// Identique à celle des colonnes de la grille : les noms doivent tomber
  /// exactement au-dessus des rendez-vous qu'ils désignent.
  final double columnWidth;

  @override
  Widget build(BuildContext context) {
    if (stylists.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < stylists.length; i++)
            SizedBox(
              width: columnWidth,
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
class _DayGrid extends StatefulWidget {
  const _DayGrid({required this.stylists, required this.appointmentsByStylist});

  final List<Profile> stylists;
  final Map<String, List<Appointment>> appointmentsByStylist;

  @override
  State<_DayGrid> createState() => _DayGridState();
}

class _DayGridState extends State<_DayGrid> {
  /// L'en-tête des coiffeurs et les colonnes défilent ensemble, sinon les noms
  /// ne désignent plus la bonne colonne dès qu'on fait glisser la grille.
  final ScrollController _headerScroll = ScrollController();
  final ScrollController _bodyScroll = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _headerScroll.addListener(() => _mirror(_headerScroll, _bodyScroll));
    _bodyScroll.addListener(() => _mirror(_bodyScroll, _headerScroll));
  }

  void _mirror(ScrollController from, ScrollController to) {
    // Le garde évite la boucle : chaque `jumpTo` déclenche l'écouteur d'en face.
    if (_syncing || !to.hasClients) return;
    if (to.offset == from.offset) return;

    _syncing = true;
    to.jumpTo(from.offset);
    _syncing = false;
  }

  @override
  void dispose() {
    _headerScroll.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const hours = AgendaPage.closingHour - AgendaPage.openingHour;
    const totalHeight = hours * AgendaPage.hourHeight;
    final count = widget.stylists.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Peu de coiffeurs : les colonnes remplissent l'écran. Au-delà, elles
        // gardent leur largeur lisible et la grille défile.
        final available = constraints.maxWidth - AgendaPage.gutterWidth;
        final columnWidth = count == 0
            ? available
            : (available / count).clamp(AgendaPage.minColumnWidth, available);
        final gridWidth = columnWidth * count;

        return Column(
          children: [
            Row(
              children: [
                const SizedBox(width: AgendaPage.gutterWidth),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _headerScroll,
                    scrollDirection: Axis.horizontal,
                    child: _StylistHeader(
                      stylists: widget.stylists,
                      columnWidth: columnWidth,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  height: totalHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Les heures restent visibles quel que soit le défilement
                      // horizontal : elles sont hors de ce scroll.
                      SizedBox(
                        width: AgendaPage.gutterWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < hours; i++)
                              SizedBox(
                                height: AgendaPage.hourHeight,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(left: 10, top: 6),
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
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _bodyScroll,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: gridWidth,
                            height: totalHeight,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Column(
                                    children: [
                                      for (var i = 0; i < hours; i++)
                                        Container(
                                          height: AgendaPage.hourHeight,
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: AppColors.gridLine,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Positioned.fill(
                                  child: Row(
                                    children: [
                                      for (var i = 0; i < count; i++)
                                        SizedBox(
                                          width: columnWidth,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: i == count - 1
                                                  ? null
                                                  : const Border(
                                                      right: BorderSide(
                                                        color:
                                                            AppColors.gridLine,
                                                      ),
                                                    ),
                                            ),
                                            child: Stack(
                                              children: [
                                                for (final appointment
                                                    in widget.appointmentsByStylist[
                                                            widget.stylists[i]
                                                                .id] ??
                                                        const <Appointment>[])
                                                  _positioned(
                                                    context,
                                                    appointment,
                                                    i,
                                                  ),
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
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _positioned(BuildContext context, Appointment appointment, int index) {
    final startOffset = appointment.startTime.hour +
        appointment.startTime.minute / 60 -
        AgendaPage.openingHour;
    final accent = _StylistHeader._accent(index);

    // La hauteur du bloc est proportionnelle à la durée : une prestation de
    // trente minutes ne fait qu'une trentaine de pixels, marges comprises.
    final height =
        (appointment.duration.inMinutes / 60 * AgendaPage.hourHeight - 4)
            .clamp(28.0, double.infinity);

    // En dessous, deux lignes de texte ne tiennent pas — c'est ce qui
    // provoquait le « BOTTOM OVERFLOWED ». On garde alors le nom du client,
    // la prestation restant lisible sur la fiche du rendez-vous.
    // 42 px : une prestation de trente minutes en fait 44 avec la hauteur
    // d'heure actuelle, et doit donc afficher client *et* prestation.
    final isCompact = height < 42;
    final padding = isCompact ? 3.0 : 6.0;

    return Positioned(
      left: 3,
      right: 3,
      top: startOffset * AgendaPage.hourHeight + 2,
      height: height,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed(
          AppointmentDetailPage.routeName,
          arguments: appointment.id,
        ),
        child: Container(
          padding: EdgeInsets.fromLTRB(7, padding, 7, padding),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          // Dernier rempart : une police agrandie par les réglages système
          // peut déborder même en mode compact.
          child: ClipRect(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    appointment.clientName ?? 'Client',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sora(
                      10.5,
                      FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
                if (!isCompact)
                  Flexible(
                    child: Text(
                      appointment.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.manrope(
                        9.5,
                        FontWeight.w500,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
              ],
            ),
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
