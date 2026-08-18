import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/payment_method.dart';
import 'pos_providers.dart';
import 'receipt_page.dart';

/// 6.2 — Moyen de paiement : espèces, mobile money, carte.
class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key});

  static const routeName = '/pos/payment';

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  bool _isProcessing = false;

  Future<void> _checkout() async {
    setState(() => _isProcessing = true);
    try {
      final transaction = await ref.read(checkoutControllerProvider)();
      if (!mounted) return;

      if (transaction == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ticket vide.')));
        return;
      }

      Navigator.of(context).pushReplacementNamed(ReceiptPage.routeName);

      // Le ticket est encaissé, mais le stock n'a pas suivi : le dire ici,
      // sinon l'inventaire dérive sans que personne ne le sache.
      final warning = ref.read(stockWarningProvider);
      if (warning != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(warning)));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Encaissement impossible : $error')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = ref.watch(ticketProvider);
    final selected = ref.watch(selectedPaymentProvider);

    return AppScreen(
      title: 'Paiement',
      footer: AppButton(
        label: 'Encaisser ${Formatters.fcfa(ticket.totalFcfa)}',
        height: 56,
        isLoading: _isProcessing,
        onPressed: ticket.isEmpty ? null : _checkout,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppGradientCard(
            bubbleColor: Colors.transparent,
            child: Column(
              children: [
                Text(
                  'Montant à encaisser',
                  style: AppTypography.manrope(
                    13,
                    FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    Formatters.fcfa(ticket.totalFcfa),
                    style: AppTypography.sora(
                      38,
                      FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const AppSectionTitle('Comment paie le client ?'),
          for (final family in PaymentFamily.values) ...[
            _PaymentFamilyCard(
              family: family,
              selected: selected,
              onSelected: (method) =>
                  ref.read(selectedPaymentProvider.notifier).state = method,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PaymentFamilyCard extends StatelessWidget {
  const _PaymentFamilyCard({
    required this.family,
    required this.selected,
    required this.onSelected,
  });

  final PaymentFamily family;
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onSelected;

  @override
  Widget build(BuildContext context) {
    final methods = family.methods;
    final isSelected = selected.family == family;
    final hasProviders = methods.length > 1;

    return AppCard(
      onTap: () => onSelected(methods.first),
      shadow: false,
      color: isSelected ? AppColors.tintGreenSoft : AppColors.surface,
      borderColor: isSelected ? AppColors.accent : AppColors.border,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : (family == PaymentFamily.card
                              ? AppColors.tintBlue
                              : AppColors.tintGreen),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    family.icon,
                    size: 22,
                    color: family == PaymentFamily.card
                        ? AppColors.blue
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family.label,
                        style: AppTypography.sora(15, FontWeight.w700),
                      ),
                      if (hasProviders)
                        Text(
                          methods.map((method) => method.label).join(' · '),
                          style: AppTypography.manrope(
                            12,
                            FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                _RadioDot(selected: isSelected),
              ],
            ),
          ),
          if (isSelected && hasProviders)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              child: Row(
                children: [
                  for (final method in methods) ...[
                    if (method != methods.first) const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onSelected(method),
                        child: Container(
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: selected == method
                                  ? AppColors.tintGreenBorder
                                  : AppColors.border,
                              width: selected == method ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            method.label,
                            style: AppTypography.sora(
                              12,
                              FontWeight.w700,
                              color: method.color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Pastille de sélection ronde des listes d'options.
class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.accent : Colors.transparent,
        border: selected
            ? null
            : Border.all(color: AppColors.borderStrong, width: 2),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}
