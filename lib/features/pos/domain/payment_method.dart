import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Famille de moyen de paiement, telle que présentée en caisse.
enum PaymentFamily {
  cash('Espèces', Icons.payments_outlined),
  mobileMoney('Mobile money', Icons.smartphone_outlined),
  card('Carte bancaire', Icons.credit_card_rounded);

  const PaymentFamily(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Sous-choix proposés sous la famille (opérateurs mobile money).
  List<PaymentMethod> get methods => PaymentMethod.values
      .where((method) => method.family == this)
      .toList();
}

/// Moyens de paiement acceptés (`transactions.payment_method`).
enum PaymentMethod {
  cash('cash', 'Espèces', PaymentFamily.cash, AppColors.primary),
  wave('wave', 'Wave', PaymentFamily.mobileMoney, Color(0xFF1E7BC4)),
  orangeMoney(
    'orange_money',
    'Orange',
    PaymentFamily.mobileMoney,
    Color(0xFFE8850C),
  ),
  // Moov Africa Malitel — le second opérateur mobile money du Mali. Remplace
  // « Free Money », qui n'existe qu'au Sénégal.
  moovMoney('moov_money', 'Moov', PaymentFamily.mobileMoney, Color(0xFF0A6FB8)),
  card('card', 'Carte bancaire', PaymentFamily.card, AppColors.blue);

  const PaymentMethod(this.value, this.label, this.family, this.color);

  final String value;
  final String label;
  final PaymentFamily family;
  final Color color;

  IconData get icon => family.icon;

  static PaymentMethod fromValue(String? value) =>
      PaymentMethod.values.firstWhere(
        (method) => method.value == value,
        orElse: () => cash,
      );

  /// Les paiements mobiles demandent une référence de transaction.
  bool get requiresReference => family == PaymentFamily.mobileMoney;

  /// Libellé complet pour un ticket (« Mobile money · Wave »).
  String get fullLabel =>
      family == PaymentFamily.mobileMoney ? '${family.label} · $label' : label;
}
