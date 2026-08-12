import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/loyalty_campaign.dart';
import 'loyalty_providers.dart';

/// 9.4 — Formulaire de création d'une promotion / offre (Lot 9 prototype).
class PromotionFormPage extends ConsumerStatefulWidget {
  const PromotionFormPage({super.key});

  static const routeName = '/loyalty/promotion-form';

  @override
  ConsumerState<PromotionFormPage> createState() => _PromotionFormPageState();
}

class _PromotionFormPageState extends ConsumerState<PromotionFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _discountController;
  late TextEditingController _codeController;

  bool _isPercentage = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _discountController = TextEditingController();
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _discountController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _savePromotion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final salonId = ref.read(currentSalonIdProvider);
      if (salonId == null) throw Exception('Salon non identifié');

      final desc = _descriptionController.text.trim();
      final promoCode = _codeController.text.trim().toUpperCase();
      final fullDesc = promoCode.isNotEmpty ? '$desc (Code: $promoCode)' : desc;

      final promo = Promotion(
        id: '',
        salonId: salonId,
        name: _nameController.text.trim(),
        description: fullDesc,
        startsAt: DateTime.now(),
        endsAt: DateTime.now().add(const Duration(days: 30)),
        isActive: true,
      );

      final repo = ref.read(loyaltyRepositoryProvider);
      await repo.createPromotion(promo);

      ref.invalidate(promotionsProvider);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Créer une offre',
      subtitle: 'Lancer une promotion marketing',
      footer: AppButton(
        label: _isSaving ? 'Enregistrement...' : 'Lancer l\'offre',
        isLoading: _isSaving,
        onPressed: _savePromotion,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInput(
              controller: _nameController,
              label: 'Nom de l\'offre',
              hint: 'Ex: Promo Saint-Valentin',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
            ),
            const SizedBox(height: 14),
            AppInput(
              controller: _descriptionController,
              label: 'Description',
              hint: '−20% sur tous les soins capillaires',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    controller: _discountController,
                    label: _isPercentage ? 'Réduction (%)' : 'Réduction (FCFA)',
                    hint: _isPercentage ? '20' : '5000',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Obligatoire';
                      if (int.tryParse(v.trim()) == null) return 'Invalide';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Type',
                      style: AppTypography.sora(12, FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('%'),
                          selected: _isPercentage,
                          onSelected: (sel) {
                            if (sel) setState(() => _isPercentage = true);
                          },
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: _isPercentage ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('FCFA'),
                          selected: !_isPercentage,
                          onSelected: (sel) {
                            if (sel) setState(() => _isPercentage = false);
                          },
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: !_isPercentage ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppInput(
              controller: _codeController,
              label: 'Code promo (Optionnel)',
              hint: 'VALENTIN2026',
            ),
          ],
        ),
      ),
    );
  }
}
