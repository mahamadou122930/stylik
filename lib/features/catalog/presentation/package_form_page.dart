import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/salon_service.dart';
import 'catalog_providers.dart';

/// 5.4 — Formulaire de création / édition d'un forfait (Lot 5 prototype).
class PackageFormPage extends ConsumerStatefulWidget {
  const PackageFormPage({super.key, this.package});

  static const routeName = '/catalog/package-form';

  final SalonService? package;

  @override
  ConsumerState<PackageFormPage> createState() => _PackageFormPageState();
}

class _PackageFormPageState extends ConsumerState<PackageFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;

  final Set<String> _selectedServiceIds = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.package;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _priceController =
        TextEditingController(text: p != null ? '${p.priceFcfa}' : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  int _calculateOriginalPrice(List<SalonService> allServices) {
    var sum = 0;
    for (final service in allServices) {
      if (_selectedServiceIds.contains(service.id)) {
        sum += service.priceFcfa;
      }
    }
    return sum;
  }

  Future<void> _savePackage(List<SalonService> allServices) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner au moins un service dans le forfait.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final salonId = ref.read(currentSalonIdProvider);
      if (salonId == null) throw Exception('Salon non identifié');

      final priceFcfa = int.parse(_priceController.text.trim());
      final originalPrice = _calculateOriginalPrice(allServices);

      final newPackage = SalonService(
        id: widget.package?.id ?? '',
        salonId: salonId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        priceFcfa: priceFcfa,
        durationMinutes: 90,
        category: 'Forfait',
        isPackage: true,
        originalPriceFcfa: originalPrice > priceFcfa ? originalPrice : null,
      );

      final repo = ref.read(catalogRepositoryProvider);
      if (widget.package == null) {
        await repo.create(newPackage);
      } else {
        await repo.update(newPackage);
      }

      ref.invalidate(servicesProvider);
      ref.invalidate(packagesProvider);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'enregistrement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicesState = ref.watch(servicesProvider);
    final allServices = servicesState.valueOrNull ?? [];

    final originalPrice = _calculateOriginalPrice(allServices);
    final enteredPrice = int.tryParse(_priceController.text.trim()) ?? 0;
    final discount = (originalPrice > 0 && enteredPrice > 0 && originalPrice > enteredPrice)
        ? (((originalPrice - enteredPrice) / originalPrice) * 100).round()
        : null;

    return AppScreen(
      title: widget.package == null ? 'Nouveau forfait' : 'Modifier le forfait',
      subtitle: 'Combiner des prestations à prix réduit',
      footer: AppButton(
        label: _isSaving ? 'Enregistrement...' : 'Enregistrer le forfait',
        isLoading: _isSaving,
        onPressed: () => _savePackage(allServices),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInput(
              controller: _nameController,
              label: 'Nom du forfait',
              hint: 'Ex: Pack Mariage Royal',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
            ),
            const SizedBox(height: 14),
            AppInput(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Brushing + Manucure + Soin visage',
            ),
            const SizedBox(height: 14),
            AppInput(
              controller: _priceController,
              label: 'Prix du forfait (FCFA)',
              hint: '45000',
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
                if (int.tryParse(v.trim()) == null) return 'Prix invalide';
                return null;
              },
            ),
            if (originalPrice > 0) ...[
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.all(12),
                color: AppColors.tintGreen,
                borderColor: AppColors.border,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Prix d\'origine cumulé :',
                      style: AppTypography.manrope(13, FontWeight.w600),
                    ),
                    Text(
                      Formatters.fcfa(originalPrice),
                      style: AppTypography.sora(14, FontWeight.w700),
                    ),
                    if (discount != null)
                      AppBadge(
                        label: '−$discount %',
                        color: AppColors.primary,
                        background: Colors.white,
                      ),
                  ],
                ),
              ),
            ],
            const AppSectionTitle('Services inclus'),
            if (servicesState.isLoading)
              const AppLoader(compact: true)
            else if (allServices.isEmpty)
              const AppEmptyState(
                compact: true,
                title: 'Aucun service disponible',
                message: 'Créez d\'abord des prestations individuelles.',
              )
            else
              AppListCard(
                children: [
                  for (final service in allServices.where((s) => !s.isPackage))
                    CheckboxListTile(
                      value: _selectedServiceIds.contains(service.id),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedServiceIds.add(service.id);
                          } else {
                            _selectedServiceIds.remove(service.id);
                          }
                        });
                      },
                      title: Text(
                        service.name,
                        style: AppTypography.sora(14, FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${service.category} · ${Formatters.fcfa(service.priceFcfa)}',
                        style: AppTypography.manrope(12, FontWeight.w500),
                      ),
                      activeColor: AppColors.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
