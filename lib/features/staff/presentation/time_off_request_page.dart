import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/profile.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/staff_schedule.dart';
import 'staff_providers.dart';

/// C1 — Demander un congé.
///
/// Le membre pose sa demande, le gérant la valide depuis « Absences ». Rien
/// n'est décompté ici : le solde n'est ajusté qu'à la validation, sinon une
/// demande refusée aurait déjà mangé les jours.
class TimeOffRequestPage extends ConsumerStatefulWidget {
  const TimeOffRequestPage({super.key});

  static const routeName = '/staff/time-off/request';

  @override
  ConsumerState<TimeOffRequestPage> createState() => _TimeOffRequestPageState();
}

class _TimeOffRequestPageState extends ConsumerState<TimeOffRequestPage> {
  TimeOffType _type = TimeOffType.vacation;
  late DateTime _from = _today;
  late DateTime _to = _today;
  final TextEditingController _note = TextEditingController();
  Profile? _selectedStylist;
  bool _sending = false;

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Bornes incluses : du 18 au 22 août fait cinq jours, pas quatre.
  int get _dayCount => _to.difference(_from).inDays + 1;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool isStart}) async {
    final initial = isStart ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked.isBefore(_from) ? _from : picked;
      }
    });
  }

  Future<void> _pickStylist(List<Profile> stylists) async {
    final picked = await showModalBottomSheet<Profile>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sélectionner un coiffeur',
              style: AppTypography.sora(18, FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final s in stylists)
              ListTile(
                title: Text(s.fullName),
                subtitle: Text(s.specialties.join(', ')),
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );

    if (picked != null) {
      setState(() => _selectedStylist = picked);
    }
  }

  Future<void> _submit() async {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null || _sending) return;

    final targetProfile = _selectedStylist ?? profile;

    setState(() => _sending = true);
    try {
      await ref.read(staffRepositoryProvider).requestTimeOff(
            TimeOff(
              id: '',
              salonId: profile.salonId,
              profileId: targetProfile.id,
              type: _type,
              status: TimeOffStatus.pending,
              startDate: _from,
              endDate: _to,
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            ),
          );

      ref.invalidate(timeOffProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetProfile.id == profile.id
                ? 'Demande envoyée au gérant.'
                : 'Demande de congé posée pour ${targetProfile.fullName}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Envoi impossible : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final team = ref.watch(teamProvider).valueOrNull ?? const <Profile>[];
    final targetProfile = _selectedStylist ?? profile;

    return AppScreen(
      title: 'Demander un congé',
      footer: AppButton(
        label: 'Envoyer la demande',
        icon: Icons.send_rounded,
        isLoading: _sending,
        onPressed: profile == null ? null : _submit,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (profile != null && profile.role != UserRole.coiffeur && team.isNotEmpty) ...[
            AppSelectField(
              label: 'Coiffeur / Employé concerné',
              value: targetProfile?.fullName ?? 'Choisir un employé',
              onTap: () => _pickStylist(team),
            ),
            const SizedBox(height: 18),
          ],
          const AppSectionLabel('Type'),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final type in TimeOffType.values) ...[
                  if (type != TimeOffType.values.first)
                    const SizedBox(width: 10),
                  Expanded(
                    child: _TypeChoice(
                      type: type,
                      selected: _type == type,
                      onTap: () => setState(() => _type = type),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          const AppSectionLabel('Période'),
          Row(
            children: [
              Expanded(
                child: AppSelectField(
                  label: 'Du',
                  value: Formatters.dayMonth(_from),
                  onTap: () => _pick(isStart: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppSelectField(
                  label: 'Au',
                  value: Formatters.dayMonth(_to),
                  onTap: () => _pick(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppCard(
            color: AppColors.tintGreenSoft,
            borderColor: AppColors.tintGreenBorder,
            shadow: false,
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Durée',
                    style: AppTypography.manrope(
                      13,
                      FontWeight.w600,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
                Text(
                  '$_dayCount jour${_dayCount > 1 ? 's' : ''}',
                  style: AppTypography.sora(14, FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const AppSectionLabel('Motif (optionnel)'),
          AppInput(
            controller: _note,
            hint: 'Congés annuels en famille',
            maxLines: 4,
          ),
          const SizedBox(height: 14),
          AppListCard(
            children: [
              AppListRow(
                label: 'Solde congés',
                strong: true,
                padding: const EdgeInsets.symmetric(vertical: 12),
                leading: const AppIconTile(icon: Icons.beach_access_outlined),
                trailing: Text(
                  '${profile?.leaveBalanceDays ?? 0} j restants',
                  style: AppTypography.sora(
                    14,
                    FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (_type == TimeOffType.vacation &&
              profile != null &&
              _dayCount > profile.leaveBalanceDays) ...[
            const SizedBox(height: 10),
            // Non bloquant : c'est au gérant de trancher, mais la personne
            // doit savoir qu'elle dépasse avant d'envoyer.
            Text(
              'Cette demande dépasse votre solde de '
              '${_dayCount - profile.leaveBalanceDays} jour(s).',
              style: AppTypography.manrope(
                12,
                FontWeight.w600,
                color: AppColors.amberDeep,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Choix du type d'absence — les trois cartes du haut de la maquette.
class _TypeChoice extends StatelessWidget {
  const _TypeChoice({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final TimeOffType type;
  final bool selected;
  final VoidCallback onTap;

  static const Map<TimeOffType, ({String label, IconData icon})> _display = {
    TimeOffType.vacation: (label: 'Congé', icon: Icons.beach_access_outlined),
    TimeOffType.sickLeave: (label: 'Maladie', icon: Icons.info_outline_rounded),
    TimeOffType.unpaid: (label: 'Absence', icon: Icons.schedule_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final display = _display[type]!;

    return AppCard(
      onTap: onTap,
      radius: 14,
      shadow: false,
      color: selected ? AppColors.tintBlue : AppColors.surface,
      borderColor: selected ? AppColors.blue : AppColors.border,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            display.icon,
            size: 22,
            color: selected ? AppColors.blue : AppColors.textSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            display.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.manrope(
              13,
              FontWeight.w700,
              color: selected ? AppColors.blue : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
