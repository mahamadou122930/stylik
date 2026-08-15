import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Moyen par lequel le salon règle une commission.
enum PayoutMethod {
  orangeMoney('orange_money', 'Orange Money', Icons.smartphone_rounded),
  moovMoney('moov_money', 'Moov Money', Icons.smartphone_rounded),
  wave('wave', 'Wave', Icons.smartphone_rounded),
  cash('cash', 'Espèces', Icons.payments_outlined),
  transfer('transfer', 'Virement', Icons.mail_outline_rounded);

  const PayoutMethod(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  static PayoutMethod fromValue(String? value) => PayoutMethod.values.firstWhere(
        (method) => method.value == value,
        orElse: () => cash,
      );
}

/// Cycle de vie d'une demande de versement.
enum PayoutStatus {
  pending('pending', 'en attente gérant'),
  paid('paid', 'versée'),
  rejected('rejected', 'refusée');

  const PayoutStatus(this.value, this.label);

  final String value;
  final String label;

  static PayoutStatus fromValue(String? value) => PayoutStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => pending,
      );

  Color get color => switch (this) {
        pending => AppColors.amber,
        paid => AppColors.primary,
        rejected => AppColors.expense,
      };

  IconData get icon => switch (this) {
        pending => Icons.schedule_rounded,
        paid => Icons.check_rounded,
        rejected => Icons.close_rounded,
      };
}

/// Demande de versement d'une commission — table `payout_requests`.
///
/// Une seule ligne porte tout le cycle : le coiffeur demande, le gérant règle.
/// Le versement n'est donc pas un objet distinct — c'est cette même demande une
/// fois `paid`, avec sa date, son moyen de paiement et sa référence. Rapprocher
/// deux tables pour reconstituer « telle demande = tel versement » serait une
/// source d'écarts pour rien.
class PayoutRequest {
  const PayoutRequest({
    required this.id,
    required this.salonId,
    required this.profileId,
    required this.amountFcfa,
    required this.status,
    required this.requestedAt,
    this.method,
    this.paidAt,
    this.reference,
    this.note,
    this.profileName,
  });

  final String id;
  final String salonId;
  final String profileId;
  final int amountFcfa;
  final PayoutStatus status;
  final DateTime requestedAt;

  /// Renseigné au règlement : tant que la demande est en attente, le gérant
  /// n'a pas encore choisi comment il paie.
  final PayoutMethod? method;
  final DateTime? paidAt;

  /// Référence de la transaction (« TXN-Q7F42K », « Reçu n° 0142 »).
  final String? reference;

  final String? note;

  /// Issu de la jointure `profiles(full_name)`, pour l'écran du gérant.
  final String? profileName;

  bool get isSettled => status == PayoutStatus.paid;

  factory PayoutRequest.fromMap(Map<String, dynamic> map) => PayoutRequest(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
        profileId: map['profile_id'] as String,
        amountFcfa: (map['amount_fcfa'] as num?)?.toInt() ?? 0,
        status: PayoutStatus.fromValue(map['status'] as String?),
        requestedAt:
            DateTime.parse(map['requested_at'] as String).toLocal(),
        method: map['method'] == null
            ? null
            : PayoutMethod.fromValue(map['method'] as String?),
        paidAt: map['paid_at'] == null
            ? null
            : DateTime.parse(map['paid_at'] as String).toLocal(),
        reference: map['reference'] as String?,
        note: map['note'] as String?,
        profileName: map['profiles'] is Map<String, dynamic>
            ? (map['profiles'] as Map<String, dynamic>)['full_name'] as String?
            : null,
      );

  /// Insertion : le statut, la date et le salon sont posés par la base — le
  /// client ne décide ni de se payer lui-même, ni de la date de règlement.
  Map<String, dynamic> toInsertMap() => {
        'salon_id': salonId,
        'profile_id': profileId,
        'amount_fcfa': amountFcfa,
        'note': note,
      };
}
