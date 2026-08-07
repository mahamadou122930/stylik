import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_providers.dart';
import 'staff_providers.dart';

/// Nouvel employé : identité, rôle, spécialités et commission.
///
/// Aucun compte n'est créé ici — voir le bandeau explicatif en bas d'écran et
/// `StaffRepository.create`.
class StaffFormPage extends ConsumerStatefulWidget {
  const StaffFormPage({super.key});

  static const routeName = '/staff/new';

  /// Spécialités proposées, reprises des fiches employé de la maquette (4.2).
  static const List<String> suggestedSpecialties = [
    'Coupe femme',
    'Coupe homme',
    'Coloration',
    'Balayage',
    'Taille de barbe',
    'Tresses',
    'Soins',
    'Coiffure mariée',
  ];

  @override
  ConsumerState<StaffFormPage> createState() => _StaffFormPageState();
}

class _StaffFormPageState extends ConsumerState<StaffFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _commission = TextEditingController(text: '30');

  UserRole _role = UserRole.coiffeur;
  final Set<String> _specialties = {};
  bool _isSaving = false;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _commission.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final salonId = ref.read(currentSalonIdProvider);
    if (salonId == null) return;

    setState(() => _isSaving = true);
    try {
      final email = _email.text.trim();
      final phone = _phone.text.trim();

      await ref.read(staffRepositoryProvider).create(
            salonId: salonId,
            fullName: _fullName.text.trim(),
            role: _role,
            specialties: _specialties.toList(),
            commissionRate: double.tryParse(
                  _commission.text.trim().replaceAll(',', '.'),
                ) ??
                0,
            phone: phone.isEmpty ? null : phone,
            email: email.isEmpty ? null : email,
          );

      // La liste, les coiffeurs affectables et le compteur de présence
      // dérivent tous de `teamProvider`.
      ref.invalidate(teamProvider);
      ref.invalidate(stylistsProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_fullName.text.trim()} a rejoint l\'équipe.')),
      );
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
    return AppScreen(
      title: 'Nouvel employé',
      footer: AppButton(
        label: 'Ajouter à l\'équipe',
        isLoading: _isSaving,
        onPressed: _save,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInput(
              label: 'Nom complet',
              controller: _fullName,
              hint: 'Karim Sy',
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 7),
              child: Text(
                'Rôle',
                style: AppTypography.sora(
                  12.5,
                  FontWeight.w600,
                  color: AppColors.textBody,
                ),
              ),
            ),
            AppSegmented(
              padding: EdgeInsets.zero,
              items: [for (final role in UserRole.values) role.label],
              selectedIndex: UserRole.values.indexOf(_role),
              onChanged: (index) =>
                  setState(() => _role = UserRole.values[index]),
            ),
            const SizedBox(height: 15),
            AppInput.phone(
              controller: _phone,
              validator: (value) =>
                  (value != null && value.trim().isNotEmpty &&
                          value.trim().length < 6)
                      ? 'Numéro invalide'
                      : null,
            ),
            const SizedBox(height: 15),
            AppInput(
              label: 'Email (optionnel)',
              controller: _email,
              hint: 'karim@latelier.sn',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return null;
                return email.contains('@') && email.contains('.')
                    ? null
                    : 'Email invalide';
              },
            ),
            if (_role == UserRole.coiffeur) ...[
              const SizedBox(height: 15),
              AppInput(
                label: 'Taux de commission (%)',
                controller: _commission,
                keyboardType: TextInputType.number,
                validator: (value) {
                  final rate = double.tryParse(
                    (value ?? '').trim().replaceAll(',', '.'),
                  );
                  if (rate == null) return 'Nombre attendu';
                  return (rate < 0 || rate > 100) ? 'Entre 0 et 100' : null;
                },
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 7),
                child: Text(
                  'Spécialités',
                  style: AppTypography.sora(
                    12.5,
                    FontWeight.w600,
                    color: AppColors.textBody,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final specialty in StaffFormPage.suggestedSpecialties)
                    _SpecialtyChip(
                      label: specialty,
                      selected: _specialties.contains(specialty),
                      onTap: () => setState(
                        () => _specialties.contains(specialty)
                            ? _specialties.remove(specialty)
                            : _specialties.add(specialty),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            const AppCallout(
              message: 'Aucun compte n\'est créé : le membre apparaît au '
                  'planning et touche ses commissions sans se connecter. '
                  'S\'il s\'inscrit un jour avec l\'email renseigné, son '
                  'compte rejoindra automatiquement cette fiche.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.tintGreen : AppColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: selected ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.manrope(
            12.5,
            FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
