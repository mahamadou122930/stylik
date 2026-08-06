/// Statuts de la file d'attente sans rendez-vous.
enum WalkInStatus {
  waiting('waiting', 'En attente'),
  assigned('assigned', 'Affecté'),
  inProgress('in_progress', 'En cours'),
  served('served', 'Servi'),
  left('left', 'Parti');

  const WalkInStatus(this.value, this.label);

  final String value;
  final String label;

  static WalkInStatus fromValue(String? value) =>
      WalkInStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => WalkInStatus.waiting,
      );
}

/// Entrée de la file d'attente — table `walk_in_queue`.
class WalkInEntry {
  const WalkInEntry({
    required this.id,
    required this.salonId,
    required this.clientName,
    required this.serviceRequested,
    required this.arrivalTime,
    required this.status,
    this.assignedStylistId,
    this.phone,
  });

  final String id;
  final String salonId;
  final String clientName;
  final String serviceRequested;
  final DateTime arrivalTime;
  final WalkInStatus status;
  final String? assignedStylistId;
  final String? phone;

  /// Temps d'attente écoulé depuis l'arrivée.
  Duration get waitingTime => DateTime.now().difference(arrivalTime);

  factory WalkInEntry.fromMap(Map<String, dynamic> map) => WalkInEntry(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
        clientName: (map['client_name'] as String?) ?? 'Client',
        serviceRequested: (map['service_requested'] as String?) ?? '',
        arrivalTime: DateTime.parse(map['arrival_time'] as String).toLocal(),
        status: WalkInStatus.fromValue(map['status'] as String?),
        assignedStylistId: map['assigned_stylist_id'] as String?,
        phone: map['phone'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'salon_id': salonId,
        'client_name': clientName,
        'service_requested': serviceRequested,
        'arrival_time': arrivalTime.toUtc().toIso8601String(),
        'status': status.value,
        'assigned_stylist_id': assignedStylistId,
        'phone': phone,
      };
}
