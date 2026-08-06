import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/profile.dart';
import '../domain/staff_schedule.dart';
import 'staff_providers.dart';

/// 4.3 — Horaires & disponibilités : jours travaillés et amplitude.
class StaffSchedulePage extends ConsumerStatefulWidget {
  const StaffSchedulePage({super.key, required this.member});

  static const routeName = '/staff/schedule';

  final Profile member;

  @override
  ConsumerState<StaffSchedulePage> createState() => _StaffSchedulePageState();
}

class _StaffSchedulePageState extends ConsumerState<StaffSchedulePage> {
  List<StaffSchedule>? _week;
  bool _isSaving = false;

  Future<void> _editHours(StaffSchedule day) async {
    final start = await showTimePicker(
      context: context,
      helpText: 'Début — ${day.weekdayLabel}',
      initialTime: _parse(day.start),
    );
    if (start == null || !mounted) return;

    final end = await showTimePicker(
      context: context,
      helpText: 'Fin — ${day.weekdayLabel}',
      initialTime: _parse(day.end),
    );
    if (end == null) return;

    setState(() {
      _week = [
        for (final entry in _week!)
          entry.weekday == day.weekday
              ? entry.copyWith(
                  start: _format(start),
                  end: _format(end),
                  isDayOff: false,
                )
              : entry,
      ];
    });
  }

  TimeOfDay _parse(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  String _format(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_week == null) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(staffRepositoryProvider).saveSchedule(
            profileId: widget.member.id,
            schedule: _week!,
          );
      ref.invalidate(staffScheduleProvider(widget.member.id));

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enregistrement impossible : $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(staffScheduleProvider(widget.member.id));
    final week = _week ?? schedule.valueOrNull;
    final firstName = widget.member.fullName.split(' ').first;

    return AppScreen(
      title: 'Horaires — $firstName',
      footer: AppButton(
        label: 'Enregistrer',
        isLoading: _isSaving,
        onPressed: _week == null ? null : _save,
      ),
      child: schedule.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () =>
              ref.invalidate(staffScheduleProvider(widget.member.id)),
        ),
        data: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppListCard(
              children: [
                for (final day in week ?? const <StaffSchedule>[])
                  AppListRow(
                    label: day.weekdayLabel,
                    subtitle: day.isDayOff ? 'Repos' : '${day.start} – ${day.end}',
                    strong: true,
                    muted: day.isDayOff,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onTap: day.isDayOff ? null : () => _editHours(day),
                    trailing: AppToggle(
                      value: !day.isDayOff,
                      onChanged: (value) => setState(() {
                        _week = [
                          for (final entry in week!)
                            entry.weekday == day.weekday
                                ? entry.copyWith(isDayOff: !value)
                                : entry,
                        ];
                      }),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            AppCard(
              radius: 14,
              shadow: false,
              color: AppColors.tintGreenSoft,
              borderColor: AppColors.tintGreenBorder,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total hebdomadaire',
                    style: AppTypography.manrope(
                      13,
                      FontWeight.w600,
                      color: AppColors.textBody,
                    ),
                  ),
                  Text(
                    '${StaffSchedule.weeklyHours(week ?? const []).round()} h',
                    style: AppTypography.sora(
                      16,
                      FontWeight.w800,
                      color: AppColors.primary,
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
}
