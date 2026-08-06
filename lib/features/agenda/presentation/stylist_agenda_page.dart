import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/profile.dart';
import '../domain/appointment.dart';
import 'agenda_providers.dart';
import 'appointment_detail_page.dart';
import 'appointment_form_page.dart';

/// 2.2 — Planning individuel : la journée d'un seul coiffeur.
class StylistAgendaPage extends ConsumerStatefulWidget {
  const StylistAgendaPage({super.key, required this.stylist});

  static const routeName = '/agenda/stylist';

  final Profile stylist;

  @override
  ConsumerState<StylistAgendaPage> createState() => _StylistAgendaPageState();
}

class _StylistAgendaPageState extends ConsumerState<StylistAgendaPage> {
  late DateTime _day = ref.read(selectedDayProvider);

  @override
  Widget build(BuildContext context) {
    final appointments = ref.watch(dayAppointmentsProvider);
    final mine = (appointments.valueOrNull ?? const <Appointment>[])
        .where((appointment) => appointment.stylistId == widget.stylist.id)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      Formatters.initials(widget.stylist.fullName)
                          .substring(0, 1),
                      style: AppTypography.sora(
                        16,
                        FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.stylist.fullName,
                          style: AppTypography.sora(
                            20,
                            FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          [
                            if (widget.stylist.specialties.isNotEmpty)
                              widget.stylist.specialties.first
                            else
                              widget.stylist.role.label,
                            '${mine.length} RDV aujourd\'hui',
                          ].join(' · '),
                          style: AppTypography.manrope(
                            12,
                            FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const AppIconButton(icon: Icons.arrow_back_ios_new_rounded),
                ],
              ),
            ),
            _WeekStrip(
              day: _day,
              onChanged: (value) {
                setState(() => _day = value);
                ref.read(selectedDayProvider.notifier).state = value;
              },
            ),
            Expanded(
              child: appointments.when(
                loading: () => const AppLoader(),
                error: (error, _) => AppErrorState(
                  message: '$error',
                  onRetry: () => ref.invalidate(dayAppointmentsProvider),
                ),
                data: (_) => mine.isEmpty
                    ? AppEmptyState(
                        title: 'Journée libre',
                        message: 'Aucun rendez-vous pour ce coiffeur.',
                        icon: Icons.event_available_outlined,
                        actionLabel: 'Nouveau RDV',
                        onAction: () => Navigator.of(context)
                            .pushNamed(AppointmentFormPage.routeName),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        itemCount: mine.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _TimelineRow(
                          appointment: mine[index],
                          onTap: () => Navigator.of(context).pushNamed(
                            AppointmentDetailPage.routeName,
                            arguments: mine[index].id,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau des 5 jours autour de la date affichée.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.day, required this.onChanged});

  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final start = day.subtract(const Duration(days: 1));

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        children: [
          for (var i = 0; i < 5; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(start.add(Duration(days: i))),
                behavior: HitTestBehavior.opaque,
                child: _DayCell(
                  date: start.add(Duration(days: i)),
                  selected: i == 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.date, required this.selected});

  final DateTime date;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            Formatters.weekdayShort(date).toUpperCase(),
            style: AppTypography.manrope(
              10.5,
              FontWeight.w600,
              color: selected ? Colors.white70 : AppColors.textFaint,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${date.day}',
            style: AppTypography.sora(
              15,
              FontWeight.w700,
              color: selected ? Colors.white : AppColors.textBody,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne de la journée : heure à gauche, carte du RDV à droite.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.appointment, this.onTap});

  final Appointment appointment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isNow = appointment.isNow;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 44,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Formatters.time(appointment.startTime),
                  style: AppTypography.sora(
                    13,
                    FontWeight.w700,
                    color: isNow ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                if (isNow)
                  Text(
                    'en cours',
                    style: AppTypography.manrope(
                      9.5,
                      FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                color: isNow ? AppColors.tintGreenSoft : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border(
                  top: BorderSide(
                    color: isNow ? AppColors.tintGreenBorder : AppColors.border,
                  ),
                  right: BorderSide(
                    color: isNow ? AppColors.tintGreenBorder : AppColors.border,
                  ),
                  bottom: BorderSide(
                    color: isNow ? AppColors.tintGreenBorder : AppColors.border,
                  ),
                  left: BorderSide(color: appointment.status.color, width: 3),
                ),
                boxShadow: isNow ? null : AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.clientName ?? 'Client de passage',
                    style: AppTypography.manrope(14, FontWeight.w700),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${appointment.summary} · '
                    '${Formatters.duration(appointment.duration.inMinutes)}',
                    style: AppTypography.manrope(
                      12,
                      FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
