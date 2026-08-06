import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../catalog/domain/salon_service.dart';
import '../../pos/presentation/pos_page.dart';
import '../../pos/presentation/pos_providers.dart';
import '../domain/appointment.dart';
import 'agenda_providers.dart';

/// 2.3 — Détail d'un rendez-vous : client, prestations, statut, actions.
class AppointmentDetailPage extends ConsumerWidget {
  const AppointmentDetailPage({super.key, required this.appointmentId});

  static const routeName = '/agenda/appointment';

  final String appointmentId;

  /// Charge le ticket de caisse à partir du rendez-vous, puis ouvre la caisse.
  void _checkout(BuildContext context, WidgetRef ref, Appointment appointment) {
    final ticket = ref.read(ticketProvider.notifier);
    ticket.clear();

    for (final service in appointment.services) {
      ticket.addService(
        SalonService(
          id: service.serviceId,
          salonId: appointment.salonId,
          name: service.name,
          category: '',
          durationMinutes: service.durationMinutes,
          priceFcfa: service.priceFcfa,
        ),
        stylistId: appointment.stylistId,
      );
    }

    if (appointment.clientId != null) {
      ticket.attachClient(
        clientId: appointment.clientId!,
        clientName: appointment.clientName,
        stylistName: appointment.stylistName,
        timeLabel: Formatters.time(appointment.startTime),
      );
    }
    ticket.attachAppointment(appointment.id);

    Navigator.of(context).pushNamed(PosPage.routeName);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointment = ref.watch(appointmentDetailProvider(appointmentId));

    return AppScreen(
      title: 'Rendez-vous',
      action: AppIconButton(
        icon: Icons.edit_outlined,
        onTap: () {
          // TODO(agenda): édition du rendez-vous.
        },
      ),
      footer: appointment.valueOrNull == null
          ? null
          : Row(
              children: [
                AppIconButton(
                  icon: Icons.edit_outlined,
                  onTap: () {
                    // TODO(agenda): reprogrammer le rendez-vous.
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'Encaisser',
                    onPressed: () =>
                        _checkout(context, ref, appointment.value!),
                  ),
                ),
              ],
            ),
      child: appointment.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(appointmentDetailProvider(appointmentId)),
        ),
        data: (data) => data == null
            ? const AppEmptyState(
                title: 'Rendez-vous introuvable',
                icon: Icons.event_busy_outlined,
              )
            : _AppointmentBody(appointment: data),
      ),
    );
  }
}

class _AppointmentBody extends StatelessWidget {
  const _AppointmentBody({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(appointment.startTime, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppGradientCard(
          padding: const EdgeInsets.all(18),
          bubbleColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppBadge.onDark(label: appointment.status.label),
                  Text(
                    isToday
                        ? 'Aujourd\'hui'
                        : Formatters.weekdayDayMonth(appointment.startTime),
                    style: AppTypography.sora(
                      13,
                      FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${Formatters.time(appointment.startTime)} — '
                '${Formatters.time(appointment.endTime)}',
                style: AppTypography.sora(
                  24,
                  FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Durée estimée '
                '${Formatters.duration(appointment.duration.inMinutes)}',
                style: AppTypography.manrope(
                  13.5,
                  FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  Formatters.initials(appointment.clientName ?? 'Client'),
                  style: AppTypography.sora(
                    15,
                    FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.clientName ?? 'Client de passage',
                      style: AppTypography.manrope(15, FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      appointment.clientVisitCount > 0
                          ? '${appointment.clientVisitCount} visites'
                          : 'Nouveau client',
                      style: AppTypography.manrope(
                        12.5,
                        FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (appointment.clientPhone != null)
                const AppIconTile(
                  icon: Icons.phone_outlined,
                  size: 38,
                  radius: 11,
                ),
            ],
          ),
        ),
        const AppSectionTitle('Prestations'),
        if (appointment.services.isEmpty)
          const AppEmptyState(
            compact: true,
            title: 'Aucune prestation',
            icon: Icons.content_cut_rounded,
          )
        else
          AppListCard(
            children: [
              for (final service in appointment.services)
                AppListRow(
                  label: service.name,
                  subtitle: [
                    Formatters.duration(service.durationMinutes),
                    if (service.stylistName != null) service.stylistName!,
                  ].join(' · '),
                  strong: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  trailing: Text(
                    Formatters.fcfa(service.priceFcfa),
                    style: AppTypography.sora(14, FontWeight.w700),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 10),
        AppCard(
          radius: 14,
          shadow: false,
          color: AppColors.tintGreenSoft,
          borderColor: AppColors.tintGreenBorder,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total estimé',
                style: AppTypography.sora(14, FontWeight.w700),
              ),
              Text(
                Formatters.fcfa(appointment.totalPriceFcfa),
                style: AppTypography.sora(
                  18,
                  FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        if (appointment.notes?.isNotEmpty ?? false) ...[
          const AppSectionTitle('Notes'),
          AppQuoteBlock(appointment.notes!),
        ],
      ],
    );
  }
}
