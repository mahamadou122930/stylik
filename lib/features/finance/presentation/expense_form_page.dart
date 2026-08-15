import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/finance_summary.dart';
import 'finance_providers.dart';

/// 8.6 — Formulaire de saisie d'une dépense / charge (Lot 8 prototype).
class ExpenseFormPage extends ConsumerStatefulWidget {
  const ExpenseFormPage({super.key});

  static const routeName = '/finance/expense-form';

  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  String _selectedCategory = 'Loyer & Charges';
  bool _isSaving = false;

  static const List<String> _categories = [
    'Loyer & Charges',
    'Électricité & Eau',
    'Produits & Fournitures',
    'Salaires & Prime',
    'Marketing & Com',
    'Entretien & Réparation',
    'Autre charge',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final salonId = ref.read(currentSalonIdProvider);
      if (salonId == null) throw Exception('Salon non identifié');

      final expense = Expense(
        id: '',
        salonId: salonId,
        label: _titleController.text.trim(),
        amountFcfa: int.parse(_amountController.text.trim()),
        category: ExpenseCategory.fromValue(_selectedCategory),
        spentAt: DateTime.now(),
        supplier: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final repo = ref.read(financeRepositoryProvider);
      await repo.createExpense(expense);

      ref.invalidate(expensesProvider);
      ref.invalidate(financeSummaryProvider);

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
      title: 'Ajouter une dépense',
      subtitle: 'Enregistrer une charge du salon',
      footer: AppButton(
        label: _isSaving ? 'Enregistrement...' : 'Enregistrer la dépense',
        isLoading: _isSaving,
        onPressed: _saveExpense,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInput(
              controller: _titleController,
              label: 'Libellé de la dépense',
              hint: 'Ex: Facture EDM Février',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
            ),
            const SizedBox(height: 14),
            AppInput(
              controller: _amountController,
              label: 'Montant (FCFA)',
              hint: '45000',
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
                if (int.tryParse(v.trim()) == null) return 'Montant invalide';
                return null;
              },
            ),
            const SizedBox(height: 14),
            const AppSectionTitle('Catégorie de la charge'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: [
                    for (final cat in _categories)
                      DropdownMenuItem(
                        value: cat,
                        child: Text(
                          cat,
                          style: AppTypography.sora(14, FontWeight.w600),
                        ),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            AppInput(
              controller: _notesController,
              label: 'Notes / Détails',
              hint: 'Optionnel (numéro de facture, détails du fournisseur...)',
            ),
          ],
        ),
      ),
    );
  }
}
