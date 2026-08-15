import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/product.dart';
import 'inventory_providers.dart';

/// Formulaire de création d'un nouveau produit en stock.
class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key});

  static const routeName = '/inventory/product-form';

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Revente');
  final _unitSalePriceController = TextEditingController(text: '0');
  final _unitCostController = TextEditingController(text: '0');
  final _stockQuantityController = TextEditingController(text: '10');
  final _alertThresholdController = TextEditingController(text: '3');
  final _supplierController = TextEditingController();
  final _packagingController = TextEditingController();

  ProductUsage _usage = ProductUsage.resale;
  bool _isSubmitting = false;

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
      final product = Product(
        id: '',
        salonId: salonId,
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? 'Autre'
            : _categoryController.text.trim(),
        unitSalePriceFcfa:
            int.tryParse(_unitSalePriceController.text.replaceAll(' ', '')) ?? 0,
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
      );

      await ref.read(inventoryRepositoryProvider).create(product);
      ref.invalidate(productsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produit « ${product.name} » ajouté au stock.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ajouter le produit : $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Nouveau produit',
      footer: AppButton(
        label: 'Enregistrer le produit',
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
                            controller: _unitCostController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Coût d\'achat (FCFA)',
                              suffixText: 'F',
                            ),
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
