import 'subscription_plan.dart';

/// Demande d'activation déposée par le gérant — table `subscription_requests`.
///
/// L'application ne s'active plus elle-même : elle demande, le gérant paie,
/// et l'opérateur active depuis la console une fois l'argent reçu. Le montant
/// et la référence viennent de la base, jamais de l'application.
class SubscriptionRequest {
  const SubscriptionRequest({
    required this.id,
    required this.salonId,
    required this.planCode,
    required this.planName,
    required this.billingCycle,
    required this.months,
    required this.amountFcfa,
    required this.reference,
    required this.status,
    required this.createdAt,
    this.method,
  });

  final String id;
  final String salonId;
  final String planCode;
  final String planName;
  final BillingCycle billingCycle;
  final int months;

  /// Calculé par la base à partir du catalogue.
  final int amountFcfa;

  /// Moyen choisi par le gérant (« Orange Money »), s'il en a choisi un.
  final String? method;

  /// À rappeler dans le message du paiement : c'est elle qui permet à
  /// l'opérateur de rattacher l'argent reçu à ce salon.
  final String reference;

  /// `pending`, `approved`, `rejected` ou `canceled`.
  final String status;

  final DateTime createdAt;

  bool get isPending => status == 'pending';

  factory SubscriptionRequest.fromMap(Map<String, dynamic> map) =>
      SubscriptionRequest(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
        planCode: map['plan_code'] as String,
        planName: map['plan_name'] as String,
        billingCycle: BillingCycle.fromValue(map['billing_cycle'] as String?),
        months: (map['months'] as num).toInt(),
        amountFcfa: (map['amount_fcfa'] as num).toInt(),
        method: map['method'] as String?,
        reference: map['reference'] as String,
        status: map['status'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );
}

/// Compte sur lequel envoyer le paiement — table `billing_payment_accounts`.
class PaymentAccount {
  const PaymentAccount({
    required this.method,
    required this.accountNumber,
    this.holderName,
  });

  /// « Orange Money », « Wave », « Moov Money ».
  final String method;
  final String accountNumber;

  /// Nom affiché par l'opérateur mobile au moment de l'envoi : le gérant
  /// vérifie ainsi qu'il paie la bonne personne.
  final String? holderName;

  factory PaymentAccount.fromMap(Map<String, dynamic> map) => PaymentAccount(
    method: map['method'] as String,
    accountNumber: map['account_number'] as String,
    holderName: map['holder_name'] as String?,
  );
}
