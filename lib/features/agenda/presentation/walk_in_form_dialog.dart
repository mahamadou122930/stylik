import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/profile.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/domain/salon_service.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../staff/presentation/staff_providers.dart';
import '../domain/walk_in_entry.dart';
import 'agenda_providers.dart';

/// 2.5 — Formulaire d'ajout rapide d'un client de passage (Walk-in).
class WalkInFormDialog extends ConsumerStatefulWidget {
  const WalkInFormDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WalkInFormDialog(),
    );
  }

  @override
  ConsumerState<WalkInFormDialog> createState() => _WalkInFormDialogState();
}

class _WalkInFormDialogState extends ConsumerState<WalkInFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  SalonService? _selectedService;
  Profile? _selectedStylist;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _addToQueue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final salonId = ref.read(currentSalonIdProvider);
      if (salonId == null) throw Exception('Salon non identifié');

      final entry = WalkInEntry(
        id: '',
        salonId: salonId,
        clientName: _nameController.text.trim(),
        serviceRequested: _selectedService?.name ?? 'Prestation salon',
        arrivalTime: DateTime.now(),
        status: WalkInStatus.waiting,
        assignedStylistId: _selectedStylist?.id,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );

      final repo = ref.read(agendaRepositoryProvider);
      await repo.addToQueue(entry);

      ref.invalidate(walkInQueueProvider);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'ajout en file d\'attente: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider).valueOrNull ?? [];
    final staff = ref.watch(stylistsProvider).valueOrNull ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Client sans RDV',
                    style: AppTypography.sora(18, FontWeight.w700),
                  ),
                  const AppIconButton(icon: Icons.close_rounded),
                ],
              ),
              const SizedBox(height: 16),
              AppInput(
                controller: _nameController,
                label: 'Nom du client',
                hint: 'Ex: Awa Sow',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 14),
              AppInput(
                controller: _phoneController,
                label: 'Téléphone (Optionnel)',
                hint: '+221 77 000 00 00',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              const AppSectionTitle('Prestation souhaitée'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SalonService>(
                    value: _selectedService,
                    hint: Text(
                      'Sélectionner une prestation',
                      style: AppTypography.manrope(14, FontWeight.w500),
                    ),
                    isExpanded: true,
                    items: [
                      for (final s in services)
                        DropdownMenuItem(
                          value: s,
                          child: Text(
                            '${s.name} (${s.priceFcfa} F)',
                            style: AppTypography.sora(14, FontWeight.w600),
                          ),
                        ),
                    ],
                    onChanged: (val) => setState(() => _selectedService = val),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const AppSectionTitle('Coiffeur souhaité'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Profile>(
                    value: _selectedStylist,
                    hint: Text(
                      'Premier disponible',
                      style: AppTypography.manrope(14, FontWeight.w500),
                    ),
                    isExpanded: true,
                    items: [
                      for (final m in staff)
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            m.fullName,
                            style: AppTypography.sora(14, FontWeight.w600),
                          ),
                        ),
                    ],
                    onChanged: (val) => setState(() => _selectedStylist = val),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: _isSaving ? 'Ajout...' : 'Ajouter à la file d\'attente',
                isLoading: _isSaving,
                onPressed: _addToQueue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
