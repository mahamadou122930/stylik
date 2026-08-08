import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/salon_service.dart';
import 'catalog_providers.dart';

/// 5.2 — Édition d'un service : prix, durée, catégorie, commission.
class ServiceEditPage extends ConsumerStatefulWidget {
  const ServiceEditPage({super.key, this.service});

  static const routeName = '/catalog/service';

  /// `null` pour une création.
  final SalonService? service;

  @override
  ConsumerState<ServiceEditPage> createState() => _ServiceEditPageState();
}

class _ServiceEditPageState extends ConsumerState<ServiceEditPage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.service?.name ?? '');
  late final TextEditingController _price = TextEditingController(
    text: widget.service == null ? '' : '${widget.service!.priceFcfa}',
  );
  late final TextEditingController _description =
      TextEditingController(text: widget.service?.description ?? '');

  late int _durationMinutes = widget.service?.durationMinutes ?? 30;
  late String _category = widget.service?.category ?? '';
  late double _commissionRate = widget.service?.commissionRate ?? 30;
  late bool _bookableOnline = widget.service?.isBookableOnline ?? true;
  bool _isSaving = false;

  late Set<String> _availableCategories;

  static const List<String> _defaultCategories = [
    'Coiffure',
    'Coupe & Brushing',
    'Coloration & Mèches',
    'Soins Capillaires',
    'Tresses & Tissages',
    'Barbe & Rasage',
    'Esthétique',
  ];

  @override
  void initState() {
    super.initState();
    _initCategories();
  }

  void _initCategories() {
    final existingFromRef = ref
        .read(serviceCategoriesProvider)
        .where((c) => c != 'Toutes')
        .toList();

    _availableCategories = {
      ...existingFromRef,
      ..._defaultCategories,
      if (widget.service?.category.isNotEmpty ?? false)
        widget.service!.category,
    };

    if (_category.isEmpty && _availableCategories.isNotEmpty) {
      _category = _availableCategories.first;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final newCategory = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Nouvelle catégorie',
          style: AppTypography.sora(17, FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Créez une catégorie pour regrouper vos prestations (ex: Coloration, Tresses, Soins...).',
              style: AppTypography.manrope(
                13,
                FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            AppInput(
              controller: controller,
              hint: 'Ex: Soins Visage, Extension...',
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Annuler',
              style: AppTypography.manrope(
                13,
                FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          AppButton(
            label: 'Ajouter',
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(dialogContext, text);
              }
            },
          ),
        ],
      ),
    );

    if (newCategory != null && newCategory.isNotEmpty) {
      setState(() {
        _availableCategories.add(newCategory);
        _category = newCategory;
      });
    }
  }

  Future<void> _save() async {
    final salonId = ref.read(currentSalonIdProvider);
    if (salonId == null || _name.text.trim().isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final repository = ref.read(catalogRepositoryProvider);
      final draft = SalonService(
        id: widget.service?.id ?? '',
        salonId: salonId,
        name: _name.text.trim(),
        category: _category.isEmpty ? 'Autre' : _category,
        durationMinutes: _durationMinutes,
        priceFcfa: int.tryParse(_price.text) ?? 0,
        commissionRate: _commissionRate,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        isBookableOnline: _bookableOnline,
        isPackage: widget.service?.isPackage ?? false,
        includedServiceIds: widget.service?.includedServiceIds ?? const [],
      );

      if (widget.service == null) {
        await repository.create(draft);
      } else {
        await repository.update(draft);
      }
      ref.invalidate(servicesProvider);

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

  Future<void> _pickDuration() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          children: [
            for (final minutes in const [15, 20, 30, 40, 45, 60, 90, 120, 180])
              AppListRow(
                label: Formatters.duration(minutes),
                padding: const EdgeInsets.symmetric(vertical: 13),
                onTap: () => Navigator.pop(context, minutes),
                trailing: minutes == _durationMinutes
                    ? const Icon(Icons.check_rounded,
                        size: 18, color: AppColors.accent)
                    : null,
              ),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _durationMinutes = selected);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesList = _availableCategories.toList();

    return AppScreen(
      title: widget.service?.name.isEmpty ?? true
          ? 'Nouveau service'
          : widget.service!.name,
      action: widget.service == null
          ? null
          : TextButton(
              onPressed: () async {
                await ref
                    .read(catalogRepositoryProvider)
                    .archive(widget.service!.id);
                ref.invalidate(servicesProvider);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: Text(
                'Supprimer',
                style: AppTypography.manrope(
                  12,
                  FontWeight.w700,
                  color: AppColors.dangerDeep,
                ),
              ),
            ),
      footer: AppButton(
        label: 'Enregistrer',
        isLoading: _isSaving,
        onPressed: _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInput(
            label: 'Nom du service',
            controller: _name,
            hint: 'Ex: Balayage, Brushing, Coupe Homme...',
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppInput.amount(label: 'Prix', controller: _price),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: AppSelectField(
                  label: 'Durée',
                  value: Formatters.duration(_durationMinutes),
                  icon: Icons.schedule_rounded,
                  onTap: _pickDuration,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 7),
                child: Text(
                  'Catégorie / Groupe',
                  style: AppTypography.sora(
                    12.5,
                    FontWeight.w600,
                    color: AppColors.textBody,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in categoriesList)
                GestureDetector(
                  onTap: () => setState(() => _category = category),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _category == category
                          ? AppColors.tintGreen
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(11),
                      border: _category == category
                          ? null
                          : Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      category,
                      style: AppTypography.manrope(
                        12.5,
                        FontWeight.w600,
                        color: _category == category
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              // Bouton pour ajouter une nouvelle catégorie
              GestureDetector(
                onTap: _showAddCategoryDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: AppColors.accent,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Nouvelle catégorie',
                        style: AppTypography.manrope(
                          12.5,
                          FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          AppInput(
            label: 'Description',
            controller: _description,
            maxLines: 3,
            hint: 'Détails ou conseils sur la prestation…',
          ),
          const SizedBox(height: 15),
          AppListCard(
            children: [
              AppListRow(
                label: 'Commission coiffeur',
                subtitle: 'Appliquée sur ce service',
                strong: true,
                padding: const EdgeInsets.symmetric(vertical: 12),
                onTap: () async {
                  final rate = await showModalBottomSheet<double>(
                    context: context,
                    builder: (context) => SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                        children: [
                          for (final value in const [0, 10, 20, 25, 30, 35, 40])
                            AppListRow(
                              label: '$value %',
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              onTap: () =>
                                  Navigator.pop(context, value.toDouble()),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (rate != null) setState(() => _commissionRate = rate);
                },
                trailing: Text(
                  '${_commissionRate.toStringAsFixed(0)} %',
                  style: AppTypography.sora(
                    15,
                    FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              AppListRow(
                label: 'Réservable en ligne',
                strong: true,
                padding: const EdgeInsets.symmetric(vertical: 12),
                trailing: AppToggle(
                  value: _bookableOnline,
                  onChanged: (value) => setState(() => _bookableOnline = value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
