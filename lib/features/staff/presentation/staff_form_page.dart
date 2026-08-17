import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/profile.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_providers.dart';
import 'invite_code_card.dart';
import 'staff_providers.dart';

/// Nouvel employé ou édition d'un membre de l'équipe.
class StaffFormPage extends ConsumerStatefulWidget {
  const StaffFormPage({super.key, this.member});

  static const routeName = '/staff/new';

  /// Membre à modifier, ou `null` pour une création.
  final Profile? member;

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
  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _commission;
  late final TextEditingController _leaveBalance;

  late UserRole _role;
  late Set<String> _specialties;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _fullName = TextEditingController(text: m?.fullName ?? '');
    _phone = TextEditingController(text: m?.phone ?? '');
    _email = TextEditingController(text: m?.email ?? '');
    _commission = TextEditingController(
      text: m != null ? m.commissionRate.toStringAsFixed(0) : '30',
    );
    // Un nouvel employé démarre à zéro : c'est au gérant de poser le droit
    // annuel qu'il accorde, aucune valeur par défaut ne serait légitime.
    _leaveBalance = TextEditingController(
      text: '${m?.leaveBalanceDays ?? 0}',
    );
    _role = m?.role ?? UserRole.coiffeur;
    _specialties = m != null ? Set.from(m.specialties) : {};
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _commission.dispose();
    _leaveBalance.dispose();
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
      final commissionRate = double.tryParse(
            _commission.text.trim().replaceAll(',', '.'),
          ) ??
          0;
      final leaveBalanceDays = int.tryParse(_leaveBalance.text.trim()) ?? 0;
      final repository = ref.read(staffRepositoryProvider);

      if (widget.member == null) {
        await repository.create(
          salonId: salonId,
          fullName: _fullName.text.trim(),
          role: _role,
          specialties: _specialties.toList(),
          commissionRate: commissionRate,
          leaveBalanceDays: leaveBalanceDays,
          phone: phone.isEmpty ? null : phone,
          email: email.isEmpty ? null : email,
        );
      } else {
        final updated = widget.member!.copyWith(
          fullName: _fullName.text.trim(),
          role: _role,
          specialties: _specialties.toList(),
          commissionRate: commissionRate,
          leaveBalanceDays: leaveBalanceDays,
          phone: phone.isEmpty ? null : phone,
          email: email.isEmpty ? null : email,
        );
        await repository.update(updated);
        ref.invalidate(staffDetailProvider(widget.member!.id));
      }

      // La liste, les coiffeurs affectables et le compteur de présence
      // dérivent tous de `teamProvider`.
      ref.invalidate(teamProvider);
      ref.invalidate(stylistsProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.member == null
                ? '${_fullName.text.trim()} a rejoint l\'équipe.'
                : 'Fiche de ${_fullName.text.trim()} mise à jour.',
          ),
        ),
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
    final isEditing = widget.member != null;

    return AppScreen(
      title: isEditing ? 'Éditer l\'employé' : 'Nouvel employé',
      footer: AppButton(
        label: isEditing ? 'Enregistrer les modifications' : 'Ajouter à l\'équipe',
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
              hint: 'Bakary Keïta',
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
              hint: 'bakary@latelier.ml',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return null;
                return email.contains('@') && email.contains('.')
                    ? null
                    : 'Email invalide';
              },
            ),
            const SizedBox(height: 15),
            // Hors du bloc réservé au coiffeur : tout le personnel prend des
            // congés, y compris la réception.
            AppInput(
              label: 'Solde de congés (jours)',
              controller: _leaveBalance,
              keyboardType: TextInputType.number,
              validator: (value) {
                final days = int.tryParse((value ?? '').trim());
                if (days == null) return 'Nombre de jours attendu';
                return days < 0 ? 'Ne peut pas être négatif' : null;
              },
            ),
            // Le gérant coiffe aussi et touche sa commission : réserver ce
            // champ au rôle « coiffeur » l'empêchait de fixer son propre taux,
            // et ses prestations ne rapportaient rien au rapport.
            if (_role != UserRole.receptionniste) ...[
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
            if (!isEditing) ...[
              const AppCallout(
                message: 'Aucun compte n\'est créé : le membre apparaît au '
                    'planning et touche ses commissions sans se connecter.',
              ),
              const AppSectionTitle('Code d\'invitation'),
              const InviteCodeCard(
                message: 'L\'employé l\'entre pour rejoindre le salon, avec '
                    'l\'email renseigné ci-dessus : son compte se rattachera '
                    'alors à cette fiche.',
              ),
            ],
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
