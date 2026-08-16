import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/product.dart';
import 'inventory_providers.dart';

/// Formulaire de fiche produit — création et modification.
class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, this.product});

  static const routeName = '/inventory/product-form';

  /// Fiche existante à modifier, `null` pour une création.
  final Product? product;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _categoryController;
  late final TextEditingController _unitSalePriceController;
  late final TextEditingController _unitCostController;
  late final TextEditingController _stockQuantityController;
  late final TextEditingController _alertThresholdController;
  late final TextEditingController _supplierController;
  late final TextEditingController _packagingController;

  late ProductUsage _usage;
  bool _isSubmitting = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _nameController = TextEditingController(text: p?.name ?? '');
    _brandController = TextEditingController(text: p?.brand ?? '');
    _categoryController = TextEditingController(text: p?.category ?? 'Revente');
    _unitSalePriceController =
        TextEditingController(text: '${p?.unitSalePriceFcfa ?? 0}');
    _unitCostController = TextEditingController(text: '${p?.unitCostFcfa ?? 0}');
    _stockQuantityController =
        TextEditingController(text: '${p?.stockQuantity ?? 10}');
    _alertThresholdController =
        TextEditingController(text: '${p?.alertThreshold ?? 3}');
    _supplierController = TextEditingController(text: p?.supplier ?? '');
    _packagingController = TextEditingController(text: p?.packaging ?? '');
    _usage = p?.usage ?? ProductUsage.resale;
  }

  final List<String> _suggestedCategories = const [
    'Revente',
    'Shampooing',
    'Soin',
    'Coloration',
    'Coiffage',
    'Consommable',
    'Autre',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _unitSalePriceController.dispose();
    _unitCostController.dispose();
    _stockQuantityController.dispose();
    _alertThresholdController.dispose();
    _supplierController.dispose();
    _packagingController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final salonId = ref.read(currentSalonIdProvider);
    if (salonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur : Salon non identifié.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final existing = widget.product;
      final product = Product(
        id: existing?.id ?? '',
        salonId: existing?.salonId ?? salonId,
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? 'Autre'
            : _categoryController.text.trim(),
        // Un consommable n'est jamais vendu : son prix de vente reste à zéro
        // quoi qu'il arrive.
        unitSalePriceFcfa: _usage == ProductUsage.consumable
            ? 0
            : int.tryParse(
                  _unitSalePriceController.text.replaceAll(' ', ''),
                ) ??
                0,
        unitCostFcfa:
            int.tryParse(_unitCostController.text.replaceAll(' ', '')) ?? 0,
        stockQuantity:
            int.tryParse(_stockQuantityController.text.replaceAll(' ', '')) ?? 0,
        alertThreshold:
            int.tryParse(_alertThresholdController.text.replaceAll(' ', '')) ?? 0,
        supplier: _supplierController.text.trim().isEmpty
            ? null
            : _supplierController.text.trim(),
        packaging: _packagingController.text.trim().isEmpty
            ? null
            : _packagingController.text.trim(),
        usage: _usage,
        isActive: existing?.isActive ?? true,
      );

      final repository = ref.read(inventoryRepositoryProvider);
      if (_isEditing) {
        await repository.update(product);
        ref.invalidate(productDetailProvider(product.id));
      } else {
        await repository.create(product);
      }
      ref.invalidate(productsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Fiche « ${product.name} » mise à jour.'
                : 'Produit « ${product.name} » ajouté au stock.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Impossible d\'enregistrer la fiche : $e'
                : 'Impossible d\'ajouter le produit : $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: _isEditing ? 'Modifier le produit' : 'Nouveau produit',
      footer: AppButton(
        label: _isEditing ? 'Enregistrer les modifications' : 'Enregistrer le produit',
        height: 56,
        isLoading: _isSubmitting,
        onPressed: _submit,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionTitle('Informations générales',
                        padding: EdgeInsets.only(bottom: 12)),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nom du produit *',
                        hintText: 'ex: Shampooing Nutritif Kérastase',
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Veuillez saisir un nom'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _brandController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Marque *',
                        hintText: 'ex: Kérastase, L\'Oréal',
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Veuillez saisir une marque'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        hintText: 'ex: Revente, Care, Coloration',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _suggestedCategories.map((cat) {
                        final selected = _categoryController.text == cat;
                        return ChoiceChip(
                          label: Text(cat, style: const TextStyle(fontSize: 12)),
                          selected: selected,
                          selectedColor: AppColors.tintGreen,
                          onSelected: (_) {
                            setState(() => _categoryController.text = cat);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionTitle('Prix & Usage',
                        padding: EdgeInsets.only(bottom: 12)),
                    Row(
                      children: [
                        // Le prix de vente n'a de sens que pour un produit
                        // revendu : l'exiger sur un consommable empêchait
                        // purement et simplement d'enregistrer la fiche.
                        if (_usage == ProductUsage.resale) ...[
                          Expanded(
                            child: TextFormField(
                              controller: _unitSalePriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Prix de vente (FCFA) *',
                                suffixText: 'F',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Obligatoire';
                                }
                                if (int.tryParse(
                                      value.replaceAll(' ', ''),
                                    ) ==
                                    null) {
                                  return 'Nombre invalide';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: TextFormField(
                            controller: _unitCostController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              // Obligatoire des deux côtés : c'est la seule
                              // base de la valeur du stock, et le laisser à
                              // zéro faisait disparaître le produit du total.
                              labelText: 'Coût d\'achat (FCFA) *',
                              suffixText: 'F',
                            ),
                            validator: (value) {
                              final cost =
                                  int.tryParse((value ?? '').replaceAll(' ', ''));
                              if (cost == null) return 'Nombre invalide';
                              if (cost <= 0) return 'Requis pour la valeur du stock';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Destination / Usage',
                      style: AppTypography.sora(13, FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _usage = ProductUsage.resale),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                color: _usage == ProductUsage.resale
                                    ? AppColors.tintGreenSoft
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _usage == ProductUsage.resale
                                      ? AppColors.accent
                                      : AppColors.border,
                                  width: _usage == ProductUsage.resale ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 18,
                                    color: _usage == ProductUsage.resale
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Revente client',
                                      style: AppTypography.sora(
                                        12.5,
                                        FontWeight.w700,
                                        color: _usage == ProductUsage.resale
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _usage = ProductUsage.consumable),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                color: _usage == ProductUsage.consumable
                                    ? AppColors.tintGreenSoft
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _usage == ProductUsage.consumable
                                      ? AppColors.accent
                                      : AppColors.border,
                                  width:
                                      _usage == ProductUsage.consumable ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.science_outlined,
                                    size: 18,
                                    color: _usage == ProductUsage.consumable
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Consommable soin',
                                      style: AppTypography.sora(
                                        12.5,
                                        FontWeight.w700,
                                        color: _usage == ProductUsage.consumable
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
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
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionTitle('Stock & Alertes',
                        padding: EdgeInsets.only(bottom: 12)),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stockQuantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Stock initial *',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Obligatoire';
                              }
                              if (int.tryParse(value.replaceAll(' ', '')) == null) {
                                return 'Nombre invalide';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _alertThresholdController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Seuil d\'alerte *',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Obligatoire';
                              }
                              if (int.tryParse(value.replaceAll(' ', '')) == null) {
                                return 'Nombre invalide';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _packagingController,
                      decoration: const InputDecoration(
                        labelText: 'Conditionnement (Optionnel)',
                        hintText: 'ex: Flacon 250 ml, Tube 60 ml',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _supplierController,
                      decoration: const InputDecoration(
                        labelText: 'Fournisseur (Optionnel)',
                        hintText: 'ex: L\'Oréal Mali',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
