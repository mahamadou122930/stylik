import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

/// 2.4 — Nouveau RDV : Client, prestations, coiffeur, créneau.
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Choisir un client',
                  style: AppTypography.sora(18, FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: clients.isEmpty
                      ? Center(
                          child: Text(
                            'Aucun client enregistré',
                            style: AppTypography.rowSubtitle,
                          ),
                        )
                      : ListView.separated(
                          itemCount: clients.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, index) {
                            final c = clients[index];
                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              leading: Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Text(
                                  c.initials,
                                  style: AppTypography.sora(
                                    13,
                                    FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              title: Text(
                                c.fullName,
                                style: AppTypography.manrope(
                                  14,
                                  FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                c.phone,
                                style: AppTypography.manrope(
                                  12,
                                  FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              trailing: const AppChevron(),
                              onTap: () => Navigator.pop(context, c),
                            );
                          },
                        ),
                ),
              ],
            ),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ajouter une prestation',
                  style: AppTypography.sora(18, FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: services.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final s = services[index];
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 4),
                        title: Text(
                          s.name,
                          style: AppTypography.manrope(
                            14,
                            FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          Formatters.duration(s.durationMinutes),
                          style: AppTypography.manrope(
                            12,
                            FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: Text(
                          Formatters.fcfa(s.priceFcfa),
                          style: AppTypography.sora(
                            14,
                            FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, s),
                      );
                    },
                  ),
                ),
              ],
            ),
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
    if (salonId == null ||
        _client == null ||
        _stylist == null ||
        _slot == null) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rendez-vous confirmé pour ${_client!.fullName}.'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Création impossible : $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stylists =
        ref.watch(stylistsProvider).valueOrNull ?? const <Profile>[];
    final day = ref.watch(selectedDayProvider);

    // Initialisation automatique du coiffeur si non sélectionné
    if (_stylist == null && stylists.isNotEmpty) {
      _stylist = stylists.first;
    }

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
        _client != null &&
        _stylist != null &&
        _slot != null &&
        _services.isNotEmpty;

    return AppScreen(
      title: 'Nouveau RDV',
      footer: GestureDetector(
        onTap: canConfirm && !_isSaving ? _confirm : null,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: canConfirm ? AppColors.accent : AppColors.toggleOff,
            borderRadius: BorderRadius.circular(16),
            boxShadow: canConfirm
                ? const [
                    BoxShadow(
                      color: Color(0x3D13A06B),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_isSaving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              else
                Text(
                  'Confirmer le RDV',
                  style: AppTypography.sora(
                    16,
                    FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              Text(
                Formatters.fcfa(_totalFcfa),
                style: AppTypography.sora(
                  17,
                  FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Client
          const _FieldLabel('Client'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A141E14),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _pickClient,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                              _client?.fullName ?? 'Sélectionner un client',
                              style: AppTypography.manrope(
                                14,
                                FontWeight.w700,
                                color: _client == null
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            if (_client != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  _client!.phone,
                                  style: AppTypography.manrope(
                                    11.5,
                                    FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(
                        LucideIcons.chevronRight,
                        size: 18,
                        color: AppColors.textFaint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Prestations
          const _FieldLabel('Prestations'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final service in _services)
                GestureDetector(
                  onTap: () => setState(() => _services.remove(service)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
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
                          LucideIcons.x,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.plus,
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

          // 3. Coiffeur
          const _FieldLabel('Coiffeur'),
          if (stylists.isEmpty)
            Text(
              'Aucun coiffeur disponible',
              style: AppTypography.rowSubtitle,
            )
          else
            Row(
              children: [
                for (var i = 0; i < stylists.length; i++) ...[
                  Expanded(
                    child: _StylistChoiceCard(
                      stylist: stylists[i],
                      isSelected: _stylist?.id == stylists[i].id,
                      onTap: () => setState(() {
                        _stylist = stylists[i];
                        _slot = null;
                      }),
                    ),
                  ),
                  if (i < stylists.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          const SizedBox(height: 16),

          // 4. Créneau · date
          _FieldLabel('Créneau · ${Formatters.day(day)}'),
          slots.when(
            loading: () => const AppLoader(compact: true),
            error: (error, _) =>
                AppErrorState(message: '$error', compact: true),
            data: (values) {
              // Si la liste calculée est vide, proposer les créneaux par défaut
              final availableSlots = values.isNotEmpty
                  ? values
                  : _generateDefaultSlots(day);

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in availableSlots)
                    _SlotChip(
                      slot: slot,
                      isSelected: _slot != null &&
                          _slot!.hour == slot.hour &&
                          _slot!.minute == slot.minute,
                      onTap: () => setState(() => _slot = slot),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  List<DateTime> _generateDefaultSlots(DateTime day) {
    return [
      DateTime(day.year, day.month, day.day, 9, 0),
      DateTime(day.year, day.month, day.day, 10, 30),
      DateTime(day.year, day.month, day.day, 11, 30),
      DateTime(day.year, day.month, day.day, 14, 0),
      DateTime(day.year, day.month, day.day, 15, 30),
      DateTime(day.year, day.month, day.day, 16, 0),
      DateTime(day.year, day.month, day.day, 17, 30),
    ];
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

class _StylistChoiceCard extends StatelessWidget {
  const _StylistChoiceCard({
    required this.stylist,
    required this.isSelected,
    required this.onTap,
  });

  final Profile stylist;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstName = stylist.fullName.split(' ').first;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: isSelected ? null : Border.all(color: AppColors.border),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x3D0C7A50),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          firstName,
          style: AppTypography.sora(
            13,
            FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textBody,
          ),
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime slot;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: isSelected ? null : Border.all(color: AppColors.border),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x3D13A06B),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          Formatters.time(slot),
          style: AppTypography.sora(
            13,
            FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textBody,
          ),
        ),
      ),
    );
  }
}
