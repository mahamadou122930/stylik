import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/salon.dart';
import 'settings_providers.dart';

/// 10.1 — Infos salon & Horaires d'ouverture (Édition & Consultation).
class SalonInfoPage extends ConsumerWidget {
  const SalonInfoPage({super.key});

  static const routeName = '/settings/salon';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salon = ref.watch(currentSalonProvider);

    return AppScreen(
      title: 'Mon salon',
      child: salon.when(
        loading: () => const AppLoader(),
        error: (error, _) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(currentSalonProvider),
        ),
        data: (data) => data == null
            ? const AppEmptyState(
                title: 'Salon introuvable',
                message: 'Aucun salon n\'est rattaché à ce compte.',
                icon: Icons.storefront_outlined,
              )
            : _SalonFormBody(salon: data),
      ),
    );
  }
}

class _DayScheduleState {
  _DayScheduleState({
    required this.weekday,
    required this.dayName,
    required this.isClosed,
    required this.openTime,
    required this.closeTime,
  });

  final int weekday;
  final String dayName;
  bool isClosed;
  TimeOfDay openTime;
  TimeOfDay closeTime;
}

class _SalonFormBody extends ConsumerStatefulWidget {
  const _SalonFormBody({required this.salon});

  final Salon salon;

  @override
  ConsumerState<_SalonFormBody> createState() => _SalonFormBodyState();
}

class _SalonFormBodyState extends ConsumerState<_SalonFormBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _emailController;

  late List<_DayScheduleState> _dayStates;
  bool _isSaving = false;

  static const List<String> _dayNames = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.salon.name);
    _phoneController = TextEditingController(text: widget.salon.phone);
    _addressController = TextEditingController(text: widget.salon.address);
    _emailController = TextEditingController(text: widget.salon.email ?? '');

    _initDayStates();
  }

  void _initDayStates() {
    final jsonHours = widget.salon.openingHours;
    _dayStates = List.generate(7, (index) {
      final weekday = index + 1;
      final raw = jsonHours['$weekday'];
      
      bool isClosed = false;
      TimeOfDay openTime = const TimeOfDay(hour: 9, minute: 0);
      TimeOfDay closeTime = const TimeOfDay(hour: 19, minute: 0);

      if (raw is Map<String, dynamic>) {
        isClosed = raw['closed'] == true;
        if (raw['open'] is String) {
          openTime = _parseTimeOfDay(raw['open'] as String, openTime);
        }
        if (raw['close'] is String) {
          closeTime = _parseTimeOfDay(raw['close'] as String, closeTime);
        }
      } else if (jsonHours.isEmpty && weekday == 7) {
        // Par défaut si non renseigné : fermé le dimanche
        isClosed = true;
      }

      return _DayScheduleState(
        weekday: weekday,
        dayName: _dayNames[index],
        isClosed: isClosed,
        openTime: openTime,
        closeTime: closeTime,
      );
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  static String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static TimeOfDay _parseTimeOfDay(String timeStr, TimeOfDay fallback) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> _pickTime(
    _DayScheduleState day,
    bool isOpenTime,
  ) async {
    final initial = isOpenTime ? day.openTime : day.closeTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isOpenTime) {
          day.openTime = picked;
        } else {
          day.closeTime = picked;
        }
      });
    }
  }

  void _copyFirstDayToWeekdays() {
    final firstDay = _dayStates.first;
    setState(() {
      for (var i = 1; i < 6; i++) { // Du Lundi au Samedi
        _dayStates[i].isClosed = firstDay.isClosed;
        _dayStates[i].openTime = firstDay.openTime;
        _dayStates[i].closeTime = firstDay.closeTime;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Horaires du Lundi appliqués du Mardi au Samedi.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> openingHoursMap = {};
      for (final day in _dayStates) {
        if (day.isClosed) {
          openingHoursMap['${day.weekday}'] = {'closed': true};
        } else {
          openingHoursMap['${day.weekday}'] = {
            'open': _formatTimeOfDay(day.openTime),
            'close': _formatTimeOfDay(day.closeTime),
            'closed': false,
          };
        }
      }

      final updatedSalon = widget.salon.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        openingHours: openingHoursMap,
      );

      await ref.read(settingsRepositoryProvider).update(updatedSalon);
      ref.invalidate(currentSalonProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informations et horaires du salon enregistrés !'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'enregistrement : $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête Identité du Salon
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                    image: (widget.salon.logoUrl?.isNotEmpty ?? false)
                        ? DecorationImage(
                            image: NetworkImage(widget.salon.logoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (widget.salon.logoUrl?.isNotEmpty ?? false)
                      ? null
                      : const Icon(
                          Icons.content_cut_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.salon.name.isEmpty
                            ? 'Mon Salon'
                            : widget.salon.name,
                        style: AppTypography.sora(
                          19,
                          FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Configuration des horaires & coordonnées',
                        style: AppTypography.manrope(
                          12.5,
                          FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Section Horaires d'ouverture
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppSectionTitle(
                'Horaires d\'ouverture',
                padding: EdgeInsets.fromLTRB(2, 2, 2, 8),
              ),
              TextButton.icon(
                onPressed: _copyFirstDayToWeekdays,
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text(
                  'Appliquer Lun → Sam',
                  style: AppTypography.manrope(12, FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Cartes des jours
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                for (int i = 0; i < _dayStates.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 90,
                              child: Text(
                                _dayStates[i].dayName,
                                style: AppTypography.manrope(
                                  14.5,
                                  FontWeight.w700,
                                  color: _dayStates[i].isClosed
                                      ? AppColors.textFaint
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _dayStates[i].isClosed ? 'Fermé' : 'Ouvert',
                              style: AppTypography.manrope(
                                13,
                                FontWeight.w600,
                                color: _dayStates[i].isClosed
                                    ? AppColors.textFaint
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch.adaptive(
                              value: !_dayStates[i].isClosed,
                              activeTrackColor: AppColors.primary,
                              onChanged: (open) {
                                setState(() {
                                  _dayStates[i].isClosed = !open;
                                });
                              },
                            ),
                          ],
                        ),
                        if (!_dayStates[i].isClosed) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickTime(_dayStates[i], true),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.access_time_rounded,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Ouvre: ${_formatTimeOfDay(_dayStates[i].openTime)}',
                                          style: AppTypography.manrope(
                                            13,
                                            FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickTime(_dayStates[i], false),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.access_time_filled_rounded,
                                          size: 16,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Ferme: ${_formatTimeOfDay(_dayStates[i].closeTime)}',
                                          style: AppTypography.manrope(
                                            13,
                                            FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Section Informations de contact
          const AppSectionTitle('Coordonnées & Contact'),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AppInput(
                  controller: _nameController,
                  label: 'Nom du salon',
                  hint: 'Ex: L\'Atelier Coiffure',
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Le nom du salon est requis'
                      : null,
                ),
                const SizedBox(height: 12),
                AppInput.phone(
                  controller: _phoneController,
                  label: 'Téléphone',
                  hint: '+221 77 123 45 67',
                ),
                const SizedBox(height: 12),
                AppInput(
                  controller: _addressController,
                  label: 'Adresse',
                  hint: 'Ex: Almadies, Dakar',
                ),
                const SizedBox(height: 12),
                AppInput(
                  controller: _emailController,
                  label: 'Email de contact',
                  hint: 'Ex: contact@latelier.sn',
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Bouton d'enregistrement
          AppButton(
            label: _isSaving ? 'Enregistrement…' : 'Enregistrer les modifications',
            onPressed: _isSaving ? null : _save,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

