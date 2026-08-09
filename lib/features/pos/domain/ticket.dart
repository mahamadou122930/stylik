import 'payment_method.dart';

/// Statuts d'une transaction (`transactions.status`).
enum TransactionStatus {
  draft('draft', 'Brouillon'),
  paid('paid', 'Payé'),
  refunded('refunded', 'Remboursé'),
  cancelled('cancelled', 'Annulé');

  const TransactionStatus(this.value, this.label);

  final String value;
  final String label;

  static TransactionStatus fromValue(String? value) =>
      TransactionStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => TransactionStatus.draft,
      );
}

/// Motif d'un remboursement ou d'une annulation.
enum RefundReason {
  unsatisfied('unsatisfied', 'Cliente insatisfaite'),
  cashierError('cashier_error', 'Erreur d\'encaissement'),
  cancelledAppointment('cancelled_appointment', 'RDV annulé');

  const RefundReason(this.value, this.label);

  final String value;
  final String label;
}

/// Ligne d'un ticket de caisse (prestation ou produit).
class TicketLine {
  const TicketLine({
    required this.refId,
    required this.label,
    required this.unitPriceFcfa,
    this.quantity = 1,
    this.isProduct = false,
    this.stylistId,
    this.stylistName,
    this.category,
  });

  /// Identifiant de la prestation (`services.id`) ou du produit.
  final String refId;
  final String label;
  final int unitPriceFcfa;
  final int quantity;
  final bool isProduct;

  /// Coiffeur crédité de la commission sur cette ligne.
  final String? stylistId;
  final String? stylistName;

  /// Catégorie de la prestation ou marque du produit, affichée en sous-titre.
  final String? category;

  int get totalFcfa => unitPriceFcfa * quantity;

  TicketLine copyWith({
    int? quantity,
    String? stylistId,
    String? stylistName,
  }) =>
      TicketLine(
        refId: refId,
        label: label,
        unitPriceFcfa: unitPriceFcfa,
        quantity: quantity ?? this.quantity,
        isProduct: isProduct,
        stylistId: stylistId ?? this.stylistId,
        stylistName: stylistName ?? this.stylistName,
        category: category,
      );

  Map<String, dynamic> toMap() => {
        'ref_id': refId,
        'refId': refId,
        'label': label,
        'unit_price_fcfa': unitPriceFcfa,
        'unitPriceFcfa': unitPriceFcfa,
        'quantity': quantity,
        'is_product': isProduct,
        'isProduct': isProduct,
        'stylist_id': stylistId,
        'stylistId': stylistId,
        'stylist_name': stylistName,
        'stylistName': stylistName,
        'category': category,
      };

  factory TicketLine.fromMap(Map<String, dynamic> map) => TicketLine(
        refId: (map['ref_id'] ?? map['refId'] ?? '') as String,
        label: (map['label'] as String?) ?? '',
        unitPriceFcfa:
            (map['unit_price_fcfa'] ?? map['unitPriceFcfa'] as num?)?.toInt() ?? 0,
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        isProduct: (map['is_product'] ?? map['isProduct'] as bool?) ?? false,
        stylistId: (map['stylist_id'] ?? map['stylistId']) as String?,
        stylistName: (map['stylist_name'] ?? map['stylistName']) as String?,
        category: map['category'] as String?,
      );
}

/// Ticket en cours de composition en caisse (état local, non persisté).
class Ticket {
  const Ticket({
    this.lines = const [],
    this.discountFcfa = 0,
    this.clientId,
    this.appointmentId,
    this.clientName,
    this.stylistName,
    this.timeLabel,
    this.discountLabel,
  });

  final List<TicketLine> lines;
  final int discountFcfa;
  final String? clientId;
  final String? appointmentId;

  /// En-tête affiché en caisse (client, coiffeur, heure du RDV).
  final String? clientName;
  final String? stylistName;
  final String? timeLabel;

  /// Libellé de la remise (« Remise fidélité (5 %) »).
  final String? discountLabel;

  /// Prestations du ticket.
  List<TicketLine> get serviceLines =>
      lines.where((line) => !line.isProduct).toList();

  /// Produits vendus.
  List<TicketLine> get productLines =>
      lines.where((line) => line.isProduct).toList();

  int get subtotalFcfa =>
      lines.fold(0, (sum, line) => sum + line.totalFcfa);

  int get totalFcfa => (subtotalFcfa - discountFcfa).clamp(0, subtotalFcfa);

  bool get isEmpty => lines.isEmpty;

  Ticket copyWith({
    List<TicketLine>? lines,
    int? discountFcfa,
    String? clientId,
    String? appointmentId,
    String? clientName,
    String? stylistName,
    String? timeLabel,
    String? discountLabel,
  }) =>
      Ticket(
        lines: lines ?? this.lines,
        discountFcfa: discountFcfa ?? this.discountFcfa,
        clientId: clientId ?? this.clientId,
        appointmentId: appointmentId ?? this.appointmentId,
        clientName: clientName ?? this.clientName,
        stylistName: stylistName ?? this.stylistName,
        timeLabel: timeLabel ?? this.timeLabel,
        discountLabel: discountLabel ?? this.discountLabel,
      );
}

/// Transaction encaissée — table `transactions`.
class SalonTransaction {
  const SalonTransaction({
    required this.id,
    required this.salonId,
    required this.subtotalFcfa,
    required this.discountFcfa,
    required this.totalAmountFcfa,
    required this.paymentMethod,
    required this.status,
    this.appointmentId,
    this.clientId,
    this.cashierId,
    this.lines = const [],
    this.createdAt,
    this.clientName,
  });

  final String id;
  final String salonId;
  final String? appointmentId;
  final String? clientId;
  final String? cashierId;
  final int subtotalFcfa;
  final int discountFcfa;
  final int totalAmountFcfa;
  final PaymentMethod paymentMethod;
  final TransactionStatus status;
  final List<TicketLine> lines;
  final DateTime? createdAt;

  /// Nom du client, issu de la jointure `clients(full_name)`.
  final String? clientName;

  /// Numéro affiché sur le ticket (« #2024-0847 »).
  String get reference =>
      '#${createdAt?.year ?? ''}-${id.length >= 4 ? id.substring(0, 4).toUpperCase() : id}';

  bool get isRefund => status == TransactionStatus.refunded;

  /// Montant signé : négatif pour un remboursement.
  int get signedAmountFcfa => isRefund ? -totalAmountFcfa : totalAmountFcfa;

  factory SalonTransaction.fromMap(Map<String, dynamic> map) =>
      SalonTransaction(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
        appointmentId: map['appointment_id'] as String?,
        clientId: map['client_id'] as String?,
        cashierId: map['cashier_id'] as String?,
        subtotalFcfa: (map['subtotal_fcfa'] as num?)?.toInt() ?? 0,
        discountFcfa: (map['discount_fcfa'] as num?)?.toInt() ?? 0,
        totalAmountFcfa: (map['total_amount_fcfa'] as num?)?.toInt() ?? 0,
        paymentMethod: PaymentMethod.fromValue(map['payment_method'] as String?),
        status: TransactionStatus.fromValue(map['status'] as String?),
        lines: (map['lines'] as List?)
                ?.map((e) => TicketLine.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
        createdAt: map['created_at'] == null
            ? null
            : DateTime.parse(map['created_at'] as String).toLocal(),
        clientName: map['clients'] is Map<String, dynamic>
            ? (map['clients'] as Map<String, dynamic>)['full_name'] as String?
            : null,
      );

  Map<String, dynamic> toMap() => {
        if (id.isNotEmpty && !id.startsWith('tx_')) 'id': id,
        'salon_id': salonId,
        'appointment_id':
            (appointmentId != null && appointmentId!.isNotEmpty) ? appointmentId : null,
        'client_id': (clientId != null && clientId!.isNotEmpty) ? clientId : null,
        'cashier_id': (cashierId != null && cashierId!.isNotEmpty) ? cashierId : null,
        'subtotal_fcfa': subtotalFcfa,
        'discount_fcfa': discountFcfa,
        'total_amount_fcfa': totalAmountFcfa,
        'payment_method': paymentMethod.value,
        'status': status.value,
        'lines': lines.map((line) => line.toMap()).toList(),
      };
}
