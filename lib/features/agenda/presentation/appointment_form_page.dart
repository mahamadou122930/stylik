import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/profile.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/domain/salon_service.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../clients/domain/client.dart';
import '../../clients/presentation/clients_providers.dart';
import '../../staff/presentation/staff_providers.dart';
import '../domain/appointment.dart';
import 'agenda_providers.dart';

/// 2.4 — Nouveau RDV : client, prestations, coiffeur, créneau.
class AppointmentFormPage extends ConsumerStatefulWidget {
  const AppointmentFormPage({super.key, this.client});

  static const routeName = '/agenda/new';

  /// Client pré-sélectionné (depuis sa fiche).
  final Client? client;

  @override
  ConsumerState<AppointmentFormPage> createState() =>
      _AppointmentFormPageState();
}

class _AppointmentFormPageState extends ConsumerState<AppointmentFormPage> {
  late Client? _client = widget.client;
  final List<SalonService> _services = [];
  Profile? _stylist;
  DateTime? _slot;
  bool _isSaving = false;

  int get _totalFcfa =>
      _services.fold(0, (sum, service) => sum + service.priceFcfa);

  int get _durationMinutes => _services.isEmpty
      ? 30
      : _services.fold(0, (sum, service) => sum + service.durationMinutes);

  Future<void> _pickClient() async {
    final clients = ref.read(clientsListProvider).valueOrNull ?? const [];
    final selected = await showModalBottomSheet<Client>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            children: [
              Text(
                'Choisir un client',
                style: AppTypography.sora(17, FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final client in clients)
                AppListRow(
                  label: client.fullName,
                  subtitle: client.phone,
                  strong: true,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  onTap: () => Navigator.pop(context, client),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) setState(() => _client = selected);
  }

  Future<void> _addService() async {
    final services = ref.read(servicesProvider).valueOrNull ?? const [];
    final selected = await showModalBottomSheet<SalonService>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            children: [
              Text(
                'Ajouter une prestation',
                style: AppTypography.sora(17, FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final service in services)
                AppListRow(
                  label: service.name,
                  subtitle: Formatters.duration(service.durationMinutes),
                  strong: true,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  onTap: () => Navigator.pop(context, service),
                  trailing: Text(
                    Formatters.fcfa(service.priceFcfa),
                    style: AppTypography.sora(14, FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _services.add(selected);
        _slot = null;
      });
    }
  }

  Future<void> _confirm() async {
    final salonId = ref.read(currentSalonIdProvider);
    if (salonId == null || _client == null || _stylist == null || _slot == null) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(agendaRepositoryProvider).create(
            Appointment(
              id: '',
              salonId: salonId,
              clientId: _client!.id,
              stylistId: _stylist!.id,
              startTime: _slot!,
              endTime: _slot!.add(Duration(minutes: _durationMinutes)),
              status: AppointmentStatus.confirmed,
              totalPriceFcfa: _totalFcfa,
              services: [
                for (final service in _services)
                  AppointmentService(
                    serviceId: service.id,
                    name: service.name,
                    priceFcfa: service.priceFcfa,
                    durationMinutes: service.durationMinutes,
                    stylistName: _stylist!.fullName,
                  ),
              ],
            ),
          );
      ref.invalidate(dayAppointmentsProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Création impossible : $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stylists = ref.watch(stylistsProvider).valueOrNull ?? const <Profile>[];
    final day = ref.watch(selectedDayProvider);

    final slots = _stylist == null
        ? const AsyncValue<List<DateTime>>.data([])
        : ref.watch(
            freeSlotsProvider((
              stylistId: _stylist!.id,
              day: day,
              durationMinutes: _durationMinutes,
            )),
          );

    final canConfirm =
        _client != null && _stylist != null && _slot != null && _services.isNotEmpty;

    return AppScreen(
      title: 'Nouveau RDV',
      footer: AppButton(
        label: 'Confirmer le RDV',
        trailingLabel: Formatters.fcfa(_totalFcfa),
        isLoading: _isSaving,
        onPressed: canConfirm ? _confirm : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel('Client'),
          AppCard(
            onTap: _pickClient,
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    _client == null ? '?' : _client!.initials,
                    style: AppTypography.sora(
                      13,
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
                        _client?.fullName ?? 'Choisir un client',
                        style: AppTypography.manrope(14, FontWeight.w700),
                      ),
                      if (_client != null)
                        Text(_client!.phone, style: AppTypography.rowSubtitle),
                    ],
                  ),
                ),
                const AppChevron(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Prestations'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final service in _services)
                GestureDetector(
                  onTap: () => setState(() => _services.remove(service)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.tintGreen,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${service.name} · ${Formatters.fcfa(service.priceFcfa)}',
                          style: AppTypography.manrope(
                            12.5,
                            FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              GestureDetector(
                onTap: _addService,
                child: CustomPaint(
                  painter: const DashedBorderPainter(
                    radius: 11,
                    color: AppColors.dashLine,
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Ajouter',
                          style: AppTypography.manrope(
                            12.5,
                            FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldLabel('Coiffeur'),
          if (stylists.isEmpty)
            Text('Aucun coiffeur disponible', style: AppTypography.rowSubtitle)
          else
            AppSegmented(
              padding: EdgeInsets.zero,
              items: [
                for (final stylist in stylists)
                  stylist.fullName.split(' ').first,
              ],
              selectedIndex: _stylist == null ? -1 : stylists.indexOf(_stylist!),
              onChanged: (index) => setState(() {
                _stylist = stylists[index];
                _slot = null;
              }),
            ),
          const SizedBox(height: 16),
          _FieldLabel('Créneau · ${Formatters.day(day)}'),
          slots.when(
            loading: () => const AppLoader(compact: true),
            error: (error, _) => AppErrorState(message: '$error', compact: true),
            data: (values) => values.isEmpty
                ? Text(
                    _stylist == null
                        ? 'Sélectionnez un coiffeur pour voir ses créneaux.'
                        : 'Aucun créneau libre ce jour.',
                    style: AppTypography.rowSubtitle,
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final slot in values)
                        GestureDetector(
                          onTap: () => setState(() => _slot = slot),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: _slot == slot
                                  ? AppColors.accent
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(11),
                              border: _slot == slot
                                  ? null
                                  : Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              Formatters.time(slot),
                              style: AppTypography.sora(
                                13,
                                FontWeight.w600,
                                color: _slot == slot
                                    ? Colors.white
                                    : AppColors.textBody,
                              ),
                            ),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 7),
        child: Text(
          label,
          style: AppTypography.sora(
            12.5,
            FontWeight.w600,
            color: AppColors.textBody,
          ),
        ),
      );
}
