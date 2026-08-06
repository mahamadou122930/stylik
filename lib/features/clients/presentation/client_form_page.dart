import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/client.dart';
import 'clients_providers.dart';

/// 3.3 — Nouveau client : coordonnées, préférences, allergies.
class ClientFormPage extends ConsumerStatefulWidget {
  const ClientFormPage({super.key});

  static const routeName = '/clients/new';

  /// Étiquettes proposées à la création.
  static const List<String> suggestedTags = [
    'Nouveau',
    'Coloration',
    'VIP',
    'Mariage',
    'À relancer',
  ];

  @override
  ConsumerState<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends ConsumerState<ClientFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();

  ClientGender _gender = ClientGender.female;
  final Set<String> _tags = {'Nouveau'};
  bool _isSaving = false;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final salonId = ref.read(currentSalonIdProvider);
    if (salonId == null) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(clientsRepositoryProvider).create(
            Client(
              id: '',
              salonId: salonId,
              fullName: _fullName.text.trim(),
              phone: _phone.text.trim(),
              gender: _gender,
              allergiesNotes:
                  _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              tags: _tags.toList(),
            ),
          );
      ref.invalidate(clientsListProvider);

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

  Future<void> _pickGender() async {
    final selected = await showModalBottomSheet<ClientGender>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final gender in ClientGender.values)
              ListTile(
                title: Text(
                  gender.label,
                  style: AppTypography.manrope(14, FontWeight.w600),
                ),
                trailing: gender == _gender
                    ? const Icon(Icons.check_rounded, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.pop(context, gender),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _gender = selected);
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Nouveau client',
      footer: AppButton(
        label: 'Enregistrer le client',
        isLoading: _isSaving,
        onPressed: _save,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 18),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    // TODO(clients): photo de profil du client.
                  },
                  child: CustomPaint(
                    painter: const DashedBorderPainter(
                      radius: 24,
                      color: AppColors.dashLine,
                    ),
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 24,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Photo',
                            style: AppTypography.manrope(
                              10,
                              FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AppInput(
              label: 'Nom complet',
              controller: _fullName,
              hint: 'Khady Ndour',
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppInput.phone(
                    controller: _phone,
                    validator: (value) =>
                        (value == null || value.trim().length < 6)
                            ? 'Numéro invalide'
                            : null,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: AppSelectField(
                    label: 'Genre',
                    value: _gender.label,
                    onTap: _pickGender,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            AppInput(
              label: 'Allergies / notes',
              controller: _notes,
              maxLines: 3,
              hint: 'Ex. : allergie ammoniaque, cuir chevelu sensible…',
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 7),
              child: Text(
                'Étiquettes',
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
                for (final tag in ClientFormPage.suggestedTags)
                  GestureDetector(
                    onTap: () => setState(
                      () => _tags.contains(tag) ? _tags.remove(tag) : _tags.add(tag),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _tags.contains(tag)
                            ? AppColors.tintGreen
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(11),
                        border: _tags.contains(tag)
                            ? null
                            : Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        tag,
                        style: AppTypography.manrope(
                          12.5,
                          FontWeight.w600,
                          color: _tags.contains(tag)
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
